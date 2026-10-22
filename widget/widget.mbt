// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum Msg {
  Key(@event.Key)
  Mouse(@event.Mouse)
  Paste(String)
  Focus(Bool)
  Tick(Int32)
} derive(Eq, Debug)

///|
pub(all) enum Out {
  Repaint(id~ : Int32)
  TakeFocus(id~ : Int32)
  Pressed(id~ : Int32)
  Changed(id~ : Int32, value~ : String)
  Selected(id~ : Int32, index~ : Int32)
  Quit
} derive(Eq, Debug)

///|
pub struct Ctx {
  id : Int32
  size : @geom.Size
  focused : Bool
  out : Array[Out]
}

///|
pub fn Ctx::new(id : Int32, size : @geom.Size, focused~ : Bool = false) -> Ctx {
  { id, size, focused, out: [], }
}

///|
pub fn Ctx::emit(self : Ctx, out : Out) -> Unit {
  self.out.push(out)
}

///|
pub fn Ctx::repaint(self : Ctx) -> Unit {
  self.emit(Repaint(id=self.id))
}

///|
pub fn Ctx::asked(self : Ctx) -> Array[Out] {
  self.out
}

///|
pub(open) trait Widget {
  fn render_line(Self, Int32, @geom.Size) -> @strip.Strip
  fn hint(Self, @geom.Size) -> @geom.Size
  fn handle(Self, Ctx, Msg) -> Bool
  fn focusable(Self) -> Bool
}

///|
pub(all) struct Border {
  top_left : String
  top : String
  top_right : String
  left : String
  right : String
  bottom_left : String
  bottom : String
  bottom_right : String
} derive(Eq, Debug)

///|
pub let thin : Border = {
  top_left: "┌",
  top: "─",
  top_right: "┐",
  left: "│",
  right: "│",
  bottom_left: "└",
  bottom: "─",
  bottom_right: "┘",
}

///|
pub let heavy : Border = {
  top_left: "┏",
  top: "━",
  top_right: "┓",
  left: "┃",
  right: "┃",
  bottom_left: "┗",
  bottom: "━",
  bottom_right: "┛",
}

///|
pub fn frame(
  border : Border,
  row : Int32,
  size : @geom.Size,
  style : @style.Style,
  inner : @strip.Strip,
) -> @strip.Strip {
  if size.width < 2 || size.height < 2 {
    return inner
  }
  if row == 0 || row == size.height - 1 {
    let left = if row == 0 { border.top_left } else { border.bottom_left }
    let right = if row == 0 { border.top_right } else { border.bottom_right }
    let edge = if row == 0 { border.top } else { border.bottom }
    let line = StringBuilder()
    line.write_string(left)
    for _ in 0..<(size.width - 2) {
      line.write_string(edge)
    }
    line.write_string(right)
    return @strip.Strip::of(line.to_string(), style)
  }
  @strip.Strip::join([
    @strip.Strip::of(border.left, style),
    inner.pad_to(size.width - 2, style),
    @strip.Strip::of(border.right, style),
  ])
}

///|
pub extend Border with Debug::{to_repr}

///|
pub extend Border with Eq::{not_equal, equal}

///|
pub extend Msg with Debug::{to_repr}

///|
pub extend Msg with Eq::{not_equal, equal}

///|
pub extend Out with Debug::{to_repr}

///|
pub extend Out with Eq::{not_equal, equal}
