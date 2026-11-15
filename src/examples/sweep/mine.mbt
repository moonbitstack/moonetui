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
let hidden_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let cursor_style : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.accent,
  bold=true,
)

///|
let flag_style : @style.Style = @style.Style::new(fg=@theme.warn, bold=true)

///|
let mine_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let hud_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
/// The colour of a number: one and two calm, three to five warm, six and up hot.
fn number_style(count : Int32) -> @style.Style {
  if count <= 2 {
    @style.Style::new(fg=@theme.accent, bold=true)
  } else if count <= 5 {
    @style.Style::new(fg=@theme.warn, bold=true)
  } else {
    @style.Style::new(fg=@theme.bad, bold=true)
  }
}

///|
fn Field::cell(self : Field, x : Int32, y : Int32) -> @strip.Strip {
  let index = y * SIZE + x
  let here = x == self.cx && y == self.cy
  if self.stage == Over && self.mine[index] {
    return @strip.Strip::of("✳ ", mine_style)
  }
  if self.flag[index] {
    return @strip.Strip::of("⚑ ", flag_style)
  }
  if !self.open[index] {
    return @strip.Strip::of(
      "█ ",
      if here {
        cursor_style
      } else {
        hidden_style
      },
    )
  }
  let count = self.around[index]
  if count == 0 {
    return @strip.Strip::of(
      "· ",
      if here {
        cursor_style
      } else {
        hidden_style
      },
    )
  }
  @strip.Strip::of(
    count.to_string() + " ",
    if here {
      cursor_style
    } else {
      number_style(count)
    },
  )
}

///|
impl @widget.Widget for Field with fn render_line(self, row, size) {
  let width = size.width
  if row == 0 {
    let flags : Array[Bool] = self.flag
    let mut placed = 0
    for on in flags {
      if on {
        placed = placed + 1
      }
    }
    let word = match self.stage {
      Playing =>
        "mines " +
        (mines_at.length() - placed).to_string() +
        " · space reveal · f flag"
      Won => "cleared · r to play again"
      Over => "boom · r to play again"
    }
    return @strip.Strip::of(" " + word, hud_style)
  }
  let y = row - 1
  if y < 0 || y >= SIZE {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let box = SIZE * 2
  let offset = if width > box { (width - box) / 2 } else { 0 }
  let parts : Array[@strip.Strip] = []
  if offset > 0 {
    parts.push(@strip.Strip::blank(offset, @style.Style::new()))
  }
  for x in 0..<SIZE {
    parts.push(self.cell(x, y))
  }
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Field with fn hint(_self, _size) {
  @geom.Size::new(SIZE * 2, SIZE + 1)
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
  let root = @app.column(0, [
    @app.leaf(1, field, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, field, }
}
