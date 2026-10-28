// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A bar on its own: how much there is, how much of it shows, and how far
/// into it the view has gone. It is driven by plain numbers, so it works with
/// any view a caller keeps, not only with the scroll containers of the tree.
///
/// A click on the track goes to that part of the content, and the keys move
/// by a line or by a view once the bar has been given focus.
pub struct Scrollbar {
  mut position : Int32
  mut content : Int32
  mut viewport : Int32
  vertical : Bool
  style : @style.Style
  thumb_style : @style.Style
  track_style : @style.Style
}

///|
pub fn Scrollbar::new(
  content~ : Int32 = 0,
  viewport~ : Int32 = 0,
  position~ : Int32 = 0,
  vertical~ : Bool = true,
  style~ : @style.Style = @style.default,
  thumb_style~ : @style.Style = @style.Style::new(reverse=true),
  track_style~ : @style.Style = @style.Style::new(dim=true),
) -> Scrollbar {
  let bar : Scrollbar = {
    position: 0,
    content: 0,
    viewport: 0,
    vertical,
    style,
    thumb_style,
    track_style,
  }
  bar.set(content~, viewport~, position~)
  bar
}

///|
pub fn Scrollbar::set(
  self : Scrollbar,
  content~ : Int32,
  viewport~ : Int32,
  position~ : Int32,
) -> Unit {
  self.content = if content < 0 { 0 } else { content }
  self.viewport = if viewport < 0 { 0 } else { viewport }
  self.position = constrain(position, 0, self.max())
}

///|
pub fn Scrollbar::position(self : Scrollbar) -> Int32 {
  self.position
}

///|
pub fn Scrollbar::content(self : Scrollbar) -> Int32 {
  self.content
}

///|
pub fn Scrollbar::viewport(self : Scrollbar) -> Int32 {
  self.viewport
}

///|
pub fn Scrollbar::is_vertical(self : Scrollbar) -> Bool {
  self.vertical
}

///|
/// How far the view can go before it reaches the end.
pub fn Scrollbar::max(self : Scrollbar) -> Int32 {
  let slack = self.content - self.viewport
  if slack < 0 {
    0
  } else {
    slack
  }
}

///|
/// Whether there is anything to scroll at all.
pub fn Scrollbar::is_needed(self : Scrollbar) -> Bool {
  self.max() > 0
}

///|
/// Where the thumb starts and how long it is, in a bar `length` cells long.
pub fn Scrollbar::thumb(self : Scrollbar, length : Int32) -> (Int32, Int32) {
  if length <= 0 || self.content <= 0 {
    return (0, 0)
  }
  let span = length * self.viewport / self.content
  let span = if span < 1 { 1 } else { span }
  let span = if span > length { length } else { span }
  let room = length - span
  let at = if self.max() == 0 { 0 } else { self.position * room / self.max() }
  (at, span)
}

///|
/// How many cells the bar itself is: along its own axis, whatever the box.
fn Scrollbar::axis_length(self : Scrollbar, size : @geom.Size) -> Int32 {
  if self.vertical {
    size.height
  } else {
    size.width
  }
}

///|
pub impl Widget for Scrollbar with fn render_line(self, row, size) {
  let length = self.axis_length(size)
  let (at, span) = self.thumb(length)
  let cells : Array[@strip.Strip] = []
  for i in 0..<length {
    let on = i >= at && i < at + span
    let glyph = if on { "█" } else { "░" }
    let ink = if on { self.thumb_style } else { self.track_style }
    cells.push(@strip.Strip::of(glyph, ink))
  }
  let bar = @strip.Strip::join(cells)
  if self.vertical {
    if row < 0 || row >= length {
      return @strip.Strip::blank(1, self.style)
    }
    bar.crop(row, row + 1)
  } else {
    if row != 0 {
      return @strip.Strip::blank(size.width, self.style)
    }
    bar.pad_to(size.width, self.style)
  }
}

///|
pub impl Widget for Scrollbar with fn hint(self, size) {
  if self.vertical {
    @geom.Size::new(1, size.height)
  } else {
    @geom.Size::new(size.width, 1)
  }
}

///|
pub impl Widget for Scrollbar with fn handle(self, ctx, msg) {
  let length = self.axis_length(ctx.size)
  match msg {
    Key(key) =>
      if key.mods.is_none() {
        let by = match key.code {
          Up | Left => -1
          Down | Right => 1
          PageUp => -at_least_one(self.viewport)
          PageDown => at_least_one(self.viewport)
          Home => -self.content
          End => self.content
          _ => return false
        }
        self.move_by(by, ctx)
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let along = if self.vertical { mouse.y } else { mouse.x }
          let (_, span) = self.thumb(length)
          let room = at_least_zero(length - span)
          self.move_to(
            if room == 0 {
              0
            } else {
              (along - span / 2) * self.max() / room
            },
            ctx,
          )
          |> ignore
          true
        }
        ScrollUp => {
          self.move_by(-1, ctx) |> ignore
          true
        }
        ScrollDown => {
          self.move_by(1, ctx) |> ignore
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Scrollbar with fn focusable(_self) {
  true
}

///|

///|

///|
/// Whether the view moved, which is what the keys answer with.
fn Scrollbar::move_to(self : Scrollbar, place : Int32, ctx : Ctx) -> Bool {
  let next = constrain(place, 0, self.max())
  if next == self.position {
    return false
  }
  self.position = next
  self.report(ctx)
  true
}

///|
fn Scrollbar::move_by(self : Scrollbar, by : Int32, ctx : Ctx) -> Bool {
  self.move_to(self.position + by, ctx)
}

///|
fn Scrollbar::report(self : Scrollbar, ctx : Ctx) -> Unit {
  if self.vertical {
    ctx.emit(Scrolled(id=ctx.id, x=0, y=self.position))
  } else {
    ctx.emit(Scrolled(id=ctx.id, x=self.position, y=0))
  }
  ctx.repaint()
}

///|
pub extend Scrollbar with Widget::{focusable, handle, hint, render_line}
