// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// Twelve columns and eighteen rows of falling blocks. A piece is four cells in
// a four by four box; turning it turns the box.

///|
#derive(Eq)
pub(all) enum Stage {
  Title
  Playing
  Over
}

///|
pub extend Stage with Eq::{not_equal, equal}

///|
pub const WIDE : Int32 = 10

///|
pub const TALL : Int32 = 18

///|
/// The seven pieces, each drawn in a four by four box.
fn shape(kind : Int32) -> Array[(Int32, Int32)] {
  match kind {
    0 => [(0, 1), (1, 1), (2, 1), (3, 1)]
    1 => [(0, 0), (1, 0), (0, 1), (1, 1)]
    2 => [(1, 0), (0, 1), (1, 1), (2, 1)]
    3 => [(1, 0), (2, 0), (0, 1), (1, 1)]
    4 => [(0, 0), (1, 0), (1, 1), (2, 1)]
    5 => [(0, 0), (0, 1), (1, 1), (2, 1)]
    _ => [(2, 0), (0, 1), (1, 1), (2, 1)]
  }
}

///|
/// A quarter turn of the box: the far column becomes the top row.
fn turned(cells : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  let out : Array[(Int32, Int32)] = []
  for cell in cells {
    let (x, y) = cell
    out.push((3 - y, x))
  }
  out
}

///|
pub struct Grid {
  mut stage : Stage
  mut cells : Array[Int32]
  mut kind : Int32
  mut rot : Int32
  mut px : Int32
  mut py : Int32
  mut score : Int32
  mut lines : Int32
  mut level : Int32
  mut beat : Int32
  mut seed : Int32
  mut next : Int32
}

///|
pub fn Grid::new() -> Grid {
  let cells : Array[Int32] = []
  for _ in 0..<(WIDE * TALL) {
    cells.push(0)
  }
  {
    stage: Title,
    cells,
    kind: 0,
    rot: 0,
    px: 3,
    py: 0,
    score: 0,
    lines: 0,
    level: 1,
    beat: 0,
    seed: 3,
    next: 1,
  }
}

///|
pub fn Grid::stage(self : Grid) -> Stage {
  self.stage
}

///|
pub fn Grid::score(self : Grid) -> Int32 {
  self.score
}

///|
pub fn Grid::lines(self : Grid) -> Int32 {
  self.lines
}

///|
pub fn Grid::level(self : Grid) -> Int32 {
  self.level
}

///|
pub fn Grid::cell(self : Grid, x : Int32, y : Int32) -> Int32 {
  self.cells[y * WIDE + x]
}

///|
/// Where the falling piece sits, as cells on the board.
pub fn Grid::piece(self : Grid) -> Array[(Int32, Int32)] {
  let out : Array[(Int32, Int32)] = []
  let mut cells = shape(self.kind)
  for _ in 0..<self.rot {
    cells = turned(cells)
  }
  for cell in cells {
    let (x, y) = cell
    out.push((self.px + x, self.py + y))
  }
  out
}

///|
fn Grid::fits(self : Grid, cells : Array[(Int32, Int32)]) -> Bool {
  for cell in cells {
    let (x, y) = cell
    if x < 0 || x >= WIDE || y >= TALL {
      return false
    }
    if y >= 0 && self.cells[y * WIDE + x] != 0 {
      return false
    }
  }
  true
}

///|
pub fn Grid::start(self : Grid) -> Unit {
  let cells : Array[Int32] = []
  for _ in 0..<(WIDE * TALL) {
    cells.push(0)
  }
  self.cells = cells
  self.score = 0
  self.lines = 0
  self.level = 1
  self.beat = 0
  self.stage = Playing
  self.spawn()
}

///|
fn Grid::spawn(self : Grid) -> Unit {
  self.kind = self.next
  self.seed = (self.seed + 3) % 7
  self.next = self.seed
  self.rot = 0
  self.px = 3
  self.py = 0
  if !self.fits(self.piece()) {
    self.stage = Over
  }
}

///|
pub fn Grid::shift(self : Grid, step : Int32) -> Unit {
  if self.stage != Playing {
    return
  }
  self.px = self.px + step
  if !self.fits(self.piece()) {
    self.px = self.px - step
  }
}

///|
pub fn Grid::turn(self : Grid) -> Unit {
  if self.stage != Playing {
    return
  }
  self.rot = (self.rot + 1) % 4
  if !self.fits(self.piece()) {
    self.rot = (self.rot + 3) % 4
  }
}

///|
/// The clock: the piece drops one row every `level` beats, and settles onto the
/// board when it cannot go further.
pub fn Grid::fall(self : Grid) -> Unit {
  if self.stage != Playing {
    return
  }
  self.beat = self.beat + 1
  if self.beat < 6 - self.level {
    return
  }
  self.beat = 0
  self.drop()
}

///|
pub fn Grid::drop(self : Grid) -> Unit {
  self.py = self.py + 1
  if !self.fits(self.piece()) {
    self.py = self.py - 1
    self.settle()
  }
}

///|
fn Grid::settle(self : Grid) -> Unit {
  for cell in self.piece() {
    let (x, y) = cell
    if y >= 0 && y < TALL {
      self.cells[y * WIDE + x] = self.kind + 1
    }
  }
  self.clear()
  self.spawn()
}

///|
/// Full rows go, the rows above come down, and the score follows the count.
fn Grid::clear(self : Grid) -> Unit {
  let kept : Array[Int32] = []
  let mut gone = 0
  for y in 0..<TALL {
    let mut full = true
    for x in 0..<WIDE {
      if self.cells[y * WIDE + x] == 0 {
        full = false
      }
    }
    if full {
      gone = gone + 1
    } else {
      for x in 0..<WIDE {
        kept.push(self.cells[y * WIDE + x])
      }
    }
  }
  if gone == 0 {
    return
  }
  let fresh : Array[Int32] = []
  for _ in 0..<(gone * WIDE) {
    fresh.push(0)
  }
  for cell in kept {
    fresh.push(cell)
  }
  self.cells = fresh
  self.lines = self.lines + gone
  self.score = self.score + gone * 100 * self.level
  self.level = 1 + self.lines / 5
}

///|
let ghost_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x2a, 0x2e, 0x44),
)

///|
let palette : Array[@style.Style] = [
  @style.Style::new(fg=@theme.accent),
  @style.Style::new(fg=@theme.accent_alt),
  @style.Style::new(fg=@theme.good),
  @style.Style::new(fg=@theme.warn),
  @style.Style::new(fg=@theme.bad),
  @style.Style::new(fg=@theme.ink),
  @style.Style::new(fg=@theme.accent, bold=true),
]

///|
let hud_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn Grid::colour(self : Grid, value : Int32) -> @style.Style {
  ignore(self)
  if value <= 0 {
    return @style.Style::new()
  }
  palette[(value - 1) % 7]
}

///|
impl @widget.Widget for Grid with fn render_line(self, row, size) {
  let width = size.width
  if row == 0 {
    let word = match self.stage {
      Title => "space to play"
      Playing =>
        "score " +
        self.score.to_string() +
        " · lines " +
        self.lines.to_string() +
        " · level " +
        self.level.to_string()
      Over => "game over · r to play again"
    }
    return @strip.Strip::of(" " + word, hud_style)
  }
  let y = row - 1
  if y < 0 || y >= TALL {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let box = WIDE * 2
  let offset = if width > box { (width - box) / 2 } else { 0 }
  let parts : Array[@strip.Strip] = []
  if offset > 0 {
    parts.push(@strip.Strip::blank(offset, @style.Style::new()))
  }
  let piece = if self.stage == Title { [] } else { self.piece() }
  for x in 0..<WIDE {
    let value = self.cells[y * WIDE + x]
    let mut in_piece = false
    let mut piece_kind = 0
    for cell in piece {
      let (px, py) = cell
      if px == x && py == y {
        in_piece = true
        piece_kind = self.kind + 1
      }
    }
    if in_piece {
      parts.push(@strip.Strip::of("██", self.colour(piece_kind)))
    } else if value > 0 {
      parts.push(@strip.Strip::of("██", self.colour(value)))
    } else {
      parts.push(@strip.Strip::of("  ", ghost_style))
    }
  }
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Grid with fn hint(_self, _size) {
  @geom.Size::new(WIDE * 2, TALL + 1)
}

///|
impl @widget.Widget for Grid with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Grid with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Char(32) => {
          match self.stage {
            Title => self.start()
            Over => self.start()
            Playing => self.drop()
          }
          ctx.repaint()
          true
        }
        Char(114) => {
          self.start()
          ctx.repaint()
          true
        }
        Left => {
          self.shift(-1)
          ctx.repaint()
          true
        }
        Right => {
          self.shift(1)
          ctx.repaint()
          true
        }
        Up => {
          self.turn()
          ctx.repaint()
          true
        }
        Down => {
          self.drop()
          ctx.repaint()
          true
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
  grid : Grid
}

///|
pub fn Screen::new() -> Screen {
  let grid = Grid::new()
  let root = @app.column(0, [
    @app.leaf(1, grid, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, grid, }
}
