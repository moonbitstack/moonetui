// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The game the `snake` example runs, in a package of its own so a test can
// reach it: a grid, a snake, one apple, and the four keys that turn it.

///|
#derive(Eq)
pub(all) enum Phase {
  /// What the board is doing. A wall, or the snake's own tail, ends a game; the
  /// other two phases are the ones a reader moves between.
  Playing
  Paused
  Over
}

///|
pub extend Phase with Eq::{not_equal, equal}

///|
/// The four directions, as the delta the head moves by.
let steps : Array[(Int32, Int32)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]

///|
/// A playfield, the snake on it, and the apple it is after.
pub struct Board {
  cols : Int32
  rows : Int32
  mut body : Array[Int32]
  mut dir : Int32
  mut want : Int32
  mut food : Int32
  mut phase : Phase
  mut score : Int32
  mut cursor : Int32
}

///|
/// A board with three cells in the middle, heading right, and an apple ahead
/// of it. The apple is placed by a cursor walking the grid, not by a random
/// number: a test that passes the same start sees the same game.
pub fn Board::new(
  cols~ : Int32 = 30,
  rows~ : Int32 = 12,
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
    phase: Playing,
    score: 0,
    cursor,
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
pub fn Board::length(self : Board) -> Int32 {
  self.body.length()
}

///|
pub fn Board::phase(self : Board) -> Phase {
  self.phase
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
/// Turn the head. A turn straight back into the neck is refused, which is what
/// a player expects when two keys arrive in one frame.
pub fn Board::turn(self : Board, dir : Int32) -> Unit {
  if self.phase == Over {
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
    Over => ()
  }
}

///|
/// Start again from the middle, with the apple on a cell the last game did not
/// use: a second game is not the first one replayed.
pub fn Board::restart(self : Board) -> Unit {
  let mid = self.rows / 2 * self.cols + self.cols / 2
  self.body = [mid, mid - 1, mid - 2]
  self.dir = 1
  self.want = 1
  self.score = 0
  self.phase = Playing
  self.food = self.spawn()
}

///|
/// One frame of the game: the head moves, the tail follows unless an apple was
/// taken, and a wall or the snake's own body ends it.
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
  // The tail cell is free on the frame the snake leaves it, so running into it
  // is not a crash — unless the snake just grew and the tail stayed put.
  if self.body.contains(next) && (next != tail || ate) {
    self.phase = Over
    return
  }
  self.body.insert(0, next)
  if ate {
    self.score = self.score + 1
    self.food = self.spawn()
  } else {
    ignore(self.body.pop())
  }
  if self.length() == self.cols * self.rows {
    self.phase = Over
  }
}

///|
/// Put the apple on a free cell the cursor reaches: the walk is deterministic,
/// so a frame test can say where the apple is.
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
let frame_style : @style.Style = @style.Style::new(fg=@theme.accent, dim=true)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.good, bold=true)

///|
let body_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let food_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let banner_style : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.warn,
  bold=true,
)

///|
let blank_style : @style.Style = @style.Style::new()

///|
fn Board::cell_strip(self : Board, x : Int32, y : Int32) -> @strip.Strip {
  let cell = self.cell_at(x, y)
  if cell == self.body[0] {
    return @strip.Strip::of("█", head_style)
  }
  if self.body.contains(cell) {
    return @strip.Strip::of("█", body_style)
  }
  if cell == self.food {
    return @strip.Strip::of("●", food_style)
  }
  @strip.Strip::blank(1, blank_style)
}

///|
/// The words a paused or finished board says, on the row it says them on.
fn Board::banner(self : Board, y : Int32) -> String? {
  // Two rows above the bottom edge: the snake is usually in the middle, and a
  // banner that covers the snake is a banner a player cannot see past.
  if y != self.rows - 3 {
    return None
  }
  match self.phase {
    Playing => None
    Paused => Some(" paused — space ")
    Over => Some(" game over — r ")
  }
}

///|
fn Board::phase_text(self : Board) -> String {
  match self.phase {
    Playing => "playing"
    Paused => "paused"
    Over => "over"
  }
}

///|
fn repeat_glyph(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  if width < 4 {
    return @strip.Strip::blank(width, blank_style)
  }
  let inner = width - 2
  // The playfield is narrower than the frame on a wide terminal: it sits in
  // the middle, where a reader's eye already is.
  let offset = if inner > self.cols { (inner - self.cols) / 2 } else { 0 }
  if row == 0 {
    let left = "─ score " + self.score.to_string() + " "
    let right = " " + self.phase_text() + " "
    let fill = inner - @strip.str_cells(left) - @strip.str_cells(right)
    let parts : Array[@strip.Strip] = [
      @strip.Strip::of("╭", frame_style),
      @strip.Strip::of(left, frame_style),
    ]
    if fill > 0 {
      parts.push(@strip.Strip::of(repeat_glyph("─", fill), frame_style))
    }
    parts.push(@strip.Strip::of(right, frame_style))
    parts.push(@strip.Strip::of("╮", frame_style))
    return @strip.Strip::join(parts)
  }
  if row == self.rows + 1 {
    return @strip.Strip::join([
      @strip.Strip::of("╰", frame_style),
      @strip.Strip::of(repeat_glyph("─", inner), frame_style),
      @strip.Strip::of("╯", frame_style),
    ])
  }
  let y = row - 1
  let parts : Array[@strip.Strip] = [@strip.Strip::of("│", frame_style)]
  if offset > 0 {
    parts.push(@strip.Strip::blank(offset, blank_style))
  }
  match self.banner(y) {
    Some(text) => {
      let cells = @strip.str_cells(text)
      let left = (self.cols - cells) / 2
      let right = self.cols - cells - left
      if left > 0 {
        parts.push(@strip.Strip::blank(left, blank_style))
      }
      parts.push(@strip.Strip::of(text, banner_style))
      if right > 0 {
        parts.push(@strip.Strip::blank(right, blank_style))
      }
    }
    None =>
      for x in 0..<self.cols {
        parts.push(self.cell_strip(x, y))
      }
  }
  if inner > self.cols + offset {
    parts.push(@strip.Strip::blank(inner - self.cols - offset, blank_style))
  }
  parts.push(@strip.Strip::of("│", frame_style))
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Board with fn hint(self, size) {
  ignore(size)
  @geom.Size::new(self.cols + 2, self.rows + 2)
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
        Char(32) => {
          if self.phase == Over {
            self.restart()
          } else {
            self.toggle_pause()
          }
          ctx.repaint()
          true
        }
        Char(114) => {
          self.restart()
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}
