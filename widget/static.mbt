// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Text that does nothing. Every widget that only shows something is built on
/// this one, which is why it is the only place where plain text becomes lines.
pub struct Static {
  mut lines : Array[String]
  mut style : @style.Style
  align : Align
}

///|
/// Where a line sits when it is narrower than the widget.
pub(all) enum Align {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
/// Static text, split on newlines.
pub fn Static::new(
  text : String,
  style? : @style.Style = @style.default,
  align? : Align = Left,
) -> Static {
  { lines: split_lines(text), style, align, }
}

///|
/// Replace the text.
pub fn Static::set(self : Static, text : String) -> Unit {
  self.lines = split_lines(text)
}

///|
/// Replace the style.
pub fn Static::set_style(self : Static, style : @style.Style) -> Unit {
  self.style = style
}

///|
/// The text as it stands.
pub fn Static::text(self : Static) -> String {
  let out = StringBuilder()
  for i in 0..<self.lines.length() {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(self.lines[i])
  }
  out.to_string()
}

///|
pub impl Widget for Static with fn render_line(self, row, size) {
  if row < 0 || row >= self.lines.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  align_line(self.lines[row], size.width, self.align, self.style)
}

///|
pub impl Widget for Static with fn hint(self, _size) {
  let mut widest = 0
  for line in self.lines {
    let cells = @strip.str_cells(line)
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(widest, self.lines.length())
}

///|
pub impl Widget for Static with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Static with fn focusable(_self) {
  false
}

///|
/// One line of text. A label is static text that happens to be one line: the
/// distinction is what the caller means by it, not what it does.
pub fn label(text : String, style? : @style.Style = @style.default) -> Static {
  Static::new(text, style~)
}

///|
/// Place a line inside a width, padding the sides the alignment asks for.
pub fn align_line(
  text : String,
  width : Int,
  align : Align,
  style : @style.Style,
) -> @strip.Strip {
  let body = @strip.Strip::of(clip_to(text, width), style)
  let slack = width - body.cell_length()
  if slack <= 0 {
    return body
  }
  match align {
    Left => body.pad_to(width, style)
    Right => @strip.Strip::join([@strip.Strip::blank(slack, style), body])
    Center => {
      let left = slack / 2
      @strip.Strip::join([
        @strip.Strip::blank(left, style),
        body,
        @strip.Strip::blank(slack - left, style),
      ])
    }
  }
}

///|
/// Cut a string to a number of columns without splitting a wide character.
pub fn clip_to(text : String, width : Int) -> String {
  if @strip.str_cells(text) <= width {
    return text
  }
  text[0:@strip.cut_at(text, width)].to_owned()
}

///|
fn split_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  for i in 0..<text.length() {
    if text[i] == '\n' {
      out.push(text[start:i].to_owned())
      start = i + 1
    }
  }
  out.push(text[start:].to_owned())
  out
}

///|
pub extend Align with Debug::{to_repr}

///|
pub extend Align with Eq::{not_equal, equal}

///|
pub extend Static with Widget::{focusable, handle, hint, render_line}
