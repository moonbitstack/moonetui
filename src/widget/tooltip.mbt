// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Tooltip {
  mut content : String
  mut style : @style.Style
  max_width : Int32
  padding : Int32
} derive(Eq, Debug)

///|
pub extend Tooltip with Debug::{to_repr}

///|
pub extend Tooltip with Eq::{not_equal, equal}

///|
pub fn Tooltip::new(
  content : String,
  style~ : @style.Style = @style.default,
  max_width~ : Int32 = 40,
  padding~ : Int32 = 2,
) -> Tooltip {
  { content, style, max_width, padding, }
}

///|
pub fn Tooltip::set_content(self : Tooltip, content : String) -> Unit {
  self.content = content
}

///|
pub fn Tooltip::set_style(self : Tooltip, style : @style.Style) -> Unit {
  self.style = style
}

///|
pub fn Tooltip::wrapped(self : Tooltip, width : Int32) -> Array[String] {
  let inner = width - 2 * self.padding
  if inner <= 0 {
    return [self.content]
  }
  let out : Array[String] = []
  for chunk in split_lines(self.content) {
    for line in wrap_text(chunk, inner) {
      out.push(line)
    }
  }
  if out.length() == 0 {
    out.push("")
  }
  out
}

///|
pub impl Widget for Tooltip with fn render_line(self, row, size) {
  let lines = self.wrapped(size.width)
  let total = lines.length() + 2
  if row < 0 || row >= total {
    return @strip.Strip::blank(size.width, self.style)
  }
  if row == 0 || row > lines.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let pad = @strip.Strip::blank(self.padding, self.style)
  let body = @strip.Strip::of(lines[row - 1], self.style)
  @strip.Strip::join([pad, body, pad]).pad_to(size.width, self.style)
}

///|
pub impl Widget for Tooltip with fn hint(self, _size) {
  let lines = self.wrapped(self.max_width)
  let mut widest = 0
  for line in lines {
    let cells = @strip.str_cells(line)
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(widest + 2 * self.padding, lines.length() + 2)
}

///|
pub impl Widget for Tooltip with fn focusable(_self) {
  false
}

///|
pub impl Widget for Tooltip with fn handle(_self, _ctx, msg) {
  match msg {
    Key(_) | Mouse(_) => true
    _ => false
  }
}

///|
pub extend Tooltip with Widget::{focusable, handle, hint, render_line}
