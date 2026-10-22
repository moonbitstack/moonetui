// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Static {
  mut lines : Array[String]
  mut style : @style.Style
  align : Align
}

///|
pub(all) enum Align {
  Left
  Centre
  Right
} derive(Eq, Debug)

///|
pub fn Static::new(
  text : String,
  style~ : @style.Style = @style.default,
  align~ : Align = Left,
) -> Static {
  { lines: split_lines(text), style, align, }
}

///|
pub fn Static::set(self : Static, text : String) -> Unit {
  self.lines = split_lines(text)
}

///|
pub fn Static::set_style(self : Static, style : @style.Style) -> Unit {
  self.style = style
}

///|
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
pub fn label(text : String, style~ : @style.Style = @style.default) -> Static {
  Static::new(text, style~)
}

///|
pub fn align_line(
  text : String,
  width : Int32,
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
    Centre => {
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
pub fn clip_to(text : String, width : Int32) -> String {
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
