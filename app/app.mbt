// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A running application: a widget tree, a terminal, and the state that turns
/// one into the other.
pub struct App[D] {
  driver : D
  root : Node
  parser : @input.Parser
  base : @style.Style
  frame_ms : Int
  rects : Map[Int, @geom.Region]
  inbox : Array[@widget.Out]
  mut size : @geom.Size
  mut focus : Int
  mut prev : Array[@strip.Strip]
  mut dirty : Bool
  mut running : Bool
  mut last_frame : Int
  mut pending_resize : @geom.Size?
  mut resize_at : Int
}

///|
/// How long a resize is allowed to settle before the screen is rebuilt. Dragging
/// a window edge produces a report per pixel; rebuilding the layout for each one
/// makes the drag crawl.
const RESIZE_SETTLE_MS : Int = 8

///|
/// An application over this terminal.
pub fn[D] App::new(
  driver : D,
  root : Node,
  base? : @style.Style = @style.default,
  fps? : Int = 60,
) -> App[D] {
  {
    driver,
    root,
    parser: @input.Parser::new(),
    base,
    frame_ms: if fps > 0 {
      1000 / fps
    } else {
      16
    },
    rects: Map([]),
    inbox: [],
    size: @geom.Size::new(80, 24),
    focus: -1,
    prev: [],
    dirty: true,
    running: false,
    last_frame: -100000,
    pending_resize: None,
    resize_at: 0,
  }
}

///|
/// Take over the terminal and draw the first frame.
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
}

///|
/// Give the terminal back.
pub fn[D : @driver.Driver] App::stop(self : App[D]) -> Unit raise {
  self.running = false
  self.driver.write(@driver.leave())
  self.driver.flush()
  self.driver.stop()
}

///|
/// Run one frame: read what the terminal has to say, let the widgets react, and
/// repaint if anything changed. Returns false once the application has quit.
pub fn[D : @driver.Driver] App::step(self : App[D]) -> Bool raise {
  if !self.running {
    return false
  }
  let chunk = self.driver.poll(self.frame_ms)
  let events : Array[@event.Event] = []
  if chunk.length() > 0 {
    self.parser.feed(chunk, events)
  } else {
    // Nothing arrived, so a lone escape is the Escape key rather than the start
    // of a sequence that never came.
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
  if self.dirty && now - self.last_frame >= self.frame_ms {
    self.render()
    self.last_frame = now
  }
  self.running
}

///|
/// Step until the application quits. A native program can call this; a browser
/// cannot, and calls `step` from its own frame callback instead.
pub fn[D : @driver.Driver] App::run(self : App[D]) -> Unit raise {
  self.start()
  while self.step() {

  }
  self.stop()
}

///|
/// Ask the application to quit after this frame.
pub fn[D] App::quit(self : App[D]) -> Unit {
  self.running = false
}

///|
/// Take everything the widgets have reported since the last call: presses,
/// edits, selections. The host reads these instead of registering callbacks.
pub fn[D] App::drain(self : App[D]) -> Array[@widget.Out] {
  let out : Array[@widget.Out] = []
  for item in self.inbox {
    out.push(item)
  }
  self.inbox.clear()
  out
}

///|
/// Which widget holds focus, or -1 when none does.
pub fn[D] App::focused(self : App[D]) -> Int {
  self.focus
}

///|
/// Move focus to the next focusable widget, wrapping round.
pub fn[D] App::focus_next(self : App[D], step : Int) -> Unit {
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
/// The area a node was last placed in.
pub fn[D] App::rect_of(self : App[D], id : Int) -> @geom.Region {
  match self.rects.get(id) {
    Some(rect) => rect
    None => @geom.Region::new(0, 0, 0, 0)
  }
}

///|
/// The screen as it stands, one string per row. What a test reads instead of a
/// terminal.
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
          _ => ()
        }
      }
    }
    Paste(text) => self.deliver(self.focus, Paste(text)) |> ignore
    Mouse(mouse) =>
      match self.at(mouse.x, mouse.y) {
        Some((id, rect)) => {
          let inside = { ..mouse, x: mouse.x - rect.x, y: mouse.y - rect.y, }
          self.deliver(id, Mouse(inside)) |> ignore
        }
        None => ()
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
/// Hand a message to a widget and act on whatever it asks for.
fn[D] App::deliver(self : App[D], id : Int, msg : @widget.Msg) -> Bool {
  if id < 0 {
    return false
  }
  match self.root.find(id) {
    None => false
    Some(widget) => {
      let rect = self.rect_of(id)
      let ctx = @widget.Ctx::new(id, rect.size(), focused=id == self.focus)
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
/// Move focus, telling both widgets about it. A widget learns it has focus the
/// same way it learns anything else, so nothing has to ask the application.
fn[D] App::give_focus(self : App[D], id : Int) -> Unit {
  if id == self.focus {
    return
  }
  let old = self.focus
  self.focus = id
  if old >= 0 {
    self.deliver(old, Focus(false)) |> ignore
  }
  self.deliver(id, Focus(true)) |> ignore
  self.dirty = true
}

///|
/// The front-most leaf covering a screen position.
fn[D] App::at(self : App[D], x : Int, y : Int) -> (Int, @geom.Region)? {
  let ring = self.root.focus_ring()
  ignore(ring)
  let mut found : (Int, @geom.Region)? = None
  for id, rect in self.rects {
    if rect.contains(x, y) {
      match found {
        // Deeper nodes are placed after their containers, and a smaller area
        // means further in, so the smallest match is the one the click is for.
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
  self.root.place(screen, screen, scene, self.rects)
  let rows = scene.compose(
    fn(id, line) {
      match self.root.find(id) {
        Some(widget) => widget.render_line(line, self.rect_of(id).size())
        None => @strip.Strip::empty()
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
/// Control-C quits. A terminal application that cannot be interrupted is a
/// terminal application people have to kill from another window.
fn quits(key : @event.Key) -> Bool {
  key.mods.ctrl && key.code == Char(99)
}
