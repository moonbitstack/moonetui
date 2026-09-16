// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What reaches a widget. A message is already interpreted — the parser turned
/// bytes into keys long before this — so a widget never looks at an escape
/// sequence.
pub(all) enum Msg {
  Key(@event.Key)
  Mouse(@event.Mouse)
  Paste(String)
  /// The widget gained or lost focus.
  Focus(Bool)
  /// Time passed; the argument is milliseconds since the last tick.
  Tick(Int)
} derive(Eq, Debug)

///|
/// What a widget asks the application for. These are values rather than
/// callbacks so that a widget's whole reaction to a message can be written down
/// and compared in a test.
pub(all) enum Out {
  Repaint(id~ : Int)
  TakeFocus(id~ : Int)
  Pressed(id~ : Int)
  Changed(id~ : Int, value~ : String)
  Selected(id~ : Int, index~ : Int)
  Quit
} derive(Eq, Debug)

///|
/// What a widget is told about itself while it handles a message, and where it
/// puts what it wants done.
pub struct Ctx {
  id : Int
  size : @geom.Size
  focused : Bool
  out : Array[Out]
}

///|
/// A context for the widget with this id, at this size.
pub fn Ctx::new(id : Int, size : @geom.Size, focused? : Bool = false) -> Ctx {
  { id, size, focused, out: [], }
}

///|
/// Ask the application for something.
pub fn Ctx::emit(self : Ctx, out : Out) -> Unit {
  self.out.push(out)
}

///|
/// Ask to be repainted.
pub fn Ctx::repaint(self : Ctx) -> Unit {
  self.emit(Repaint(id=self.id))
}

///|
/// Everything asked for so far.
pub fn Ctx::asked(self : Ctx) -> Array[Out] {
  self.out
}

///|
/// Something that draws itself a line at a time and reacts to messages.
///
/// `render_line` is given a row inside the widget and the size the widget was
/// placed at, and returns that row. Drawing one line at a time is what lets the
/// compositor ask only for the rows it needs, and what keeps a widget that is
/// mostly off-screen cheap.
pub(open) trait Widget {
  fn render_line(Self, Int, @geom.Size) -> @strip.Strip
  /// What the widget would like to be, given the space on offer. A layout uses
  /// it for automatic sizes.
  fn hint(Self, @geom.Size) -> @geom.Size
  /// Handle a message; true means it was dealt with and should not travel any
  /// further.
  fn handle(Self, Ctx, Msg) -> Bool
  /// Whether the widget can hold keyboard focus.
  fn focusable(Self) -> Bool
}

///|
/// The four corners and four edges of a border, in the order a drawing routine
/// needs them.
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
/// A single-line border.
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
/// A heavier border, for the widget that has focus.
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
/// Wrap one already-rendered row in a border.
///
/// `row` counts the border: row zero is the top edge, the last row is the
/// bottom edge, and the rows between hold `inner`, which the caller renders at
/// two columns narrower.
pub fn frame(
  border : Border,
  row : Int,
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
