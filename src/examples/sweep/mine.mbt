// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A ten by ten field of mines: reveal the cells that are safe, flag the ones
// that are not, and open a whole region at once when a zero is found.

///|
pub const SIZE : Int32 = 10

///|
#derive(Eq)
pub(all) enum Stage {
  Playing
  Won
  Over
}

///|
pub extend Stage with Eq::{not_equal, equal}

///|
/// Fourteen mines, placed away from the middle: the first reveal is always
/// safe, which is what a player expects of the first click.
let mines_at : Array[(Int32, Int32)] = [
  (0, 0),
  (3, 1),
  (7, 2),
  (9, 3),
  (1, 5),
  (5, 5),
  (8, 6),
  (2, 8),
  (6, 9),
  (9, 9),
  (4, 3),
  (0, 7),
  (7, 8),
  (3, 6),
]

///|
pub struct Field {
  mut mine : Array[Bool]
  mut open : Array[Bool]
  mut flag : Array[Bool]
  mut around : Array[Int32]
  mut cx : Int32
  mut cy : Int32
  mut stage : Stage
  mut opened : Int32
}

///|
pub fn Field::new() -> Field {
  let mine : Array[Bool] = []
  let open : Array[Bool] = []
  let flag : Array[Bool] = []
  let around : Array[Int32] = []
  for _ in 0..<(SIZE * SIZE) {
    mine.push(false)
    open.push(false)
    flag.push(false)
    around.push(0)
  }
  for spot in mines_at {
    let (x, y) = spot
    mine[y * SIZE + x] = true
  }
  // The count under every cell, so a reveal is one lookup rather than a walk.
  for y in 0..<SIZE {
    for x in 0..<SIZE {
      let mut count = 0
      for dy in -1..<=1 {
        for dx in -1..<=1 {
          if dx == 0 && dy == 0 {
            continue
          }
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 &&
            nx < SIZE &&
            ny >= 0 &&
            ny < SIZE &&
            mine[ny * SIZE + nx] {
            count = count + 1
          }
        }
      }
      around[y * SIZE + x] = count
    }
  }
  { mine, open, flag, around, cx: 5, cy: 5, stage: Playing, opened: 0, }
}

///|
pub fn Field::stage(self : Field) -> Stage {
  self.stage
}

///|
pub fn Field::opened(self : Field) -> Int32 {
  self.opened
}

///|
pub fn Field::flagged(self : Field, x : Int32, y : Int32) -> Bool {
  self.flag[y * SIZE + x]
}

///|
pub fn Field::cursor(self : Field) -> (Int32, Int32) {
  (self.cx, self.cy)
}

///|
pub fn Field::steer(self : Field, dx : Int32, dy : Int32) -> Unit {
  let nx = self.cx + dx
  let ny = self.cy + dy
  if nx >= 0 && nx < SIZE {
    self.cx = nx
  }
  if ny >= 0 && ny < SIZE {
    self.cy = ny
  }
}

///|
pub fn Field::toggle_flag(self : Field) -> Unit {
  if self.stage != Playing {
    return
  }
  let index = self.cy * SIZE + self.cx
  if !self.open[index] {
    self.flag[index] = !self.flag[index]
  }
}

///|
/// Reveal the cell under the cursor. A zero opens its neighbours, and their
/// neighbours, until the edge of the empty region is reached.
pub fn Field::reveal(self : Field) -> Unit {
  if self.stage != Playing {
    return
  }
  let start = self.cy * SIZE + self.cx
  if self.flag[start] || self.open[start] {
    return
  }
  if self.mine[start] {
    self.stage = Over
    return
  }
  self.spread(self.cx, self.cy)
  self.check()
}

///|
fn Field::spread(self : Field, x : Int32, y : Int32) -> Unit {
  let stack : Array[(Int32, Int32)] = [(x, y)]
  while stack.length() > 0 {
    let (px, py) = stack.pop().unwrap()
    let index = py * SIZE + px
    if self.open[index] || self.flag[index] {
      continue
    }
    self.open[index] = true
    self.opened = self.opened + 1
    if self.around[index] == 0 {
      for dy in -1..<=1 {
        for dx in -1..<=1 {
          let nx = px + dx
          let ny = py + dy
          if nx >= 0 &&
            nx < SIZE &&
            ny >= 0 &&
            ny < SIZE &&
            !self.open[ny * SIZE + nx] {
            stack.push((nx, ny))
          }
        }
      }
    }
  }
}

///|
fn Field::check(self : Field) -> Unit {
  let safe = SIZE * SIZE - mines_at.length()
  if self.opened >= safe {
    self.stage = Won
  }
}

///|
/// A covered cell is raised and an opened one sunk, each in two shades laid as a
/// checkerboard, so the grid reads without a single line drawn between cells.
fn ground(x : Int32, y : Int32, open : Bool) -> @style.Colour {
  let even = (x + y) % 2 == 0
  match (open, even) {
    (false, true) => @style.Rgb(0x2a, 0x33, 0x48)
    (false, false) => @style.Rgb(0x24, 0x2c, 0x3f)
    (true, true) => @style.Rgb(0x12, 0x17, 0x22)
    (true, false) => @style.Rgb(0x15, 0x1b, 0x27)
  }
}

///|
/// The colour of a number: one and two calm, three to five warm, six and up hot.
fn number_colour(count : Int32) -> @style.Colour {
  if count <= 2 {
    @theme.accent
  } else if count <= 5 {
    @theme.warn
  } else {
    @theme.bad
  }
}

///|
/// One cell, three columns wide: its glyph centred on its ground, or on the
/// accent when the cursor is on it.
fn Field::cell(self : Field, x : Int32, y : Int32) -> @strip.Strip {
  let index = y * SIZE + x
  let open = self.open[index]
  let (glyph, fg) = if self.stage == Over && self.mine[index] {
    ("✳", @theme.bad)
  } else if self.flag[index] {
    ("⚑", @theme.warn)
  } else if !open {
    (" ", @theme.muted)
  } else if self.around[index] == 0 {
    (" ", @theme.faint)
  } else {
    (self.around[index].to_string(), number_colour(self.around[index]))
  }
  let style = if x == self.cx && y == self.cy {
    @style.Style::new(fg=@theme.surface, bg=@theme.accent, bold=true)
  } else {
    @style.Style::new(fg~, bg=ground(x, y, open), bold=true)
  }
  @strip.Strip::of(" " + glyph + " ", style)
}

///|
/// How many mines are not yet flagged.
pub fn Field::left(self : Field) -> Int32 {
  mines_at.length() - self.flag.iter().filter(on => on).count()
}

///|
/// The rows the field takes: a frame above and below the ten rows of cells.
pub const TALL : Int32 = SIZE + 2

///|
/// The columns: three to a cell and a frame on either side.
pub const WIDE : Int32 = SIZE * 3 + 2

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.faint)

///|
impl @widget.Widget for Field with fn render_line(self, row, size) {
  let width = size.width
  let top = if size.height > TALL { (size.height - TALL) / 2 } else { 0 }
  let at = row - top
  if at < 0 || at >= TALL {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let inner = SIZE * 3
  let body = if at == 0 {
    @strip.Strip::of("╭" + @theme.repeat("─", inner) + "╮", frame_style)
  } else if at == TALL - 1 {
    @strip.Strip::of("╰" + @theme.repeat("─", inner) + "╯", frame_style)
  } else {
    let parts = [@strip.Strip::of("│", frame_style)]
    for x in 0..<SIZE {
      parts.push(self.cell(x, at - 1))
    }
    parts.push(@strip.Strip::of("│", frame_style))
    @strip.Strip::join(parts)
  }
  let left = if width > WIDE { (width - WIDE) / 2 } else { 0 }
  @strip.Strip::join([@strip.Strip::blank(left, @style.Style::new()), body]).pad_to(
    width,
    @style.Style::new(),
  )
}

///|
impl @widget.Widget for Field with fn hint(_self, _size) {
  @geom.Size::new(WIDE, TALL)
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
        Char(32) | Enter => {
          self.reveal()
          ctx.repaint()
          true
        }
        Char(102) => {
          self.toggle_flag()
          ctx.repaint()
          true
        }
        Char(114) => {
          let fresh = Field::new()
          self.mine = fresh.mine
          self.open = fresh.open
          self.flag = fresh.flag
          self.around = fresh.around
          self.stage = Playing
          self.opened = 0
          self.cx = 5
          self.cy = 5
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
  field : Field
}

///|
pub fn Screen::new() -> Screen {
  let field = Field::new()
  let band = @theme.line(width => {
    let note = match field.stage() {
      Playing => "\{field.left()} mines left"
      Won => "cleared"
      Over => "boom"
    }
    @theme.band("moonetui", subject="sweep", note~, width~)
  })
  let keys = @theme.line(width => {
    @theme.keys(
      [
        ("arrows", "move"),
        ("space", "reveal"),
        ("f", "flag"),
        ("r", "again"),
        ("q", "quit"),
      ],
      width~,
    )
  })
  let root = @app.column(0, [
    @app.leaf(1, band, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, field, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, keys, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, field, }
}
