// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Bytes as a reader of dumps expects them: the offset, the bytes in hex, and
/// the same bytes as text on the right.
///
/// The arrows walk a line or a screen, Home and End go to the ends, and the
/// wheel moves a line. A narrow view shows eight bytes a row, and narrower
/// still four, so the hex column always fits.
#derive(Eq, Debug)
pub struct HexView {
  data : Bytes
  mut offset : Int32
  mut focused : Bool
  per_row : Int32
  style : @style.Style
  offset_style : @style.Style
  hex_style : @style.Style
  ascii_style : @style.Style
}

///|
pub fn HexView::new(
  data~ : Bytes = b"",
  offset~ : Int32 = 0,
  per_row~ : Int32 = 16,
  style~ : @style.Style = @style.default,
  offset_style~ : @style.Style = @style.Style::new(dim=true),
  hex_style~ : @style.Style = @style.default,
  ascii_style~ : @style.Style = @style.Style::new(fg=@style.cyan),
) -> HexView {
  let view : HexView = {
    data,
    offset: 0,
    focused: false,
    per_row: if per_row < 1 {
      16
    } else {
      per_row
    },
    style,
    offset_style,
    hex_style,
    ascii_style,
  }
  view.set_offset(offset)
  view
}

///|
pub fn HexView::data(self : HexView) -> Bytes {
  self.data
}

///|
/// The byte the view starts at.
pub fn HexView::offset(self : HexView) -> Int32 {
  self.offset
}

///|
/// Start at a byte, held to the ones there are.
pub fn HexView::set_offset(self : HexView, offset : Int32) -> Unit {
  self.offset = constrain(offset, 0, self.last())
}

///|
/// The bytes on a row: what the caller asked for, cut down until a row fits
/// the width it is drawn at.
fn HexView::columns(self : HexView, width : Int32) -> Int32 {
  let mut count = self.per_row
  while count > 4 && 8 + 2 + count * 3 + 3 + count > width {
    count = count / 2
  }
  count
}

///|
/// The first byte of the last row, the furthest the view may start.
fn HexView::last(self : HexView) -> Int32 {
  let length = self.data.length()
  if length == 0 {
    0
  } else {
    (length - 1) / self.per_row * self.per_row
  }
}

///|
/// How many rows there are at a given width.
fn HexView::rows(self : HexView, width : Int32) -> Int32 {
  let columns = self.columns(width)
  let length = self.data.length()
  if length == 0 {
    1
  } else {
    (length + columns - 1) / columns
  }
}

///|
pub impl Widget for HexView with fn render_line(self, row, size) {
  if size.width <= 0 || row < 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let columns = self.columns(size.width)
  let start = self.offset + row * columns
  if start >= self.data.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let offset = hex_word(start)
  let hex = StringBuilder()
  let text = StringBuilder()
  for i in 0..<columns {
    let at = start + i
    if at < self.data.length() {
      let byte = self.data[at]
      hex.write_string(hex_byte(byte) + " ")
      let code = byte.to_int()
      text.write_string(
        if code >= 32 && code < 127 {
          code.unsafe_to_char().to_string()
        } else {
          "."
        },
      )
    } else {
      hex.write_string("   ")
      text.write_string(" ")
    }
    if i == columns / 2 - 1 {
      hex.write_string(" ")
    }
  }
  @strip.Strip::join([
    @strip.Strip::of(offset, self.offset_style),
    @strip.Strip::of("  " + hex.to_string(), self.hex_style),
    @strip.Strip::of("  " + text.to_string(), self.ascii_style),
  ]).pad_to(size.width, self.style)
}

///|
pub impl Widget for HexView with fn hint(_self, size) {
  @geom.Size::new(size.width, size.height)
}

///|
pub impl Widget for HexView with fn handle(self, ctx, msg) {
  let columns = self.columns(ctx.size.width)
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        let rows = self.rows(ctx.size.width)
        let by = match key.code {
          Up => -columns
          Down => columns
          Left => -1
          Right => 1
          PageUp => -at_least_one(rows - 1) * columns
          PageDown => at_least_one(rows - 1) * columns
          Home => -self.data.length()
          End => self.data.length()
          _ => return false
        }
        self.move_to(self.offset + by, ctx)
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          true
        }
        ScrollUp => self.move_to(self.offset - columns, ctx)
        ScrollDown => self.move_to(self.offset + columns, ctx)
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for HexView with fn focusable(_self) {
  true
}

///|
fn HexView::move_to(self : HexView, offset : Int32, ctx : Ctx) -> Bool {
  let next = constrain(offset, 0, self.last())
  if next == self.offset {
    return false
  }
  self.offset = next
  ctx.emit(Scrolled(id=ctx.id, x=0, y=next))
  ctx.repaint()
  true
}

///|
let digits : Array[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
]

///|
fn hex_byte(byte : Byte) -> String {
  let value = byte.to_int()
  digits[value / 16] + digits[value % 16]
}

///|
fn hex_word(value : Int32) -> String {
  let out = StringBuilder()
  for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
    out.write_string(digits[(value >> shift) & 0xF])
  }
  out.to_string()
}

///|
pub extend HexView with Debug::{to_repr}

///|
pub extend HexView with Eq::{not_equal, equal}

///|
pub extend HexView with Widget::{focusable, handle, hint, render_line}
