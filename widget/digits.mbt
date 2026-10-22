// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Digits {
  mut value : String
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Digits::new(
  value~ : String = "",
  style~ : @style.Style = @style.Style::new(),
) -> Digits {
  { value, style, }
}

///|
pub fn Digits::value(self : Digits) -> String {
  self.value
}

///|
pub fn Digits::update(self : Digits, value : String) -> Unit {
  self.value = value
}

///|
pub fn Digits::width_of(value : String) -> Int32 {
  let mut width = 0
  let mut i = 0
  while i < value.length() {
    let (code, used) = @strip.code_at(value, i)
    if glyph_index(code) >= 0 {
      width = width + 3
    } else {
      width = width + 1
    }
    i = i + used
  }
  width
}

///|
pub impl Widget for Digits with fn render_line(self, row, size) {
  if row < 0 || row > 2 || size.width <= 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let out = StringBuilder()
  let table = if self.style.attrs.bold { bold_rows } else { plain_rows }
  let mut i = 0
  while i < self.value.length() {
    let (code, used) = @strip.code_at(self.value, i)
    let shown = if code == 0x2E { 0x2022 } else { code }
    let index = glyph_index(shown)
    if index >= 0 {
      out.write_string(pad3(table[index * 3 + row]))
    } else if row < 2 {
      out.write_string(" ")
    } else {
      out.write_string(text_of(shown))
    }
    i = i + used
  }
  align_line(clip_to(out.to_string(), size.width), size.width, Left, self.style)
}

///|
pub impl Widget for Digits with fn hint(self, _size) {
  @geom.Size::new(Digits::width_of(self.value), 3)
}

///|
pub impl Widget for Digits with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Digits with fn focusable(_self) {
  false
}

///|
let glyph_chars : String = " 0123456789+-^x:ABCDEF$£€()"

///|
fn glyph_index(code : Int32) -> Int32 {
  let mut i = 0
  let mut at = 0
  while i < glyph_chars.length() {
    let (known, used) = @strip.code_at(glyph_chars, i)
    if known == code {
      return at
    }
    i = i + used
    at = at + 1
  }
  -1
}

///|
fn pad3(text : String) -> String {
  let out = StringBuilder()
  out.write_string(text)
  while @strip.str_cells(out.to_string()) < 3 {
    out.write_char(' ')
  }
  out.to_string()
}

///|
let plain_rows : Array[String] = [
  "", "", "", "╭─╮", "│ │", "╰─╯", "╶╮", " │", "╶┴╴",
  "╶─╮", "┌─┘", "╰─╴", "╶─╮", " ─┤", "╶─╯", "╷ ╷",
  "╰─┤", "  ╵", "╭─╴", "╰─╮", "╶─╯", "╭─╴", "├─╮",
  "╰─╯", "╶─┐", "  │", "  ╵", "╭─╮", "├─┤", "╰─╯",
  "╭─╮", "╰─┤", "╶─╯", "", "╶┼╴", "", "", "", "╶─╴",
  "", " ^", "", "", " ×", "", "", " :", "", "╭─╮", "├─┤", "╵ ╵",
  "┌─╮", "├─┤", "└─╯", "╭─╮", "│", "╰─╯", "┌─╮",
  "│ │", "└─╯", "╭─╴", "├─", "╰─╴", "╭─╴", "├─",
  "╵", "╭╫╮", "╰╫╮", "╰╫╯", "╭─╮", "╪═", "┷━╸",
  "╭─╮", "╪═", "╰─╯", "╭╴ ", "│  ", "╰╴ ", " ╶╮ ",
  "  │ ", " ╶╯ ",
]

///|
let bold_rows : Array[String] = [
  "", "", "", "┏━┓", "┃ ┃", "┗━┛", "╺┓", " ┃", "╺┻╸",
  "╺━┓", "┏━┛", "┗━╸", "╺━┓", " ━┫", "╺━┛", "╻ ╻",
  "┗━┫", "  ╹", "┏━╸", "┗━┓", "╺━┛", "┏━╸", "┣━┓",
  "┗━┛", "╺━┓", "  ┃", "  ╹", "┏━┓", "┣━┫", "┗━┛",
  "┏━┓", "┗━┫", "╺━┛", "", "╺╋╸", "", "", "", "╺━╸",
  "", " ^", "", "", " ×", "", "", " :", "", "╭─╮", "├─┤", "╵ ╵",
  "┌─╮", "├─┤", "└─╯", "╭─╮", "│", "╰─╯", "┌─╮",
  "│ │", "└─╯", "╭─╴", "├─", "╰─╴", "╭─╴", "├─",
  "╵", "╭╫╮", "╰╫╮", "╰╫╯", "╭─╮", "╪═", "┷━╸",
  "╭─╮", "╪═", "╰─╯", "╭╴ ", "│  ", "╰╴ ", " ╶╮ ",
  "  │ ", " ╶╯ ",
]

///|
pub extend Digits with Debug::{to_repr}

///|
pub extend Digits with Eq::{not_equal, equal}

///|
pub extend Digits with Widget::{focusable, handle, hint, render_line}
