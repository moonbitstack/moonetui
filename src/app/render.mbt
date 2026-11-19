// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A frame: place the tree, compose the rows that changed, write the spans that
// differ. A frame the damage list says is small composes only those rows, on
// the placements the last frame left behind.

///|
fn[D : @driver.Driver] App::render(self : App[D]) -> Unit raise {
  // A glide moves what is drawn every frame, so a frame with one running
  // places the tree again even though nothing in it asked to.
  if self.layout || self.anims.length() > 0 {
    self.reflow()
  }
  let damaged = self.damaged_rows()
  let all = self.wiped || self.prev.length() != self.size.height
  let rows : Array[@strip.Strip] = []
  if all {
    let composed = self.compose_all()
    for row in composed {
      rows.push(row)
    }
  } else {
    for row in self.prev {
      rows.push(row)
    }
    for y in damaged {
      rows[y] = self.compose_row(y)
    }
  }
  let spans = if all {
    if self.plain || self.prev.length() != rows.length() {
      @comp.full(rows)
    } else {
      @comp.diff(self.prev, rows, base=self.base)
    }
  } else {
    @comp.diff_rows(self.prev, rows, over=damaged, base=self.base)
  }
  self.emit(spans)
  self.prev = rows
  self.wiped = false
  self.damage.clear()
  self.layout = false
  self.dirty = self.anims.length() > 0
}

///|
fn[D : @driver.Driver] App::emit(
  self : App[D],
  spans : Array[@comp.Span],
) -> Unit raise {
  if self.plain {
    if spans.length() > 0 {
      self.driver.write(@comp.encode_stream(spans))
      self.driver.flush()
    }
    return
  }
  let caret = self.caret_now()
  if spans.length() == 0 && caret == self.caret {
    return
  }
  // Writing a frame moves the terminal's cursor, so it is hidden while the
  // spans go out and put back where the focused widget wants it after them.
  let out = StringBuilder()
  // Synchronized output (DEC mode 2026): a terminal that has it shows the frame
  // whole, one that lacks it ignores the two marks.
  out.write_string("\u{1b}[?2026h")
  if spans.length() > 0 {
    if self.caret is Some(_) {
      out.write_string(@comp.show_cursor(false))
    }
    out.write_string(@comp.encode(spans, self.base))
  }
  match caret {
    Some((y, x, look)) => {
      out.write_string(@comp.cursor_to(y, x))
      out.write_string(look.sequence())
      out.write_string(@comp.show_cursor(true))
      self.caret_shown = true
    }
    None =>
      if self.caret is Some(_) {
        out.write_string(@comp.show_cursor(false))
      }
  }
  out.write_string("\u{1b}[?2026l")
  self.driver.write(out.to_string())
  self.caret = caret
  self.driver.flush()
}

///|
/// Where the focused widget wants the terminal's cursor, on the screen: inside
/// its content, never on its frame or past it.
fn[D] App::caret_now(self : App[D]) -> (Int32, Int32, @widget.Caret)? {
  if self.focus < 0 || self.off.contains(self.focus) {
    return None
  }
  guard self.root.find(self.focus) is Some(widget) else { return None }
  let rect = self.rect_of(self.focus)
  let content = match self.styled.get(self.focus) {
    Some(res) => res.content_region(rect)
    None => rect
  }
  guard widget.caret(content.size()) is Some((at, look)) else { return None }
  if at.x < 0 || at.y < 0 || at.x >= content.width || at.y >= content.height {
    return None
  }
  Some((content.y + at.y, content.x + at.x, look))
}

///|
/// Lay the tree out again, and damage every row a node moved onto or off.
fn[D : @driver.Driver] App::reflow(self : App[D]) -> Unit {
  let screen = @geom.Region::new(0, 0, self.size.width, self.size.height)
  let scene = @comp.Scene::new(self.size)
  self.rects.clear()
  self.bare.clear()
  self.views.clear()
  self.styled.clear()
  let theme = self.theme()
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
  let now = self.driver.now()
  let targets : Map[Int32, @geom.Region] = Map([])
  for id, rect in self.bare {
    targets[id] = rect
  }
  self.update_anims(targets, now)
  if self.anims.length() > 0 {
    // A node that asked for a transition is shown gliding to its new place:
    // place once more, moved back by how far the glide still has to go. A
    // glide moves what is drawn every frame, so the frame is drawn whole.
    let offsets : Map[Int32, @geom.Offset] = Map([])
    for id, anim in self.anims {
      let shown = anim.at(now)
      offsets[id] = { x: shown.x - anim.to.x, y: shown.y - anim.to.y, }
    }
    let moved = @comp.Scene::new(self.size)
    let rects : Map[Int32, @geom.Region] = Map([])
    let bare : Map[Int32, @geom.Region] = Map([])
    let views : Map[Int32, View] = Map([])
    let styled : Map[Int32, @design.Resolved] = Map([])
    self.root.place(
      screen,
      screen,
      moved,
      rects,
      styled~,
      theme~,
      inherited=self.base,
      views~,
      bare~,
      offsets~,
    )
    self.rects = rects
    self.bare = bare
    self.views = views
    self.styled = styled
    self.scene = moved
    self.wiped = true
  } else {
    self.scene = scene
  }
  self.place_moved()
  self.prev_bare = targets
}

///|
/// The rows a node now sits on, and the rows it sat on before, are what a
/// relayout leaves to redraw: everything else is where it was.
fn[D] App::place_moved(self : App[D]) -> Unit {
  for id, rect in self.rects {
    let before = match self.prev_rects.get(id) {
      Some(old) => old
      None => @geom.Region::new(0, 0, 0, 0)
    }
    if before != rect {
      self.damage_region(before)
      self.damage_region(rect)
    }
  }
  for id, before in self.prev_rects {
    if !self.rects.contains(id) {
      self.damage_region(before)
    }
  }
  let keep : Map[Int32, @geom.Region] = Map([])
  for id, rect in self.rects {
    keep[id] = rect
  }
  self.prev_rects = keep
}

///|
fn[D] App::compose_row(self : App[D], y : Int32) -> @strip.Strip {
  self.scene.compose_line(
    y,
    fn(id, line) { self.draw_line(id, line) },
    self.base,
  )
}

///|
fn[D] App::compose_all(self : App[D]) -> Array[@strip.Strip] {
  self.scene.compose(fn(id, line) { self.draw_line(id, line) }, self.base)
}

///|
/// One line of one node, in the role the sheet gives it: a scroll container
/// draws its bars, anything else its frame, and a node the sheet says nothing
/// about draws its own line.
fn[D] App::draw_line(self : App[D], id : Int32, line : Int32) -> @strip.Strip {
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
            Some(widget) => widget.render_line(line, self.bare_of(id).size())
            None => @strip.Strip::empty()
          }
      }
  }
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
