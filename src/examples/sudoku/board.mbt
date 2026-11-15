// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// Nine by nine: the given numbers cannot be changed, the empty cells take a
// digit, and a digit that fights its row, its column or its box is marked.

///|
pub const SIDE : Int32 = 9

///|
/// The puzzle: zero is a cell the reader fills.
let puzzle : Array[Int32] = [
  5, 3, 0, 0, 7, 0, 0, 0, 0, 6, 0, 0, 1, 9, 5, 0, 0, 0, 0, 9, 8, 0, 0, 0, 0, 6, 0,
  8, 0, 0, 0, 6, 0, 0, 0, 3, 4, 0, 0, 8, 0, 3, 0, 0, 1, 7, 0, 0, 0, 2, 0, 0, 0, 6,
  0, 6, 0, 0, 0, 0, 2, 8, 0, 0, 0, 0, 4, 1, 9, 0, 0, 5, 0, 0, 0, 0, 8, 0, 0, 7, 9,
]

///|
pub struct Board {
  mut cells : Array[Int32]
  fixed : Array[Bool]
  mut cx : Int32
  mut cy : Int32
  mut stage : Int32
}

///|
pub fn Board::new() -> Board {
  let cells : Array[Int32] = []
  let fixed : Array[Bool] = []
  for value in puzzle {
    cells.push(value)
    fixed.push(value != 0)
  }
  { cells, fixed, cx: 2, cy: 0, stage: 0, }
}

///|
pub fn Board::cell(self : Board, x : Int32, y : Int32) -> Int32 {
  self.cells[y * SIDE + x]
}

///|
pub fn Board::cursor(self : Board) -> (Int32, Int32) {
  (self.cx, self.cy)
}

///|
pub fn Board::stage(self : Board) -> Int32 {
  self.stage
}

///|
/// Whether the digit in a cell fights another in its row, column or box.
pub fn Board::clash(self : Board, x : Int32, y : Int32) -> Bool {
  let value = self.cells[y * SIDE + x]
  if value == 0 {
    return false
  }
  for i in 0..<SIDE {
    if i != x && self.cells[y * SIDE + i] == value {
      return true
    }
    if i != y && self.cells[i * SIDE + x] == value {
      return true
    }
  }
  let bx = x / 3 * 3
  let by = y / 3 * 3
  for dy in 0..<3 {
    for dx in 0..<3 {
      let nx = bx + dx
      let ny = by + dy
      if (nx != x || ny != y) && self.cells[ny * SIDE + nx] == value {
        return true
      }
    }
  }
  false
}

///|
pub fn Board::steer(self : Board, dx : Int32, dy : Int32) -> Unit {
  let nx = self.cx + dx
  let ny = self.cy + dy
  if nx >= 0 && nx < SIDE {
    self.cx = nx
  }
  if ny >= 0 && ny < SIDE {
    self.cy = ny
  }
}

///|
/// Write a digit, or clear the cell with zero. A given cell does not move.
pub fn Board::write(self : Board, value : Int32) -> Unit {
  let index = self.cy * SIDE + self.cx
  if self.fixed[index] {
    return
  }
  self.cells[index] = value
  self.check()
}

///|
fn Board::check(self : Board) -> Unit {
  let mut full = true
  for y in 0..<SIDE {
    for x in 0..<SIDE {
      if self.cells[y * SIDE + x] == 0 || self.clash(x, y) {
        full = false
      }
    }
  }
  self.stage = if full { 1 } else { 0 }
}

///|
let given_style : @style.Style = @style.Style::new(fg=@theme.ink, bold=true)

///|
let typed_style : @style.Style = @style.Style::new(fg=@theme.accent)

///|
let bad_style : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.bad,
  bold=true,
)

///|
let picked_style : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.accent,
  bold=true,
)

///|
let grid_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let hud_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn Board::drawn(self : Board, x : Int32, y : Int32) -> @strip.Strip {
  let value = self.cells[y * SIDE + x]
  let here = x == self.cx && y == self.cy
  let text = if value == 0 { "  " } else { value.to_string() + " " }
  if self.clash(x, y) {
    return @strip.Strip::of(text, bad_style)
  }
  if here {
    return @strip.Strip::of(text, picked_style)
  }
  @strip.Strip::of(
    text,
    if self.fixed[y * SIDE + x] {
      given_style
    } else {
      typed_style
    },
  )
}

///|
/// The thin and thick rules of the nine by nine: a bar between boxes.
fn Board::row_text(self : Board, y : Int32) -> @strip.Strip {
  let parts : Array[@strip.Strip] = []
  for x in 0..<SIDE {
    if x % 3 == 0 {
      parts.push(@strip.Strip::of("┃", grid_style))
    } else {
      parts.push(@strip.Strip::of("│", grid_style))
    }
    parts.push(self.drawn(x, y))
  }
  parts.push(@strip.Strip::of("┃", grid_style))
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  if row == 0 {
    let word = if self.stage == 1 {
      "solved · r to start again"
    } else {
      "arrows move · 1–9 write · 0 clears · r resets"
    }
    return @strip.Strip::of(" " + word, hud_style)
  }
  let body = row - 1
  let box = SIDE * 3 + 1
  let offset = if width > box { (width - box) / 2 } else { 0 }
  let parts : Array[@strip.Strip] = []
  if offset > 0 {
    parts.push(@strip.Strip::blank(offset, @style.Style::new()))
  }
  // A thick rule between the boxes, three times over.
  if body == 3 || body == 6 {
    parts.push(
      @strip.Strip::of(
        "┣" + "━━━" + "╋" + "━━━" + "╋" + "━━━" + "┫",
        grid_style,
      ),
    )
    return @strip.Strip::join(parts)
  }
  let y = if body < 3 { body } else if body < 7 { body - 1 } else { body - 2 }
  if y < 0 || y >= SIDE {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  parts.push(self.row_text(y))
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Board with fn hint(_self, _size) {
  @geom.Size::new(SIDE * 3 + 1, SIDE + 3)
}

///|
impl @widget.Widget for Board with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Board with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Up => {
          self.steer(0, -1)
          ctx.repaint()
          true
        }
        Down => {
          self.steer(0, 1)
          ctx.repaint()
          true
        }
        Left => {
          self.steer(-1, 0)
          ctx.repaint()
          true
        }
        Right => {
          self.steer(1, 0)
          ctx.repaint()
          true
        }
        Char(c) =>
          if c == 114 {
            let fresh = Board::new()
            self.cells = fresh.cells
            self.stage = 0
            self.cx = 2
            self.cy = 0
            ctx.repaint()
            true
          } else if c == 48 || c == 8 {
            self.write(0)
            ctx.repaint()
            true
          } else if c >= 49 && c <= 57 {
            self.write(c - 48)
            ctx.repaint()
            true
          } else {
            false
          }
        _ => false
      }
    _ => false
  }
}

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
pub struct Screen {
  root : @app.Node
  board : Board
}

///|
pub fn Screen::new() -> Screen {
  let board = Board::new()
  let root = @app.column(0, [
    @app.leaf(1, board, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, board, }
}
