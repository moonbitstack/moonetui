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
fn Grid::colour(self : Grid, value : Int32) -> @style.Style {
  ignore(self)
  if value <= 0 {
    return @style.Style::new()
  }
  palette[(value - 1) % 7]
}

///|
/// The rows the board takes: the well's frame above and below its rows.
pub const ROWS : Int32 = TALL + 2

///|
/// The columns: the well two columns to a cell inside its frame, a gutter, and
/// the panel beside it.
pub const COLS : Int32 = WIDE * 2 + 2 + 3 + PANEL

///|
const PANEL : Int32 = 12

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.faint)

///|
let label_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let value_style : @style.Style = @style.Style::new(fg=@theme.ink, bold=true)

///|
/// What the piece under the cursor, a settled block or the empty well shows at
/// a cell.
fn Grid::block(self : Grid, x : Int32, y : Int32) -> @strip.Strip {
  let piece = if self.stage == Title { [] } else { self.piece() }
  if piece.iter().any(cell => cell == (x, y)) {
    return @strip.Strip::of("██", self.colour(self.kind + 1))
  }
  let value = self.cells[y * WIDE + x]
  if value > 0 {
    @strip.Strip::of("██", self.colour(value))
  } else {
    @strip.Strip::of(" ·", ghost_style)
  }
}

///|
/// The well's row `y`, or a line of the title or the end of the game written
/// across it.
fn Grid::well(self : Grid, y : Int32) -> @strip.Strip {
  let middle = TALL / 2
  let words = match self.stage {
    Title =>
      if y == middle - 1 {
        Some(("B L O C K S", @style.Style::new(fg=@theme.accent, bold=true)))
      } else if y == middle + 1 {
        Some(("space to play", label_style))
      } else {
        None
      }
    Over =>
      if y == middle - 1 {
        Some(("game over", @style.Style::new(fg=@theme.bad, bold=true)))
      } else if y == middle + 1 {
        Some(("r to play again", label_style))
      } else {
        None
      }
    Playing => None
  }
  match words {
    Some((text, style)) => {
      let room = WIDE * 2
      let used = @strip.str_cells(text)
      let left = if room > used { (room - used) / 2 } else { 0 }
      @strip.Strip::join([
        @strip.Strip::blank(left, @style.Style::new()),
        @strip.Strip::of(text, style),
      ]).pad_to(room, @style.Style::new())
    }
    None => {
      let parts : Array[@strip.Strip] = []
      for x in 0..<WIDE {
        parts.push(self.block(x, y))
      }
      @strip.Strip::join(parts)
    }
  }
}

///|
/// The panel beside the well: the next piece, then the score, the lines and the
/// level, each a muted label over its value.
fn Grid::panel(self : Grid, at : Int32) -> @strip.Strip {
  let label = (text : String) => @strip.Strip::of(text, label_style)
  let value = (n : Int32) => @strip.Strip::of(n.to_string(), value_style)
  let next = shape(self.next)
  let preview = (y : Int32) => {
    let parts : Array[@strip.Strip] = []
    for x in 0..<4 {
      parts.push(
        if next.iter().any(cell => cell == (x, y)) {
          @strip.Strip::of("██", palette[self.next % 7])
        } else {
          @strip.Strip::blank(2, @style.Style::new())
        },
      )
    }
    @strip.Strip::join(parts)
  }
  let line = match at {
    1 => label("next")
    3 =>
      if self.stage == Title {
        @strip.Strip::blank(0, @style.Style::new())
      } else {
        preview(0)
      }
    4 =>
      if self.stage == Title {
        @strip.Strip::blank(0, @style.Style::new())
      } else {
        preview(1)
      }
    7 => label("score")
    8 => value(self.score)
    10 => label("lines")
    11 => value(self.lines)
    13 => label("level")
    14 => value(self.level)
    _ => @strip.Strip::blank(0, @style.Style::new())
  }
  line.pad_to(PANEL, @style.Style::new())
}

///|
impl @widget.Widget for Grid with fn render_line(self, row, size) {
  let width = size.width
  let top = if size.height > ROWS { (size.height - ROWS) / 2 } else { 0 }
  let at = row - top
  if at < 0 || at >= ROWS {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let inner = WIDE * 2
  let well = if at == 0 {
    @strip.Strip::of("╭" + @theme.repeat("─", inner) + "╮", frame_style)
  } else if at == ROWS - 1 {
    @strip.Strip::of("╰" + @theme.repeat("─", inner) + "╯", frame_style)
  } else {
    @strip.Strip::join([
      @strip.Strip::of("│", frame_style),
      self.well(at - 1),
      @strip.Strip::of("│", frame_style),
    ])
  }
  let left = if width > COLS { (width - COLS) / 2 } else { 0 }
  @strip.Strip::join([
    @strip.Strip::blank(left, @style.Style::new()),
    well,
    @strip.Strip::blank(3, @style.Style::new()),
    self.panel(at),
  ]).pad_to(width, @style.Style::new())
}

///|
impl @widget.Widget for Grid with fn hint(_self, _size) {
  @geom.Size::new(COLS, ROWS)
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
  let band = @theme.line(width => {
    let note = match grid.stage() {
      Title => "space to play"
      Playing => "level \{grid.level()}"
      Over => "game over"
    }
    @theme.band("moonetui", subject="blocks", note~, width~)
  })
  let keys = @theme.line(width => {
    @theme.keys(
      [
        ("←→", "move"),
        ("↑", "turn"),
        ("↓ space", "drop"),
        ("r", "again"),
        ("q", "quit"),
      ],
      width~,
    )
  })
  let root = @app.column(0, [
    @app.leaf(1, band, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, grid, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, keys, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, grid, }
}
