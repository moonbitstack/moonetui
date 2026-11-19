// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct App[D] {
  driver : D
  plain : Bool
  quit : Array[@event.Key]
  mut root : Node
  parser : @input.Parser
  mut base : @style.Style
  mut sheet : @design.Stylesheet
  frame_ms : Int32
  mut rects : Map[Int32, @geom.Region]
  mut bare : Map[Int32, @geom.Region]
  mut views : Map[Int32, View]
  mut styled : Map[Int32, @design.Resolved]
  inbox : Array[@widget.Out]
  handlers : Array[(@widget.Out) -> Bool]
  timers : Array[Timer]
  screens : Array[Screen]
  mut anims : Map[Int32, Anim]
  mut prev_bare : Map[Int32, @geom.Region]
  /// Where the last frame put each node, to find what a relayout moved.
  mut prev_rects : Map[Int32, @geom.Region]
  mut size : @geom.Size
  mut focus : Int32
  mut hover : Int32
  off : Array[Int32]
  mut prev : Array[@strip.Strip]
  /// The placements of the last frame, kept so a frame that redraws part of
  /// the screen can compose those rows without placing the tree again.
  mut scene : @comp.Scene
  /// Rows to compose again before the next frame is written.
  damage : Array[Int32]
  /// The next frame is drawn whole, whatever the damage says.
  mut wiped : Bool
  /// The tree has to be placed again before the next frame.
  mut layout : Bool
  mut dirty : Bool
  mut running : Bool
  mut last_frame : Int32
  mut pending_resize : @geom.Size?
  mut resize_at : Int32
  mut measured : @geom.Size
  mut ticked : Int32
  /// Where the terminal's cursor was left, row and column, and how it looked.
  mut caret : (Int32, Int32, @widget.Caret)?
  /// A caret was shown, so the user's own shape is put back on the way out.
  mut caret_shown : Bool
}

///|
const RESIZE_SETTLE_MS : Int32 = 8

///|
pub fn[D] App::new(
  driver : D,
  root : Node,
  base~ : @style.Style = @style.default,
  sheet~ : @design.Stylesheet = @design.Stylesheet::new(),
  fps~ : Int32 = 60,
  plain~ : Bool = false,
  quit~ : Array[@event.Key] = [ctrl_c],
) -> App[D] {
  {
    driver,
    plain,
    quit,
    root,
    parser: @input.Parser::new(),
    base,
    sheet,
    frame_ms: if fps > 0 {
      1000 / fps
    } else {
      16
    },
    rects: Map([]),
    bare: Map([]),
    views: Map([]),
    styled: Map([]),
    inbox: [],
    handlers: [],
    timers: [],
    screens: [],
    anims: Map([]),
    prev_bare: Map([]),
    prev_rects: Map([]),
    size: @geom.Size::new(80, 24),
    focus: -1,
    hover: -1,
    off: [],
    prev: [],
    scene: @comp.Scene::new(@geom.Size::new(80, 24)),
    damage: [],
    wiped: true,
    layout: true,
    dirty: true,
    running: false,
    last_frame: 0,
    pending_resize: None,
    resize_at: 0,
    measured: @geom.Size::new(80, 24),
    ticked: 0,
    caret: None,
    caret_shown: false,
  }
}

///|
pub fn[D : @driver.Driver] App::start(self : App[D]) -> Unit raise {
  self.driver.start()
  if !self.plain {
    self.driver.write(@driver.enter())
  }
  self.size = self.driver.size()
  self.measured = self.size
  self.running = true
  self.dirty = true
  self.prev = []
  self.focus_next(1)
  self.wipe()
  self.render()
  self.last_frame = self.driver.now()
  self.ticked = self.last_frame
}

///|
pub fn[D : @driver.Driver] App::stop(self : App[D]) -> Unit raise {
  self.running = false
  if !self.plain {
    if self.caret_shown {
      self.driver.write(@widget.caret.sequence())
    }
    self.driver.write(@driver.leave())
  }
  self.driver.flush()
  self.driver.stop()
}

///|
pub fn[D : @driver.Driver] App::step(self : App[D]) -> Bool raise {
  if !self.running {
    return false
  }
  let chunk = self.driver.poll(self.frame_ms)
  let events : Array[@event.Event] = []
  if chunk.length() > 0 {
    self.parser.feed(chunk, events)
  } else {
    self.parser.idle(events)
  }
  for ev in events {
    self.dispatch(ev)
  }
  let now = self.driver.now()
  self.fire_timers(now)
  let since = now - self.ticked
  if since >= self.frame_ms || since < 0 {
    self.ticked = now
    let ms = if since < 0 { self.frame_ms } else { since }
    self.root.each_leaf((id, widget) => {
      ignore(self.deliver_to(id, widget, Tick(ms)))
    })
  }
  // Few terminals report a resize in-band, so the size is measured as well.
  let measured = self.driver.size()
  if measured != self.measured {
    self.measured = measured
    self.pending_resize = Some(measured)
    self.resize_at = now
  }
  match self.pending_resize {
    Some(size) =>
      if now - self.resize_at >= RESIZE_SETTLE_MS {
        self.size = size
        self.pending_resize = None
        self.prev = []
        self.wipe()
      }
    None => ()
  }
  // What input changed is drawn in the same step; the frame interval paces only what timers
  // and ticks change, so a key press never waits for the next frame.
  let since = now - self.last_frame
  if self.dirty && (events.length() > 0 || since < 0 || since >= self.frame_ms) {
    self.render()
    self.last_frame = now
  }
  self.running
}

///|
pub fn[D : @driver.Driver] App::run(self : App[D]) -> Unit raise {
  self.start()
  while self.step() {

  }
  self.stop()
}

///|
fn[D] App::quits(self : App[D], key : @event.Key) -> Bool {
  for quit in self.quit {
    if quit == key {
      return true
    }
  }
  false
}

///|
pub fn[D] App::quit(self : App[D]) -> Unit {
  self.running = false
}

///|
pub fn[D] App::drain(self : App[D]) -> Array[@widget.Out] {
  let out : Array[@widget.Out] = []
  for item in self.inbox {
    out.push(item)
  }
  self.inbox.clear()
  out
}

///|
pub fn[D] App::focused(self : App[D]) -> Int32 {
  self.focus
}

///|
pub fn[D] App::hovering(self : App[D]) -> Int32 {
  self.hover
}

///|
/// A disabled node takes no input, holds no focus, and can be restyled by the
/// `:disabled` pseudo-class.
pub fn[D] App::disable(self : App[D], id : Int32) -> Unit {
  if !self.off.contains(id) {
    self.off.push(id)
    if self.focus == id {
      self.focus_next(1)
    }
    self.wipe()
  }
}

///|
pub fn[D] App::enable(self : App[D], id : Int32) -> Unit {
  let kept : Array[Int32] = []
  for own in self.off {
    if own != id {
      kept.push(own)
    }
  }
  if kept.length() != self.off.length() {
    self.off.clear()
    for own in kept {
      self.off.push(own)
    }
    self.wipe()
  }
}

///|
pub fn[D] App::is_disabled(self : App[D], id : Int32) -> Bool {
  self.off.contains(id)
}

///|
/// The app's message hook: every message a widget emits, and every focus
/// or scroll move the app itself reports, passes here first. A
/// handler that answers true claims the message and the built-in behaviour
/// never runs.
pub fn[D] App::on(self : App[D], handler : (@widget.Out) -> Bool) -> Unit {
  self.handlers.push(handler)
}

///|
/// Put a message in the stream the app drains from, as if a widget had sent
/// it.
pub fn[D] App::post(self : App[D], out : @widget.Out) -> Unit {
  self.inbox.push(out)
}

///|
/// Run `fire` every `ms` milliseconds of the driver's clock, until the app
/// stops.
pub fn[D : @driver.Driver] App::every(
  self : App[D],
  ms : Int32,
  fire : () -> Unit,
) -> Unit {
  if ms <= 0 {
    return
  }
  self.timers.push({ ms, at: self.driver.now() + ms, repeat: true, fire, })
}

///|
pub fn[D : @driver.Driver] App::after(
  self : App[D],
  ms : Int32,
  fire : () -> Unit,
) -> Unit {
  if ms <= 0 {
    return
  }
  self.timers.push({ ms, at: self.driver.now() + ms, repeat: false, fire, })
}

///|
/// Restyle the whole tree with another stylesheet, as a theme switch does.
pub fn[D] App::set_sheet(self : App[D], sheet : @design.Stylesheet) -> Unit {
  self.sheet = sheet
  self.wipe()
}

///|
/// Restyle the whole tree with another theme: the colours it inherits, and
/// the rules every role names. One call is a theme switch.
pub fn[D] App::set_theme(self : App[D], theme : @design.Theme) -> Unit {
  self.base = theme.base()
  self.sheet = theme.sheet()
  self.wipe()
}

///|
/// Swap the tree the app is showing, keeping the focus where it was. The
/// frame loop redraws on the next step.
pub fn[D] App::swap_root(self : App[D], root : Node) -> Unit {
  self.root = root
  self.wipe()
}

///|
/// Cover the screen with a new tree: the one showing, and where its focus
/// sits, is pushed down and comes back when popped.
pub fn[D] App::push_screen(self : App[D], root : Node) -> Unit {
  self.screens.push({ root: self.root, focus: self.focus, })
  self.root = root
  self.focus = -1
  self.prev = []
  self.prev_bare = Map([])
  self.anims = Map([])
  self.focus_next(1)
  self.wipe()
}

///|
pub fn[D] App::pop_screen(self : App[D]) -> Unit {
  match self.screens.pop() {
    Some(screen) => {
      self.root = screen.root
      self.focus = -1
      self.prev = []
      self.prev_bare = Map([])
      self.anims = Map([])
      self.give_focus(screen.focus)
      self.wipe()
    }
    None => ()
  }
}

///|
pub fn[D] App::screen_depth(self : App[D]) -> Int32 {
  self.screens.length() + 1
}

///|
pub fn[D] App::focus_next(self : App[D], step : Int32) -> Unit {
  let ring = self.root.focus_ring(theme=self.theme())
  let open : Array[Int32] = []
  for id in ring {
    if !self.off.contains(id) {
      open.push(id)
    }
  }
  if open.length() == 0 {
    return
  }
  let mut at = -1
  for i in 0..<open.length() {
    if open[i] == self.focus {
      at = i
    }
  }
  let count = open.length()
  let next = if at < 0 {
    if step > 0 {
      0
    } else {
      count - 1
    }
  } else {
    ((at + step) % count + count) % count
  }
  self.give_focus(open[next])
}

///|
pub fn[D] App::rect_of(self : App[D], id : Int32) -> @geom.Region {
  match self.rects.get(id) {
    Some(rect) => rect
    None => @geom.Region::new(0, 0, 0, 0)
  }
}

///|
/// Where the node sits before clipping; scrolling clips a widget's window
/// without shrinking what it is asked to draw.
fn[D] App::bare_of(self : App[D], id : Int32) -> @geom.Region {
  match self.bare.get(id) {
    Some(rect) => rect
    None => self.rect_of(id)
  }
}

///|
pub fn[D] App::screen(self : App[D]) -> Array[String] {
  let out : Array[String] = []
  for row in self.prev {
    out.push(row.text())
  }
  out
}

///|
fn[D : @driver.Driver] App::dispatch(self : App[D], ev : @event.Event) -> Unit {
  match ev {
    Key(key) => {
      // ctrl-c leaves whether or not a widget would have taken it: a terminal
      // program with a key it cannot be interrupted by is a bug.
      if self.quits(key) && key == ctrl_c {
        self.running = false
        return
      }
      let handled = self.deliver(self.focus, Key(key))
      if !handled {
        // The other quit keys come after the widget, so escape can close a
        // dialog before it closes the application.
        if self.quits(key) {
          self.running = false
          return
        }
        match key.code {
          Tab => self.focus_next(1)
          BackTab => self.focus_next(-1)
          _ => self.scroll_key(key) |> ignore
        }
      }
    }
    Paste(text) => self.deliver(self.focus, Paste(text)) |> ignore
    Mouse(mouse) => {
      self.track_hover(mouse.x, mouse.y)
      match mouse.kind {
        ScrollUp | ScrollDown | ScrollLeft | ScrollRight => self.wheel(mouse)
        _ =>
          match self.at(mouse.x, mouse.y) {
            Some((id, rect)) => {
              let inside = {
                ..mouse,
                x: mouse.x - rect.x,
                y: mouse.y - rect.y,
              }
              self.deliver(id, Mouse(inside)) |> ignore
            }
            None => ()
          }
      }
    }
    Resize(width, height) => {
      self.pending_resize = Some(@geom.Size::new(width, height))
      self.resize_at = self.driver.now()
    }
    FocusIn => ()
    FocusOut => ()
  }
}

///|
/// The node the pointer rests on, smallest first so a child wins over the
/// container that holds it. A move restyles the tree, so it marks a frame.
fn[D] App::track_hover(self : App[D], x : Int32, y : Int32) -> Unit {
  let mut found = -1
  let mut smallest = 0
  for id, rect in self.rects {
    if rect.contains(x, y) {
      if found < 0 || rect.area() < smallest {
        found = id
        smallest = rect.area()
      }
    }
  }
  if found != self.hover {
    self.hover = found
    self.wipe()
  }
}

///|
fn[D] App::deliver(self : App[D], id : Int32, msg : @widget.Msg) -> Bool {
  if id < 0 || self.off.contains(id) {
    return false
  }
  match self.root.find(id) {
    None => false
    Some(widget) => self.deliver_to(id, widget, msg)
  }
}

///|
fn[D] App::deliver_to(
  self : App[D],
  id : Int32,
  widget : &@widget.Widget,
  msg : @widget.Msg,
) -> Bool {
  if self.off.contains(id) {
    return false
  }
  let rect = self.rect_of(id)
  let content = match self.styled.get(id) {
    Some(res) => res.content_region(rect).size()
    None => rect.size()
  }
  let ctx = @widget.Ctx::new(id, content, focused=id == self.focus)
  let handled = widget.handle(ctx, msg)
  for out in ctx.asked() {
    self.act(out)
  }
  handled
}

///|
fn[D] App::act(self : App[D], out : @widget.Out) -> Unit {
  for handler in self.handlers {
    if handler(out) {
      return
    }
  }
  match out {
    Repaint(id~) => self.repaint(id)
    TakeFocus(id~) => self.give_focus(id)
    Quit => self.running = false
    _ => self.inbox.push(out)
  }
}

///|
fn[D] App::give_focus(self : App[D], id : Int32) -> Unit {
  if id == self.focus || self.off.contains(id) {
    return
  }
  let old = self.focus
  self.focus = id
  if old >= 0 {
    self.deliver(old, Focus(false)) |> ignore
    self.inbox.push(Blurred(id=old))
  }
  self.deliver(id, Focus(true)) |> ignore
  self.inbox.push(Focused(id~))
  self.ensure_visible(id)
  if old >= 0 {
    self.touch(old)
  }
  self.touch(id)
}

///|
fn[D] App::at(self : App[D], x : Int32, y : Int32) -> (Int32, @geom.Region)? {
  let mut found : (Int32, @geom.Region)? = None
  for id, rect in self.rects {
    if rect.contains(x, y) {
      match found {
        Some((_, best)) =>
          if rect.area() < best.area() {
            found = Some((id, rect))
          }
        None => found = Some((id, rect))
      }
    }
  }
  match found {
    Some((id, rect)) =>
      match self.root.find(id) {
        Some(_) => Some((id, rect))
        None => None
      }
    None => None
  }
}

///|
fn[D] App::fire_timers(self : App[D], now : Int32) -> Unit {
  if self.timers.length() == 0 {
    return
  }
  let keep : Array[Timer] = []
  for timer in self.timers {
    if now >= timer.at {
      let fire = timer.fire
      fire()
      if timer.repeat {
        keep.push({ ..timer, at: timer.at + timer.ms, })
      }
    } else {
      keep.push(timer)
    }
  }
  self.timers.clear()
  for timer in keep {
    self.timers.push(timer)
  }
}

///|
/// The rules and states that styles are resolved against right now.
fn[D] App::theme(self : App[D]) -> Theme {
  Theme::new(
    sheet=self.sheet,
    focus=self.focus,
    hover=self.hover,
    disabled=self.off,
    base=self.base,
  )
}

///|
/// Start, retarget, finish or drop the glides. A node joins when it carries a
/// transition and its place moved since the last frame; one already moving
/// picks the new target up from wherever it shows right now.
fn[D] App::update_anims(
  self : App[D],
  targets : Map[Int32, @geom.Region],
  now : Int32,
) -> Unit {
  let live : Map[Int32, Anim] = Map([])
  for id, rect in targets {
    let res = match self.styled.get(id) {
      Some(res) => res
      None => continue
    }
    if res.transition <= 0 {
      match self.anims.get(id) {
        Some(running) =>
          if now - running.start < running.ms {
            live[id] = running
          }
        None => ()
      }
      continue
    }
    match self.anims.get(id) {
      Some(running) => {
        if now - running.start >= running.ms &&
          running.to.x == rect.x &&
          running.to.y == rect.y {
          continue
        }
        if running.to.x == rect.x &&
          running.to.y == rect.y &&
          running.ms == res.transition {
          live[id] = running
        } else {
          live[id] = {
            from: running.at(now),
            to: rect,
            start: now,
            ms: res.transition,
          }
        }
      }
      None =>
        match self.prev_bare.get(id) {
          Some(prev) =>
            if prev.x != rect.x || prev.y != rect.y {
              live[id] = {
                from: prev,
                to: rect,
                start: now,
                ms: res.transition,
              }
            }
          None => ()
        }
    }
  }
  self.anims = live
}

///|
/// The quit key most terminal programs answer to. An application whose text
/// fields want it for copying passes another list, or `[]` and quits itself.
pub let ctrl_c : @event.Key = {
  code: Char(99),
  mods: { ctrl: true, alt: false, shift: false, },
}

///|
/// Escape, which readers expect to leave a screen, and which is handed to the
/// widget under the keyboard first: a dialog closes before the program does.
pub let esc : @event.Key = @event.Key::of(Escape)

///|
/// `q`, the other key readers try when they want out.
pub let q : @event.Key = @event.Key::of(Char(113))

///|
fn[D] App::scroll_key(self : App[D], key : @event.Key) -> Bool {
  let found = self.root.scroll_around(self.focus)
  let (host, state) = match found {
    None => return false
    Some(pair) => pair
  }
  ignore(host)
  let moved = match key.code {
    Up => state.scroll_by(dy=-1)
    Down => state.scroll_by(dy=1)
    PageUp => state.scroll_by(dy=-state.vh)
    PageDown => state.scroll_by(dy=state.vh)
    Left => state.scroll_by(dx=-1)
    Right => state.scroll_by(dx=1)
    Home => state.scroll_to(y=0)
    End => state.scroll_to(y=state.max_y())
    _ => false
  }
  if moved {
    self.touch(host)
    self.inbox.push(Scrolled(id=host, x=state.x, y=state.y))
  }
  moved
}

///|
const WHEEL_STEP : Int32 = 3

///|
fn[D] App::wheel(self : App[D], mouse : @event.Mouse) -> Unit {
  let mut handled = false
  match self.at(mouse.x, mouse.y) {
    Some((id, rect)) => {
      let inside = { ..mouse, x: mouse.x - rect.x, y: mouse.y - rect.y, }
      handled = self.deliver(id, Mouse(inside))
    }
    None => ()
  }
  if handled {
    return
  }
  let (dx, dy) = match mouse.kind {
    ScrollUp => (0, -WHEEL_STEP)
    ScrollDown => (0, WHEEL_STEP)
    ScrollLeft => (-WHEEL_STEP, 0)
    _ => (WHEEL_STEP, 0)
  }
  let mut host = -1
  let mut smallest = 0
  for id, _ in self.views {
    if self.off.contains(id) {
      continue
    }
    let rect = self.rect_of(id)
    if !rect.contains(mouse.x, mouse.y) {
      continue
    }
    if host < 0 || rect.area() < smallest {
      host = id
      smallest = rect.area()
    }
  }
  if host < 0 {
    return
  }
  match self.views.get(host) {
    Some(view) =>
      if view.state.scroll_by(dx~, dy~) {
        self.touch(host)
        self.inbox.push(Scrolled(id=host, x=view.state.x, y=view.state.y))
      }
    None => ()
  }
}

///|
/// Keep the node that just took focus inside every scroll container that
/// holds it, innermost first. The regions come from the last render, so this
/// runs only once a frame exists.
fn[D] App::ensure_visible(self : App[D], id : Int32) -> Unit {
  let mut target = id
  let mut depth = 0
  while depth < 8 {
    depth = depth + 1
    let found = self.root.scroll_around(target)
    let (host, state) = match found {
      None => return
      Some(pair) => pair
    }
    let rect = match self.bare.get(target) {
      None => return
      Some(rect) => rect
    }
    let host_area = match self.bare.get(host) {
      None => return
      Some(area) => area
    }
    let res = match self.styled.get(host) {
      None => return
      Some(res) => res
    }
    let content = res.content_region(host_area)
    let top = rect.y - content.y + state.y
    let bottom = top + rect.height
    let left = rect.x - content.x + state.x
    let right = left + rect.width
    let mut moved = false
    if top < state.y {
      moved = state.scroll_to(y=top) || moved
    } else if bottom > state.y + state.vh {
      moved = state.scroll_to(y=bottom - state.vh) || moved
    }
    if left < state.x {
      moved = state.scroll_to(x=left) || moved
    } else if right > state.x + state.vw {
      moved = state.scroll_to(x=right - state.vw) || moved
    }
    if moved {
      self.touch(host)
    }
    target = host
  }
}
