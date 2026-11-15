// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A field of cells that follows one rule: a live cell with two or three live
/// neighbours lives, a dead one with exactly three is born. The edges wrap, so
/// a glider that leaves the right edge comes back on the left.
pub struct Field {
  cols : Int32
  rows : Int32
  mut cells : Array[Bool]
  mut gen : Int32
  mut running : Bool
}

///|
/// Three figures a reader can recognise: a glider that walks, a blinker that
/// pulses, and a block that sits still.
pub fn Field::new(cols~ : Int32 = 46, rows~ : Int32 = 14) -> Field {
  let field : Field = { cols, rows, cells: [], gen: 0, running: true, }
  field.seed()
  field
}

///|
fn put(field : Field, x : Int32, y : Int32) -> Unit {
  field.cells[y * field.cols + x] = true
}

///|
/// Start again, from the same three figures: a demonstration that can be
/// replayed, and a frame test that can say what it sees.
pub fn Field::seed(self : Field) -> Unit {
  let cells : Array[Bool] = []
  for _ in 0..<(self.cols * self.rows) {
    cells.push(false)
  }
  self.cells = cells
  self.gen = 0
  self.running = true
  // A glider, walking down and right.
  put(self, 2, 2)
  put(self, 3, 3)
  put(self, 1, 4)
  put(self, 2, 4)
  put(self, 3, 4)
  // A blinker, pulsing in place.
  put(self, 14, 6)
  put(self, 15, 6)
  put(self, 16, 6)
  // A block, which never changes.
  put(self, 30, 9)
  put(self, 31, 9)
  put(self, 30, 10)
  put(self, 31, 10)
}

///|
pub fn Field::gen(self : Field) -> Int32 {
  self.gen
}

///|
pub fn Field::alive(self : Field) -> Int32 {
  let mut count = 0
  for cell in self.cells {
    if cell {
      count = count + 1
    }
  }
  count
}

///|
pub fn Field::alive_at(self : Field, x : Int32, y : Int32) -> Bool {
  self.cells[y * self.cols + x]
}

///|
pub fn Field::running(self : Field) -> Bool {
  self.running
}

///|
pub fn Field::toggle(self : Field) -> Unit {
  self.running = !self.running
}

///|
fn Field::neighbours(self : Field, x : Int32, y : Int32) -> Int32 {
  let mut count = 0
  for dy in -1..<=1 {
    for dx in -1..<=1 {
      if dx == 0 && dy == 0 {
        continue
      }
      let nx = (x + dx + self.cols) % self.cols
      let ny = (y + dy + self.rows) % self.rows
      if self.cells[ny * self.cols + nx] {
        count = count + 1
      }
    }
  }
  count
}

///|
/// One generation. A paused field keeps its cells and its generation count.
pub fn Field::step(self : Field) -> Unit {
  if !self.running {
    return
  }
  let next : Array[Bool] = []
  for y in 0..<self.rows {
    for x in 0..<self.cols {
      let around = self.neighbours(x, y)
      let live = self.cells[y * self.cols + x]
      next.push(around == 3 || (live && around == 2))
    }
  }
  self.cells = next
  self.gen = self.gen + 1
}

///|
let alive_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let dead_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let note_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
impl @widget.Widget for Field with fn render_line(self, row, size) {
  if row == self.rows {
    let word = if self.running { "running" } else { "paused" }
    return @strip.Strip::of(
      "gen " +
      self.gen.to_string() +
      " · alive " +
      self.alive().to_string() +
      " · " +
      word,
      note_style,
    )
  }
  if row < 0 || row >= self.rows {
    return @strip.Strip::blank(size.width, @style.default)
  }
  let parts : Array[@strip.Strip] = []
  for x in 0..<self.cols {
    if self.cells[row * self.cols + x] {
      parts.push(@strip.Strip::of("█", alive_style))
    } else {
      // A faint dot on the dead cells, so an empty field still reads as a grid
      // rather than as a hole in the screen.
      parts.push(@strip.Strip::of("·", dead_style))
    }
  }
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Field with fn hint(self, _size) {
  @geom.Size::new(self.cols, self.rows + 1)
}

///|
impl @widget.Widget for Field with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Field with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Char(32) => {
          self.toggle()
          ctx.repaint()
          true
        }
        Char(114) => {
          self.seed()
          ctx.repaint()
          true
        }
        Char(46) => {
          let was = self.running
          self.running = true
          self.step()
          self.running = was
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}
