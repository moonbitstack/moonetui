// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The invaders, on a fixed field: a row of guns at the bottom, a block of
// enemies marching down, and one bullet in the air at a time.

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
pub struct Field {
  cols : Int32
  rows : Int32
  mut stage : Stage
  mut player : Int32
  mut alive : Array[Bool]
  mut left : Int32
  mut dir : Int32
  mut bullet : (Int32, Int32)?
  mut score : Int32
  mut lives : Int32
  mut slow : Int32
  mut down : Int32
}

///|
/// Twenty-four invaders in eight columns and three rows: the classic block.
pub fn Field::new(cols~ : Int32 = 46, rows~ : Int32 = 16) -> Field {
  let alive : Array[Bool] = []
  for _ in 0..<24 {
    alive.push(true)
  }
  {
    cols,
    rows,
    stage: Title,
    player: cols / 2,
    alive,
    left: 0,
    dir: 1,
    bullet: None,
    score: 0,
    lives: 3,
    slow: 0,
    down: 0,
  }
}

///|
pub fn Field::stage(self : Field) -> Stage {
  self.stage
}

///|
pub fn Field::score(self : Field) -> Int32 {
  self.score
}

///|
pub fn Field::lives(self : Field) -> Int32 {
  self.lives
}

///|
pub fn Field::left(self : Field) -> Int32 {
  self.left
}

///|
pub fn Field::start(self : Field) -> Unit {
  let alive : Array[Bool] = []
  for _ in 0..<24 {
    alive.push(true)
  }
  self.alive = alive
  self.player = self.cols / 2
  self.left = 0
  self.dir = 1
  self.bullet = None
  self.score = 0
  self.lives = 3
  self.slow = 0
  self.down = 0
  self.stage = Playing
}

///|
/// Where an invader sits, by its index in the block.
fn Field::spot(self : Field, index : Int32) -> (Int32, Int32) {
  let column = index % 8
  let row = index / 8
  (2 + self.left + column * 4, 2 + self.down + row * 2)
}

///|
/// One frame of the invasion: the block marches, bullets travel, and what meets
/// what is decided here.
pub fn Field::step(self : Field) -> Unit {
  if self.stage != Playing {
    return
  }
  // The block takes a step every third frame, which is what makes it march
  // rather than teleport.
  self.slow = self.slow + 1
  if self.slow >= 3 {
    self.slow = 0
    let mut edge = false
    for i in 0..<24 {
      if self.alive[i] {
        let (x, _) = self.spot(i)
        if (self.dir > 0 && x >= self.cols - 3) || (self.dir < 0 && x <= 1) {
          edge = true
        }
      }
    }
    if edge {
      self.dir = -self.dir
      self.descend()
    } else {
      self.left = self.left + self.dir
    }
  }
  // The bullet: up one row a frame, and it takes the first invader it meets.
  match self.bullet {
    Some((bx, by)) =>
      if by <= 1 {
        self.bullet = None
      } else {
        let ny = by - 1
        let mut hit = -1
        for i in 0..<24 {
          if self.alive[i] {
            let (x, y) = self.spot(i)
            if y == ny && (x == bx || x + 1 == bx) {
              hit = i
            }
          }
        }
        if hit >= 0 {
          self.alive[hit] = false
          self.score = self.score + 10
          self.bullet = None
        } else {
          self.bullet = Some((bx, ny))
        }
      }
    None => ()
  }
  // Reaching the bottom costs a life; losing them all ends the run.
  for i in 0..<24 {
    if self.alive[i] {
      let (_, y) = self.spot(i)
      if y >= self.rows - 1 {
        self.lives = 0
      }
    }
  }
  if self.lives <= 0 {
    self.stage = Over
  }
}

///|
/// The block moves down a row: the rows an invader sits on are kept beside the
/// block so a descent moves all of them at once.
fn Field::descend(self : Field) -> Unit {
  self.down = self.down + 1
}

///|
pub fn Field::shoot(self : Field) -> Unit {
  if self.stage != Playing {
    return
  }
  if self.bullet is None {
    self.bullet = Some((self.player, self.rows - 2))
  }
}

///|
pub fn Field::steer(self : Field, step : Int32) -> Unit {
  let next = self.player + step
  if next >= 1 && next < self.cols - 1 {
    self.player = next
  }
}

///|
impl @widget.Widget for Field with fn render_line(self, row, size) {
  let width = size.width
  if row == 0 {
    let word = match self.stage {
      Title => "space to play"
      Playing => "score " + self.score.to_string()
      Over => "game over · r to play again"
    }
    return @strip.Strip::of(" " + word, @style.Style::new(fg=@theme.muted))
  }
  let y = row - 1
  if y < 0 || y >= self.rows {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let offset = if width > self.cols { (width - self.cols) / 2 } else { 0 }
  let parts : Array[@strip.Strip] = []
  if offset > 0 {
    parts.push(@strip.Strip::blank(offset, @style.Style::new()))
  }
  for x in 0..<self.cols {
    parts.push(self.cell(x, y))
  }
  @strip.Strip::join(parts)
}

///|
fn Field::cell(self : Field, x : Int32, y : Int32) -> @strip.Strip {
  if self.stage == Title {
    return @strip.Strip::blank(1, @style.Style::new())
  }
  match self.bullet {
    Some((bx, by)) =>
      if bx == x && by == y {
        return @strip.Strip::of(
          "│",
          @style.Style::new(fg=@theme.warn, bold=true),
        )
      }
    None => ()
  }
  for i in 0..<24 {
    if self.alive[i] {
      let (ex, ey) = self.spot(i)
      if ey == y && (ex == x || ex + 1 == x) {
        let glyph = if y / 2 % 2 == 0 { "▼" } else { "▽" }
        return @strip.Strip::of(
          glyph,
          @style.Style::new(fg=@theme.bad, bold=true),
        )
      }
    }
  }
  if y == self.rows - 1 && x == self.player {
    return @strip.Strip::of("▲", @style.Style::new(fg=@theme.good, bold=true))
  }
  @strip.Strip::blank(1, @style.Style::new())
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
          match self.stage {
            Title => self.start()
            Over => self.start()
            Playing => self.shoot()
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
          self.steer(-1)
          ctx.repaint()
          true
        }
        Right => {
          self.steer(1)
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
