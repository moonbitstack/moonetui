// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct App[D] {
  driver : D
  root : Node
  parser : @input.Parser
  base : @style.Style
  sheet : @design.Stylesheet
  frame_ms : Int32
  rects : Map[Int32, @geom.Region]
  bare : Map[Int32, @geom.Region]
  views : Map[Int32, View]
  styled : Map[Int32, @design.Resolved]
  inbox : Array[@widget.Out]
  mut size : @geom.Size
  mut focus : Int32
  mut prev : Array[@strip.Strip]
  mut dirty : Bool
  mut running : Bool
  mut last_frame : Int32
  mut pending_resize : @geom.Size?
  mut resize_at : Int32
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
) -> App[D] {
  {
    driver,
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
    size: @geom.Size::new(80, 24),
    focus: -1,
    prev: [],
    dirty: true,
    running: false,
    last_frame: 0,
    pending_resize: None,
    resize_at: 0,
  }
}

///|
pub fn[D : @driver.Driver] App::start(self : App[D]) -> Unit raise {
  self.driver.start()
  self.driver.write(@driver.enter())
  self.size = self.driver.size()
  self.running = true
  self.dirty = true
  self.prev = []
  let ring = self.root.focus_ring()
  if ring.length() > 0 {
    self.give_focus(ring[0])
  }
  self.render()
  self.last_frame = self.driver.now()
}

///|
pub fn[D : @driver.Driver] App::stop(self : App[D]) -> Unit raise {
  self.running = false
  self.driver.write(@driver.leave())
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
  match self.pending_resize {
    Some(size) =>
      if now - self.resize_at >= RESIZE_SETTLE_MS {
        self.size = size
        self.pending_resize = None
        self.prev = []
        self.dirty = true
      }
    None => ()
  }
  let since = now - self.last_frame
  if self.dirty && (since < 0 || since >= self.frame_ms) {
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
pub fn[D] App::refresh(self : App[D]) -> Unit {
  self.dirty = true
}

///|
pub fn[D] App::focused(self : App[D]) -> Int32 {
  self.focus
}

///|
pub fn[D] App::focus_next(self : App[D], step : Int32) -> Unit {
  let ring = self.root.focus_ring()
  if ring.length() == 0 {
    return
  }
  let mut at = -1
  for i in 0..<ring.length() {
    if ring[i] == self.focus {
      at = i
    }
  }
  let count = ring.length()
  let next = if at < 0 {
    if step > 0 {
      0
    } else {
      count - 1
    }
  } else {
    ((at + step) % count + count) % count
  }
  self.give_focus(ring[next])
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
      if quits(key) {
        self.running = false
        return
      }
      let handled = self.deliver(self.focus, Key(key))
      if !handled {
        match key.code {
          Tab => self.focus_next(1)
          BackTab => self.focus_next(-1)
          _ => self.scroll_key(key) |> ignore
        }
      }
    }
    Paste(text) => self.deliver(self.focus, Paste(text)) |> ignore
    Mouse(mouse) =>
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
    Resize(width, height) => {
      self.pending_resize = Some(@geom.Size::new(width, height))
      self.resize_at = self.driver.now()
    }
    FocusIn => ()
    FocusOut => ()
  }
}

///|
fn[D] App::deliver(self : App[D], id : Int32, msg : @widget.Msg) -> Bool {
  if id < 0 {
    return false
  }
  match self.root.find(id) {
    None => false
    Some(widget) => {
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
  }
}

///|
fn[D] App::act(self : App[D], out : @widget.Out) -> Unit {
  match out {
    Repaint(..) => self.dirty = true
    TakeFocus(id~) => self.give_focus(id)
    Quit => self.running = false
    _ => self.inbox.push(out)
  }
}

///|
fn[D] App::give_focus(self : App[D], id : Int32) -> Unit {
  if id == self.focus {
    return
  }
  let old = self.focus
  self.focus = id
  if old >= 0 {
    self.deliver(old, Focus(false)) |> ignore
  }
  self.deliver(id, Focus(true)) |> ignore
  self.ensure_visible(id)
  self.dirty = true
}

///|
fn[D] App::at(self : App[D], x : Int32, y : Int32) -> (Int32, @geom.Region)? {
  let ring = self.root.focus_ring()
  ignore(ring)
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
fn[D : @driver.Driver] App::render(self : App[D]) -> Unit raise {
  let screen = @geom.Region::new(0, 0, self.size.width, self.size.height)
  let scene = @comp.Scene::new(self.size)
  self.rects.clear()
  self.bare.clear()
  self.views.clear()
  self.styled.clear()
  let theme = Theme::new(sheet=self.sheet, focus=self.focus, base=self.base)
  self.root.place(
    screen,
    screen,
    scene,
    self.rects,
    styled=self.styled,
    theme~,
    inherited=self.base,
    views=self.views,
    bare=self.bare,
  )
  let rows = scene.compose(
    fn(id, line) {
      match self.views.get(id) {
        Some(view) =>
          match self.styled.get(id) {
            Some(res) => self.bar_line(id, line, res, view)
            None => @strip.Strip::empty()
          }
        None =>
          match self.styled.get(id) {
            Some(res) => self.dress_line(id, line, res)
            None =>
              match self.root.find(id) {
                Some(widget) =>
                  widget.render_line(line, self.bare_of(id).size())
                None => @strip.Strip::empty()
              }
          }
      }
    },
    self.base,
  )
  let spans = if self.prev.length() != rows.length() {
    @comp.full(rows)
  } else {
    @comp.diff(self.prev, rows, base=self.base)
  }
  if spans.length() > 0 {
    self.driver.write(@comp.encode(spans, self.base))
    self.driver.flush()
  }
  self.prev = rows
  self.dirty = false
}

///|
fn[D] App::dress_line(
  self : App[D],
  id : Int32,
  line : Int32,
  res : @design.Resolved,
) -> @strip.Strip {
  let rect = self.bare_of(id)
  let decor : @design.Decor = {
    border: res.border,
    style: res.text,
    size: rect.size(),
  }
  match self.root.find(id) {
    None => decor.line(line)
    Some(widget) => {
      let ring = match res.border {
        @design.Off => 0
        _ => 1
      }
      let size = rect.size()
      let inner = @geom.Size::new(
        at_least_zero(size.width - 2 * ring - res.padding.width()),
        at_least_zero(size.height - 2 * ring - res.padding.height()),
      )
      let content_row = line - ring - res.padding.top
      let content : @strip.Strip? = if content_row >= 0 &&
        content_row < inner.height {
        Some(widget.render_line(content_row, inner).apply(res.text))
      } else {
        None
      }
      decor.frame_line(res.padding, line, content)
    }
  }
}

///|
fn quits(key : @event.Key) -> Bool {
  key.mods.ctrl && key.code == Char(99)
}

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
    Home => state.scroll_to(y=Some(0))
    End => state.scroll_to(y=Some(state.max_y()))
    _ => false
  }
  if moved {
    self.dirty = true
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
    Some(view) => if view.state.scroll_by(dx~, dy~) { self.dirty = true }
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
      moved = state.scroll_to(y=Some(top)) || moved
    } else if bottom > state.y + state.vh {
      moved = state.scroll_to(y=Some(bottom - state.vh)) || moved
    }
    if left < state.x {
      moved = state.scroll_to(x=Some(left)) || moved
    } else if right > state.x + state.vw {
      moved = state.scroll_to(x=Some(right - state.vw)) || moved
    }
    if moved {
      self.dirty = true
    }
    target = host
  }
}

///|
fn[D] App::bar_line(
  self : App[D],
  id : Int32,
  line : Int32,
  res : @design.Resolved,
  view : View,
) -> @strip.Strip {
  let rect = self.bare_of(id)
  let state = view.state
  let decor : @design.Decor = {
    border: res.border,
    style: res.text,
    size: rect.size(),
  }
  let ring = match res.border {
    @design.Off => 0
    _ => 1
  }
  let size = rect.size()
  let inner = @geom.Size::new(
    at_least_zero(size.width - 2 * ring - res.padding.width()),
    at_least_zero(size.height - 2 * ring - res.padding.height()),
  )
  let row = line - ring - res.padding.top
  let content : @strip.Strip? = if row < 0 ||
    row >= inner.height ||
    inner.width <= 0 ||
    inner.height <= 0 {
    None
  } else {
    let mut strip = @strip.Strip::blank(inner.width, res.text)
    if view.hbar && row == inner.height - 1 {
      let span = int_max(1, state.vw * state.vw / state.cw)
      let left = if state.max_x() == 0 {
        0
      } else {
        state.x * (state.vw - span) / state.max_x()
      }
      strip = @strip.Strip::join([
        @strip.Strip::blank(left, res.text),
        @strip.Strip::of(repeat_glyph("█", span), view.bar),
        @strip.Strip::blank(inner.width - left - span, res.text),
      ])
    }
    if view.vbar && row < state.vh {
      let span = int_max(1, state.vh * state.vh / state.ch)
      let top = if state.max_y() == 0 {
        0
      } else {
        state.y * (state.vh - span) / state.max_y()
      }
      let thumb = top <= row && row < top + span
      strip = @strip.Strip::join([
        strip.crop(0, inner.width - 1),
        @strip.Strip::of(
          if thumb {
            "█"
          } else {
            "░"
          },
          if thumb {
            view.bar
          } else {
            res.text
          },
        ),
      ])
    }
    Some(strip)
  }
  decor.frame_line(res.padding, line, content)
}
