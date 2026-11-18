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
fn Board::drawn(self : Board, x : Int32, y : Int32) -> @strip.Strip {
  let value = self.cells[y * SIDE + x]
  let here = x == self.cx && y == self.cy
  let text = if value == 0 { "   " } else { " " + value.to_string() + " " }
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
/// The rows the grid takes: a border at top and bottom, a thick rule between
/// boxes, and the nine rows of cells.
pub const GRID : Int32 = SIDE + 4

///|
/// Each cell is three columns wide with a bar before it, and one bar closes the
/// row: thick bars between boxes, thin ones inside them.
pub const SPAN : Int32 = SIDE * 4 + 1

///|
/// A horizontal rule: `left`, then a run of three under each cell, with `thin`
/// where a cell meets a cell and `thick` where a box meets a box, then `right`.
fn rule(left : String, thin : String, thick : String, right : String) -> String {
  let out = StringBuilder()
  out.write_string(left)
  for x in 0..<SIDE {
    if x > 0 {
      out.write_string(if x % 3 == 0 { thick } else { thin })
    }
    out.write_string("━━━")
  }
  out.write_string(right)
  out.to_string()
}

///|
/// One row of cells: each digit centred in its three columns.
fn Board::row_text(self : Board, y : Int32) -> @strip.Strip {
  let parts : Array[@strip.Strip] = []
  for x in 0..<SIDE {
    parts.push(
      @strip.Strip::of(if x % 3 == 0 { "┃" } else { "│" }, grid_style),
    )
    parts.push(self.drawn(x, y))
  }
  parts.push(@strip.Strip::of("┃", grid_style))
  @strip.Strip::join(parts)
}

///|
/// What row `at` of the grid holds, counted from its top border.
fn Board::grid_line(self : Board, at : Int32) -> @strip.Strip {
  match at {
    0 => @strip.Strip::of(rule("┏", "┯", "┳", "┓"), grid_style)
    4 | 8 => @strip.Strip::of(rule("┣", "┿", "╋", "┫"), grid_style)
    12 => @strip.Strip::of(rule("┗", "┷", "┻", "┛"), grid_style)
    _ => self.row_text(at - 1 - at / 4)
  }
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  let top = if size.height > GRID { (size.height - GRID) / 2 } else { 0 }
  let at = row - top
  if at < 0 || at >= GRID {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let left = if width > SPAN { (width - SPAN) / 2 } else { 0 }
  @strip.Strip::join([
    @strip.Strip::blank(left, @style.Style::new()),
    self.grid_line(at),
  ]).pad_to(width, @style.Style::new())
}

///|
impl @widget.Widget for Board with fn hint(_self, _size) {
  @geom.Size::new(SPAN, GRID)
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
/// How many cells are still empty.
pub fn Board::left(self : Board) -> Int32 {
  self.cells.iter().filter(v => v == 0).count()
}

///|
pub fn Screen::new() -> Screen {
  let board = Board::new()
  let band = @theme.line(width => {
    let note = if board.stage() == 1 {
      "solved"
    } else {
      "\{board.left()} to fill"
    }
    @theme.band("moonetui", subject="sudoku", note~, width~)
  })
  let keys = @theme.line(width => {
    @theme.keys(
      [
        ("arrows", "move"),
        ("1–9", "write"),
        ("0", "clear"),
        ("r", "reset"),
        ("q", "quit"),
      ],
      width~,
    )
  })
  let root = @app.column(0, [
    @app.leaf(1, band, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, board, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, keys, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, board, }
}
