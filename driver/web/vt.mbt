// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One cell of the browser's grid.
pub(all) struct Cell {
  text : String
  style : @style.Style
} derive(Eq, Debug)

///|
/// The grid a browser terminal keeps, and the small part of the escape language
/// it understands.
///
/// It is small on purpose: this reads what moonetui writes — move the cursor,
/// set a style, put text — and ignores the rest. A general terminal emulator
/// would be a different project.
pub struct Grid {
  mut width : Int
  mut height : Int
  mut cells : Array[Cell]
  mut dirty : Array[Bool]
  mut cursor_x : Int
  mut cursor_y : Int
  mut current : @style.Style
  /// An escape sequence that arrived in pieces waits here for the rest.
  mut pending : String
}

///|
/// An empty grid of this size.
pub fn Grid::new(width : Int, height : Int) -> Grid {
  let grid = {
    width,
    height,
    cells: [],
    dirty: [],
    cursor_x: 0,
    cursor_y: 0,
    current: @style.default,
    pending: "",
  }
  grid.resize(width, height)
  grid
}

///|
/// Change the grid's size, clearing it.
pub fn Grid::resize(self : Grid, width : Int, height : Int) -> Unit {
  self.width = if width < 1 { 1 } else { width }
  self.height = if height < 1 { 1 } else { height }
  let count = self.width * self.height
  let cells : Array[Cell] = []
  let dirty : Array[Bool] = []
  for _ in 0..<count {
    cells.push({ text: " ", style: @style.default, })
    dirty.push(true)
  }
  self.cells = cells
  self.dirty = dirty
  self.cursor_x = 0
  self.cursor_y = 0
}

///|
/// The cell at these coordinates.
pub fn Grid::at(self : Grid, x : Int, y : Int) -> Cell {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    return { text: " ", style: @style.default, }
  }
  self.cells[y * self.width + x]
}

///|
/// The grid as one string per row, which is what a test reads.
pub fn Grid::rows(self : Grid) -> Array[String] {
  let out : Array[String] = []
  for y in 0..<self.height {
    let line = StringBuilder()
    for x in 0..<self.width {
      line.write_string(self.at(x, y).text)
    }
    out.push(line.to_string())
  }
  out
}

///|
/// The cells that changed since they were last collected, as coordinates.
pub fn Grid::take_dirty(self : Grid) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for i in 0..<self.dirty.length() {
    if self.dirty[i] {
      out.push((i % self.width, i / self.width))
      self.dirty[i] = false
    }
  }
  out
}

///|
/// Mark every cell as needing to be drawn again, after a resize or a font
/// change, where the browser lost what was on the canvas.
pub fn Grid::dirty_all(self : Grid) -> Unit {
  for i in 0..<self.dirty.length() {
    self.dirty[i] = true
  }
}

///|
/// Feed output from the application.
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
        // The sequence is incomplete. Keeping it is the whole point: output
        // arrives in whatever pieces the caller wrote it in, and a colour that
        // was split across two writes still has to reach the cell.
        self.pending = text[i:].to_owned()
        return
      }
      i = i + used
      continue
    }
    let (code, used) = @strip.code_at(text, i)
    if code == 0x0A {
      self.cursor_y = self.cursor_y + 1
      self.cursor_x = 0
    } else if code == 0x0D {
      self.cursor_x = 0
    } else if code >= 0x20 {
      self.put(code, text[i:i + used].to_owned())
    }
    i = i + used
  }
}

///|
/// Put one character at the cursor and move on. A wide character takes the
/// column after it too, which is left empty so that nothing else claims it.
fn Grid::put(self : Grid, code : Int, body : String) -> Unit {
  let width = @strip.cell_width(code)
  if width == 0 {
    // A combining mark joins the cell before the cursor.
    let x = self.cursor_x - 1
    if x >= 0 && x < self.width && self.cursor_y < self.height {
      let at = self.cursor_y * self.width + x
      let old = self.cells[at]
      self.cells[at] = { ..old, text: old.text + body, }
      self.dirty[at] = true
    }
    return
  }
  if self.cursor_x >= self.width {
    self.cursor_x = 0
    self.cursor_y = self.cursor_y + 1
  }
  if self.cursor_y >= self.height || self.cursor_y < 0 {
    return
  }
  let at = self.cursor_y * self.width + self.cursor_x
  self.cells[at] = { text: body, style: self.current, }
  self.dirty[at] = true
  if width == 2 && self.cursor_x + 1 < self.width {
    self.cells[at + 1] = { text: "", style: self.current, }
    self.dirty[at + 1] = true
  }
  self.cursor_x = self.cursor_x + width
}

///|
/// Read one escape sequence, returning how many code units it took, or zero
/// when the sequence is not complete yet.
fn Grid::escape(self : Grid, text : String, at : Int) -> Int {
  if at + 1 >= text.length() {
    return 0
  }
  if text[at + 1].to_int() != 0x5B {
    // Only CSI sequences come out of this library; anything else is skipped.
    return 2
  }
  let params : Array[Int] = []
  let mut value = -1
  let mut private_marker = false
  let mut i = at + 2
  while i < text.length() {
    let c = text[i].to_int()
    if c == 0x3F {
      private_marker = true
      i = i + 1
    } else if c >= 0x30 && c <= 0x39 {
      value = (if value < 0 { 0 } else { value }) * 10 + (c - 0x30)
      i = i + 1
    } else if c == 0x3B {
      params.push(if value < 0 { 0 } else { value })
      value = -1
      i = i + 1
    } else if c >= 0x40 && c <= 0x7E {
      if value >= 0 {
        params.push(value)
      }
      if !private_marker {
        self.apply(params, c)
      }
      return i + 1 - at
    } else {
      return 2
    }
  }
  0
}

///|
fn Grid::apply(self : Grid, params : Array[Int], last : Int) -> Unit {
  match last {
    // Cursor position, counted from one.
    0x48 => {
      self.cursor_y = param(params, 0, 1) - 1
      self.cursor_x = param(params, 1, 1) - 1
    }
    // Erase in display.
    0x4A => {
      for i in 0..<self.cells.length() {
        self.cells[i] = { text: " ", style: self.current, }
        self.dirty[i] = true
      }
      self.cursor_x = 0
      self.cursor_y = 0
    }
    0x6D => self.sgr(params)
    _ => ()
  }
}

///|
/// Apply a style change. The parameters are the ones this library emits, which
/// is a small and fixed set.
fn Grid::sgr(self : Grid, params : Array[Int]) -> Unit {
  if params.length() == 0 {
    self.current = @style.default
    return
  }
  let mut i = 0
  while i < params.length() {
    let p = params[i]
    if p == 0 {
      self.current = @style.default
    } else if p == 1 {
      self.current = with_attrs(self.current, bold=true)
    } else if p == 2 {
      self.current = with_attrs(self.current, dim=true)
    } else if p == 3 {
      self.current = with_attrs(self.current, italic=true)
    } else if p == 4 {
      self.current = with_attrs(self.current, underline=true)
    } else if p == 7 {
      self.current = with_attrs(self.current, reverse=true)
    } else if p == 9 {
      self.current = with_attrs(self.current, strike=true)
    } else if p == 39 {
      self.current = { ..self.current, fg: Default, }
    } else if p == 49 {
      self.current = { ..self.current, bg: Default, }
    } else if p >= 30 && p <= 37 {
      self.current = { ..self.current, fg: Ansi(p - 30), }
    } else if p >= 40 && p <= 47 {
      self.current = { ..self.current, bg: Ansi(p - 40), }
    } else if p >= 90 && p <= 97 {
      self.current = { ..self.current, fg: Ansi(p - 90 + 8), }
    } else if p >= 100 && p <= 107 {
      self.current = { ..self.current, bg: Ansi(p - 100 + 8), }
    } else if p == 38 || p == 48 {
      let kind = param(params, i + 1, 5)
      let color = if kind == 5 {
        i = i + 2
        @style.Color::Ansi256(param(params, i, 0))
      } else {
        let r = param(params, i + 2, 0)
        let g = param(params, i + 3, 0)
        let b = param(params, i + 4, 0)
        i = i + 4
        @style.Color::Rgb(r, g, b)
      }
      self.current = if p == 38 {
        { ..self.current, fg: color, }
      } else {
        { ..self.current, bg: color, }
      }
    }
    i = i + 1
  }
}

///|
/// Add attributes to a style, keeping the ones it already has.
fn with_attrs(
  base : @style.Style,
  bold? : Bool = false,
  dim? : Bool = false,
  italic? : Bool = false,
  underline? : Bool = false,
  reverse? : Bool = false,
  strike? : Bool = false,
) -> @style.Style {
  {
    ..base,
    attrs: base.attrs.union({
      bold,
      dim,
      italic,
      underline,
      blink: false,
      reverse,
      strike,
    }),
  }
}

///|
fn param(params : Array[Int], index : Int, fallback : Int) -> Int {
  if index < params.length() && params[index] > 0 {
    params[index]
  } else if index < params.length() {
    params[index]
  } else {
    fallback
  }
}

///|
pub extend Cell with Debug::{to_repr}

///|
pub extend Cell with Eq::{not_equal, equal}
