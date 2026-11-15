// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Where a game is. The title and the score screen are scenes, not overlays on
/// a running game: a reader starts a game and a game ends, and the clock is
/// stopped in both.
#derive(Eq)
pub(all) enum Phase {
  Title
  Playing
  Paused
  Over
}

///|
pub extend Phase with Eq::{not_equal, equal}

///|
/// One spark from a cell that was eaten: where it is, where it drifts, and how
/// many frames of light it has left.
pub(all) struct Spark {
  x : Double
  y : Double
  dx : Double
  dy : Double
  mut life : Int32
}

///|
let steps : Array[(Int32, Int32)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]

///|
pub struct Board {
  cols : Int32
  rows : Int32
  mut body : Array[Int32]
  mut dir : Int32
  mut want : Int32
  mut food : Int32
  mut phase : Phase
  mut score : Int32
  mut best : Int32
  mut cursor : Int32
  mut sparks : Array[Spark]
}

///|
pub fn Board::new(
  cols~ : Int32 = 46,
  rows~ : Int32 = 16,
  cursor~ : Int32 = 3,
) -> Board {
  let mid = rows / 2 * cols + cols / 2
  {
    cols,
    rows,
    body: [mid, mid - 1, mid - 2],
    dir: 1,
    want: 1,
    food: mid + 4,
    phase: Title,
    score: 0,
    best: 0,
    cursor,
    sparks: [],
  }
}

///|
pub fn Board::cols(self : Board) -> Int32 {
  self.cols
}

///|
pub fn Board::rows(self : Board) -> Int32 {
  self.rows
}

///|
pub fn Board::score(self : Board) -> Int32 {
  self.score
}

///|
pub fn Board::best(self : Board) -> Int32 {
  self.best
}

///|
pub fn Board::length(self : Board) -> Int32 {
  self.body.length()
}

///|
pub fn Board::phase(self : Board) -> Phase {
  self.phase
}

///|
/// The sparks in the air, as a count a test can watch.
pub fn Board::sparks(self : Board) -> Int32 {
  self.sparks.length()
}

///|
pub fn Board::head(self : Board) -> (Int32, Int32) {
  let cell = self.body[0]
  (cell % self.cols, cell / self.cols)
}

///|
pub fn Board::food_at(self : Board) -> (Int32, Int32) {
  (self.food % self.cols, self.food / self.cols)
}

///|
/// Begin. From the title or from the score screen, the board is the same.
pub fn Board::start(self : Board) -> Unit {
  let mid = self.rows / 2 * self.cols + self.cols / 2
  self.body = [mid, mid - 1, mid - 2]
  self.dir = 1
  self.want = 1
  self.score = 0
  self.phase = Playing
  self.sparks = []
  self.food = self.spawn()
}

///|
/// The same as `start`: the keys say "again", the board says "start".
pub fn Board::restart(self : Board) -> Unit {
  self.start()
}

///|
pub fn Board::turn(self : Board, dir : Int32) -> Unit {
  if self.phase != Playing {
    return
  }
  if (dir + 2) % 4 == self.dir && self.length() > 1 {
    return
  }
  self.want = dir
}

///|
pub fn Board::toggle_pause(self : Board) -> Unit {
  match self.phase {
    Playing => self.phase = Paused
    Paused => self.phase = Playing
    _ => ()
  }
}

///|
pub fn Board::step(self : Board) -> Unit {
  if self.phase != Playing {
    return
  }
  self.dir = self.want
  let (dx, dy) = steps[self.dir]
  let (x, y) = self.head()
  let nx = x + dx
  let ny = y + dy
  if nx < 0 || nx >= self.cols || ny < 0 || ny >= self.rows {
    self.phase = Over
    return
  }
  let next = ny * self.cols + nx
  let tail = self.body[self.body.length() - 1]
  let ate = next == self.food
  if self.body.contains(next) && (next != tail || ate) {
    self.phase = Over
    return
  }
  self.body.insert(0, next)
  if ate {
    self.score = self.score + 1
    if self.score > self.best {
      self.best = self.score
    }
    self.burst(nx, ny)
    self.food = self.spawn()
  } else {
    ignore(self.body.pop())
  }
  if self.length() == self.cols * self.rows {
    self.phase = Over
  }
}

///|
/// Six sparks thrown from a cell that was eaten, one for each way out.
fn Board::burst(self : Board, x : Int32, y : Int32) -> Unit {
  let paths : Array[(Double, Double)] = [
    (-0.7, -0.5),
    (0.0, -1.0),
    (0.7, -0.5),
    (0.7, 0.5),
    (0.0, 1.0),
    (-0.7, 0.5),
  ]
  for path in paths {
    let (dx, dy) = path
    self.sparks.push({ x: x.to_double(), y: y.to_double(), dx, dy, life: 4, })
  }
}

///|
/// Move the sparks a frame and drop the ones that have burned out. A test calls
/// this as often as the clock does.
pub fn Board::drift(self : Board) -> Unit {
  let alive : Array[Spark] = []
  for spark in self.sparks {
    if spark.life > 1 {
      alive.push({
        x: spark.x + spark.dx,
        y: spark.y + spark.dy,
        dx: spark.dx,
        dy: spark.dy,
        life: spark.life - 1,
      })
    }
  }
  self.sparks = alive
}

///|
fn Board::spawn(self : Board) -> Int32 {
  let cells = self.cols * self.rows
  self.cursor = self.cursor + 7
  for i in 0..<cells {
    let cell = (self.cursor + i) % cells
    if !self.body.contains(cell) {
      return cell
    }
  }
  0
}

///|
pub fn Board::place_food(self : Board, cell : Int32) -> Unit {
  self.food = cell
}

///|
pub fn Board::cell_at(self : Board, x : Int32, y : Int32) -> Int32 {
  y * self.cols + x
}

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.good, bold=true)

///|
let body_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let tail_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let food_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let spark_style : @style.Style = @style.Style::new(fg=@theme.warn, bold=true)

///|
let hud_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let value_style : @style.Style = @style.Style::new(fg=@theme.ink, bold=true)

///|
let title_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let over_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let blank_style : @style.Style = @style.Style::new()

///|
fn centred(text : String, width : Int32, style : @style.Style) -> @strip.Strip {
  let pad = (width - @strip.str_cells(text)) / 2
  if pad <= 0 {
    return @strip.Strip::of(text, style)
  }
  @strip.Strip::join([
    @strip.Strip::blank(pad, blank_style),
    @strip.Strip::of(text, style),
  ])
}

///|
/// The line above the field: what the game keeps count of, and nothing else.
fn Board::hud(self : Board) -> @strip.Strip {
  let parts : Array[@strip.Strip] = [
    @strip.Strip::of(" score ", hud_style),
    @strip.Strip::of(self.score.to_string(), value_style),
    @strip.Strip::of("   best ", hud_style),
    @strip.Strip::of(self.best.to_string(), value_style),
    @strip.Strip::of("   length ", hud_style),
    @strip.Strip::of(self.length().to_string(), value_style),
    @strip.Strip::of("   ", hud_style),
  ]
  @strip.Strip::join(parts)
}

///|
/// What the title and the score screens say, one entry a row, centred.
fn Board::scene_line(self : Board, row : Int32) -> (String, @style.Style)? {
  let middle = self.rows / 2
  match self.phase {
    Title =>
      if row == middle - 1 {
        Some(("S N A K E", title_style))
      } else if row == middle + 1 {
        Some(("space to play", hud_style))
      } else if row == middle + 2 {
        Some(("best " + self.best.to_string(), hud_style))
      } else {
        None
      }
    Over =>
      if row == middle - 1 {
        Some(("G A M E   O V E R", over_style))
      } else if row == middle {
        Some(
          (
            "score " +
            self.score.to_string() +
            " · best " +
            self.best.to_string(),
            value_style,
          ),
        )
      } else if row == middle + 2 {
        Some(("r to play again · esc to quit", hud_style))
      } else {
        None
      }
    Paused =>
      if row == middle {
        Some(("paused — space", hud_style))
      } else {
        None
      }
    Playing => None
  }
}

///|
/// Where a spark is drawn, if it is on the board.
fn Board::spark_at(self : Board, x : Int32, y : Int32) -> Bool {
  for spark in self.sparks {
    let sx = spark.x.to_int()
    let sy = spark.y.to_int()
    if sx == x && sy == y {
      return true
    }
  }
  false
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  if width < 8 {
    return @strip.Strip::blank(width, blank_style)
  }
  if row == 0 {
    return self.hud()
  }
  let y = row - 1
  if y < 0 || y >= self.rows {
    return @strip.Strip::blank(width, blank_style)
  }
  // The field is centred in the width it is given, and a scene's words sit on
  // top of it: a title covers the field rather than squeezing it.
  let offset = if width > self.cols { (width - self.cols) / 2 } else { 0 }
  match self.scene_line(y) {
    Some((text, style)) =>
      @strip.Strip::join([
        @strip.Strip::blank(offset, blank_style),
        centred(text, self.cols, style),
      ])
    None => {
      let parts : Array[@strip.Strip] = []
      if offset > 0 {
        parts.push(@strip.Strip::blank(offset, blank_style))
      }
      for x in 0..<self.cols {
        let cell = self.cell_at(x, y)
        if self.phase == Title {
          // A title screen has no snake on it.
          parts.push(@strip.Strip::blank(1, blank_style))
        } else if cell == self.body[0] {
          parts.push(@strip.Strip::of("◆", head_style))
        } else if cell == self.food {
          parts.push(@strip.Strip::of("◎", food_style))
        } else if self.spark_at(x, y) {
          parts.push(@strip.Strip::of("*", spark_style))
        } else if self.body.contains(cell) {
          if cell == self.body[self.body.length() - 1] {
            parts.push(@strip.Strip::of("·", tail_style))
          } else {
            parts.push(@strip.Strip::of("●", body_style))
          }
        } else {
          parts.push(@strip.Strip::blank(1, blank_style))
        }
      }
      @strip.Strip::join(parts)
    }
  }
}

///|
impl @widget.Widget for Board with fn hint(self, _size) {
  @geom.Size::new(self.cols, self.rows + 1)
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
        Char(32) => {
          match self.phase {
            Title => self.start()
            Over => self.start()
            _ => self.toggle_pause()
          }
          ctx.repaint()
          true
        }
        Char(114) => {
          self.start()
          ctx.repaint()
          true
        }
        Up => {
          self.turn(0)
          ctx.repaint()
          true
        }
        Right => {
          self.turn(1)
          ctx.repaint()
          true
        }
        Down => {
          self.turn(2)
          ctx.repaint()
          true
        }
        Left => {
          self.turn(3)
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}
