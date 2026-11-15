// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A four by four board of numbers. A slide moves every tile as far as it
/// goes and merges each pair once; a tile that moves makes the board add one.
pub struct Grid {
  mut cells : Array[Int32]
  mut score : Int32
  mut over : Bool
  mut won : Bool
  mut cursor : Int32
  // A merge leaves a light on the cell it happened at: three frames of fade,
  // counted down by the clock, so the eye can see what just changed.
  flashes : Array[Int32]
}

///|
/// Two tiles to start with — 2 at the top left and 4 at the top right — so the
/// first slide has something to do, and a test knows what it is.
pub fn Grid::new() -> Grid {
  let cells : Array[Int32] = []
  for _ in 0..<16 {
    cells.push(0)
  }
  cells[0] = 2
  cells[3] = 4
  let flashes : Array[Int32] = []
  for _ in 0..<16 {
    flashes.push(0)
  }
  { cells, score: 0, over: false, won: false, cursor: 5, flashes, }
}

///|
pub fn Grid::cell(self : Grid, x : Int32, y : Int32) -> Int32 {
  self.cells[y * 4 + x]
}

///|
pub fn Grid::rows(_self : Grid) -> Int32 {
  4
}

///|
pub fn Grid::score(self : Grid) -> Int32 {
  self.score
}

///|
pub fn Grid::flashing(self : Grid, x : Int32, y : Int32) -> Bool {
  self.flashes[y * 4 + x] > 0
}

///|
/// One frame of the fade. The board calls this from its clock; a test calls it
/// by hand.
pub fn Grid::decay(self : Grid) -> Unit {
  for i in 0..<16 {
    if self.flashes[i] > 0 {
      self.flashes[i] = self.flashes[i] - 1
    }
  }
}

///|
pub fn Grid::over(self : Grid) -> Bool {
  self.over
}

///|
pub fn Grid::won(self : Grid) -> Bool {
  self.won
}

///|
/// Put a board down, for a test or a set piece: sixteen numbers, row by row.
pub fn Grid::fill(self : Grid, cells : Array[Int32]) -> Unit {
  for i in 0..<16 {
    self.cells[i] = if i < cells.length() { cells[i] } else { 0 }
  }
}

///|
pub fn Grid::restart(self : Grid) -> Unit {
  let fresh = Grid::new()
  self.cells = fresh.cells
  self.score = 0
  self.over = false
  self.won = false
  for i in 0..<16 {
    self.flashes[i] = 0
  }
}

///|
/// The sixteen cells of one line, in the order a slide travels through them.
fn line_of(grid : Grid, dir : Int32, index : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for step in 0..<4 {
    let (x, y) = match dir {
      0 => (index, step)
      1 => (3 - step, index)
      2 => (index, 3 - step)
      _ => (step, index)
    }
    out.push(grid.cells[y * 4 + x])
  }
  out
}

///|
fn write_line(
  grid : Grid,
  dir : Int32,
  index : Int32,
  line : Array[Int32],
) -> Unit {
  for step in 0..<4 {
    let (x, y) = match dir {
      0 => (index, step)
      1 => (3 - step, index)
      2 => (index, 3 - step)
      _ => (step, index)
    }
    grid.cells[y * 4 + x] = line[step]
  }
}

///|
/// Squeeze one line towards its start, merging equal neighbours once.
fn squeeze(line : Array[Int32]) -> (Array[Int32], Int32) {
  let packed : Array[Int32] = []
  for value in line {
    if value != 0 {
      packed.push(value)
    }
  }
  let out : Array[Int32] = []
  let mut gained = 0
  let mut i = 0
  while i < packed.length() {
    if i + 1 < packed.length() && packed[i] == packed[i + 1] {
      let merged = packed[i] * 2
      out.push(merged)
      gained = gained + merged
      i = i + 2
    } else {
      out.push(packed[i])
      i = i + 1
    }
  }
  while out.length() < 4 {
    out.push(0)
  }
  (out, gained)
}

///|
/// One slide. A slide that moves nothing is not a turn: the board stays as it
/// is, so a reader is not punished for pressing a wall.
pub fn Grid::slide(self : Grid, dir : Int32) -> Unit {
  if self.over {
    return
  }
  let mut moved = false
  for index in 0..<4 {
    let before = line_of(self, dir, index)
    let (after, gained) = squeeze(before)
    for step in 0..<4 {
      if before[step] != after[step] {
        moved = true
      }
    }
    if gained > 0 {
      self.score = self.score + gained
      // Light the cells the merge landed in.
      for step in 0..<4 {
        if after[step] != 0 && (step == 0 || before[step] != after[step]) {
          self.flashes[index * 4 + step] = 3
        }
      }
    }
    write_line(self, dir, index, after)
  }
  if moved {
    self.spawn()
    self.check()
  }
}

///|
/// The next free cell from a cursor walking the board: deterministic, so a
/// frame test sees the same board a reader does.
fn Grid::spawn(self : Grid) -> Unit {
  self.cursor = (self.cursor + 7) % 16
  for i in 0..<16 {
    let cell = (self.cursor + i) % 16
    if self.cells[cell] == 0 {
      self.cells[cell] = if i % 3 == 0 { 4 } else { 2 }
      return
    }
  }
}

///|
fn Grid::check(self : Grid) -> Unit {
  for value in self.cells {
    if value >= 2048 {
      self.won = true
    }
    if value == 0 {
      return
    }
  }
  // Full: the board is over unless two neighbours still match.
  for y in 0..<4 {
    for x in 0..<4 {
      let value = self.cell(x, y)
      if x < 3 && self.cell(x + 1, y) == value {
        return
      }
      if y < 3 && self.cell(x, y + 1) == value {
        return
      }
    }
  }
  self.over = true
}
