// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Cell {
  text : String
  style : @style.Style
} derive(Eq, Debug)

///|
/// The screen an escape stream draws: cells, the cursor, the style in force and
/// the private modes the stream has set.
///
/// It reads the ECMA-48 subset a full-screen application writes — cursor
/// addressing and movement, erasing, SGR, private modes — and skips string
/// sequences (OSC, DCS, APC, PM, SOS) whole, so a title or a hyperlink never
/// lands on the screen as text. A sequence cut off at the end of a write is kept
/// and finished by the next one.
struct Grid {
  mut width : Int32
  mut height : Int32
  mut cells : Array[Cell]
  mut dirty : Array[Bool]
  mut cursor_x : Int32
  mut cursor_y : Int32
  mut current : @style.Style
  mut pending : String
  modes : Map[Int32, Bool]
}

///|
pub fn Grid::new(width : Int32, height : Int32) -> Grid {
  let grid = {
    width,
    height,
    cells: [],
    dirty: [],
    cursor_x: 0,
    cursor_y: 0,
    current: @style.default,
    pending: "",
    modes: {},
  }
  grid.resize(width, height)
  grid
}

///|
pub fn Grid::width(self : Grid) -> Int32 {
  self.width
}

///|
pub fn Grid::height(self : Grid) -> Int32 {
  self.height
}

///|
/// Where the next character will land, as `(x, y)` from the top left.
pub fn Grid::cursor(self : Grid) -> (Int32, Int32) {
  (self.cursor_x, self.cursor_y)
}

///|
/// Whether DEC private mode `n` is set: 25 shows the cursor, 1000 to 1003 report
/// the mouse, 1006 reports it in SGR form, 2004 brackets pastes. A terminal
/// starts with the cursor shown and everything else off.
pub fn Grid::mode(self : Grid, n : Int32) -> Bool {
  match self.modes.get(n) {
    Some(on) => on
    None => n == 25
  }
}

///|
pub fn Grid::resize(self : Grid, width : Int32, height : Int32) -> Unit {
  self.width = if width < 1 { 1 } else { width }
  self.height = if height < 1 { 1 } else { height }
  let count = self.width * self.height
  self.cells = Array::make(count, blank(@style.default))
  self.dirty = Array::make(count, true)
  self.cursor_x = 0
  self.cursor_y = 0
}

///|
pub fn Grid::at(self : Grid, x : Int32, y : Int32) -> Cell {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    return blank(@style.default)
  }
  self.cells[y * self.width + x]
}

///|
pub fn Grid::rows(self : Grid) -> Array[String] {
  Array::makei(self.height, y => {
    let line = StringBuilder()
    for x in 0..<self.width {
      line.write_string(self.at(x, y).text)
    }
    line.to_string()
  })
}

///|
/// The cells that changed since the last call, as `(x, y)`, row by row.
pub fn Grid::take_dirty(self : Grid) -> Array[(Int32, Int32)] {
  let out : Array[(Int32, Int32)] = []
  for i, d in self.dirty {
    if d {
      out.push((i % self.width, i / self.width))
      self.dirty[i] = false
    }
  }
  out
}

///|
pub fn Grid::dirty_all(self : Grid) -> Unit {
  self.dirty.fill(true)
}

///|
pub fn Grid::write(self : Grid, incoming : String) -> Unit {
  let text = if self.pending.length() > 0 {
    self.pending + incoming
  } else {
    incoming
  }
  self.pending = ""
  let mut i = 0
  while i < text.length() {
    let unit = text[i].to_int()
    if unit == 0x1B {
      let used = self.escape(text, i)
      if used == 0 {
        self.pending = text[i:].to_owned()
        return
      }
      i = i + used
      continue
    }
    let (code, used) = @strip.code_at(text, i)
    match code {
      0x0A => {
        self.cursor_x = 0
        self.line_feed()
      }
      0x0D => self.cursor_x = 0
      0x08 => if self.cursor_x > 0 { self.cursor_x -= 1 }
      0x09 =>
        self.cursor_x = @cmp.minimum(
          (self.cursor_x / 8 + 1) * 8,
          self.width - 1,
        )
      _ if code >= 0x20 => self.put(code, text[i:i + used].to_owned())
      _ => ()
    }
    i = i + used
  }
}

///|
fn blank(style : @style.Style) -> Cell {
  { text: " ", style, }
}

///|
fn Grid::set(self : Grid, x : Int32, y : Int32, cell : Cell) -> Unit {
  let at = y * self.width + x
  self.cells[at] = cell
  self.dirty[at] = true
}

///|
/// Move down a row, scrolling the screen up when the cursor is on the last one.
fn Grid::line_feed(self : Grid) -> Unit {
  if self.cursor_y + 1 < self.height {
    self.cursor_y += 1
    return
  }
  let w = self.width
  for at in 0..<(self.cells.length() - w) {
    self.cells[at] = self.cells[at + w]
  }
  for at in (self.cells.length() - w)..<self.cells.length() {
    self.cells[at] = blank(self.current)
  }
  self.dirty_all()
  self.cursor_y = self.height - 1
}

///|
fn Grid::put(self : Grid, code : Int32, body : String) -> Unit {
  let width = @strip.cell_width(code)
  if width == 0 {
    let x = self.cursor_x - 1
    if x >= 0 && x < self.width {
      let old = self.at(x, self.cursor_y)
      self.set(x, self.cursor_y, { ..old, text: old.text + body, })
    }
    return
  }
  if self.cursor_x + width > self.width {
    self.cursor_x = 0
    self.line_feed()
  }
  self.set(self.cursor_x, self.cursor_y, { text: body, style: self.current, })
  if width == 2 {
    self.set(self.cursor_x + 1, self.cursor_y, {
      text: "",
      style: self.current,
    })
  }
  self.cursor_x += width
}

///|
/// Read one escape sequence starting at `at` and return how many units it took;
/// zero means it runs past the end of `text` and must wait for the next write.
fn Grid::escape(self : Grid, text : String, at : Int32) -> Int32 {
  if at + 1 >= text.length() {
    return 0
  }
  match text[at + 1].to_int() {
    0x5B => self.csi(text, at)
    0x5D | 0x50 | 0x58 | 0x5E | 0x5F =>
      match string_end(text, at + 2) {
        Some(end) => end - at
        None => 0
      }
    0x28 | 0x29 | 0x2A | 0x2B => if at + 2 < text.length() { 3 } else { 0 }
    _ => 2
  }
}

///|
/// Where a string sequence ends: just after BEL or after ESC `\`. `None` while
/// neither has arrived.
fn string_end(text : String, from : Int32) -> Int32? {
  let mut i = from
  while i < text.length() {
    let c = text[i].to_int()
    if c == 0x07 {
      return Some(i + 1)
    }
    if c == 0x1B && i + 1 < text.length() && text[i + 1].to_int() == 0x5C {
      return Some(i + 2)
    }
    i += 1
  }
  None
}

///|
fn Grid::csi(self : Grid, text : String, at : Int32) -> Int32 {
  let params : Array[Int32] = []
  let mut value = -1
  let mut private = false
  let mut intermediate = false
  let mut i = at + 2
  while i < text.length() {
    let c = text[i].to_int()
    if c >= 0x30 && c <= 0x39 {
      value = (if value < 0 { 0 } else { value }) * 10 + (c - 0x30)
    } else if c == 0x3B {
      params.push(if value < 0 { 0 } else { value })
      value = -1
    } else if c >= 0x3C && c <= 0x3F {
      private = true
    } else if c >= 0x20 && c <= 0x2F {
      intermediate = true
    } else if c >= 0x40 && c <= 0x7E {
      if value >= 0 {
        params.push(value)
      }
      if intermediate {
        ()
      } else if private {
        self.private(params, c)
      } else {
        self.apply(params, c)
      }
      return i + 1 - at
    } else {
      return 2
    }
    i += 1
  }
  0
}

///|
fn Grid::private(self : Grid, params : Array[Int32], last : Int32) -> Unit {
  let on = match last {
    0x68 => true
    0x6C => false
    _ => return
  }
  for n in params {
    self.modes[n] = on
    if n == 1049 || n == 1047 || n == 47 {
      self.erase(0, self.cells.length())
    }
  }
}

///|
fn Grid::apply(self : Grid, params : Array[Int32], last : Int32) -> Unit {
  let n = param(params, 0, 1)
  match last {
    0x48 | 0x66 => self.move_to(param(params, 1, 1) - 1, n - 1)
    0x41 => self.move_to(self.cursor_x, self.cursor_y - n)
    0x42 => self.move_to(self.cursor_x, self.cursor_y + n)
    0x43 => self.move_to(self.cursor_x + n, self.cursor_y)
    0x44 => self.move_to(self.cursor_x - n, self.cursor_y)
    0x45 => self.move_to(0, self.cursor_y + n)
    0x46 => self.move_to(0, self.cursor_y - n)
    0x47 => self.move_to(n - 1, self.cursor_y)
    0x64 => self.move_to(self.cursor_x, n - 1)
    0x4A => {
      let here = self.cursor_y * self.width + self.cursor_x
      match param(params, 0, 0) {
        0 => self.erase(here, self.cells.length())
        1 => self.erase(0, here + 1)
        _ => {
          self.erase(0, self.cells.length())
          self.cursor_x = 0
          self.cursor_y = 0
        }
      }
    }
    0x4B => {
      let row = self.cursor_y * self.width
      let here = row + self.cursor_x
      match param(params, 0, 0) {
        0 => self.erase(here, row + self.width)
        1 => self.erase(row, here + 1)
        _ => self.erase(row, row + self.width)
      }
    }
    0x6D => self.sgr(params)
    _ => ()
  }
}

///|
fn Grid::move_to(self : Grid, x : Int32, y : Int32) -> Unit {
  self.cursor_x = @cmp.maximum(0, @cmp.minimum(x, self.width - 1))
  self.cursor_y = @cmp.maximum(0, @cmp.minimum(y, self.height - 1))
}

///|
/// Blank the cells from `from` up to `until` in the style in force, as a real
/// terminal erases with the current background.
fn Grid::erase(self : Grid, from : Int32, until : Int32) -> Unit {
  let until = @cmp.minimum(until, self.cells.length())
  for at in @cmp.maximum(0, from)..<until {
    self.cells[at] = blank(self.current)
    self.dirty[at] = true
  }
}

///|
fn Grid::sgr(self : Grid, params : Array[Int32]) -> Unit {
  if params.length() == 0 {
    self.current = @style.default
    return
  }
  let mut i = 0
  while i < params.length() {
    let p = params[i]
    let a = self.current.attrs
    match p {
      0 => self.current = @style.default
      1 => self.attrs({ ..a, bold: true, })
      2 => self.attrs({ ..a, dim: true, })
      3 => self.attrs({ ..a, italic: true, })
      4 | 21 => self.attrs({ ..a, underline: true, })
      5 | 6 => self.attrs({ ..a, blink: true, })
      7 => self.attrs({ ..a, reverse: true, })
      9 => self.attrs({ ..a, strike: true, })
      22 => self.attrs({ ..a, bold: false, dim: false, })
      23 => self.attrs({ ..a, italic: false, })
      24 => self.attrs({ ..a, underline: false, })
      25 => self.attrs({ ..a, blink: false, })
      27 => self.attrs({ ..a, reverse: false, })
      29 => self.attrs({ ..a, strike: false, })
      39 => self.current = { ..self.current, fg: Default, }
      49 => self.current = { ..self.current, bg: Default, }
      30..<=37 => self.current = { ..self.current, fg: Ansi(p - 30), }
      40..<=47 => self.current = { ..self.current, bg: Ansi(p - 40), }
      90..<=97 => self.current = { ..self.current, fg: Ansi(p - 90 + 8), }
      100..<=107 => self.current = { ..self.current, bg: Ansi(p - 100 + 8), }
      38 | 48 => {
        let colour = if param(params, i + 1, 5) == 5 {
          i += 2
          @style.Colour::Ansi256(param(params, i, 0))
        } else {
          let rgb = @style.Colour::Rgb(
            param(params, i + 2, 0),
            param(params, i + 3, 0),
            param(params, i + 4, 0),
          )
          i += 4
          rgb
        }
        self.current = if p == 38 {
          { ..self.current, fg: colour, }
        } else {
          { ..self.current, bg: colour, }
        }
      }
      _ => ()
    }
    i += 1
  }
}

///|
fn Grid::attrs(self : Grid, attrs : @style.Attrs) -> Unit {
  self.current = { ..self.current, attrs, }
}

///|
/// Parameter `index`, where a missing or zero one means `fallback`: ECMA-48
/// reads a zero count or position as its default.
fn param(params : Array[Int32], index : Int32, fallback : Int32) -> Int32 {
  if index < params.length() && params[index] > 0 {
    params[index]
  } else {
    fallback
  }
}

///|
pub extend Cell with Debug::{to_repr}

///|
pub extend Cell with Eq::{not_equal, equal}
