// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
#derive(Eq, Debug)
pub(all) struct Span {
  y : Int32
  x : Int32
  line : @strip.Strip
}

///|
/// Two cells this far apart are cheaper to reach with a second cursor move
/// than to redraw across: a cursor move is eight bytes, a cell is one or more.
const RUN_GAP : Int32 = 8

///|
/// The spans that turn one screen into the next: one per run of changed cells,
/// so a row with two changes far apart is written as two short spans rather
/// than as everything between them.
pub fn diff(
  prev : Array[@strip.Strip],
  next : Array[@strip.Strip],
  base~ : @style.Style = @style.default,
) -> Array[Span] {
  diff_rows(prev, next, base~)
}

///|
/// `diff` over the rows named, for a frame that only redrew part of the
/// screen: rows outside the list are taken as unchanged.
pub fn diff_rows(
  prev : Array[@strip.Strip],
  next : Array[@strip.Strip],
  over? : Array[Int32],
  base~ : @style.Style = @style.default,
) -> Array[Span] {
  let rows = match over {
    Some(list) => list
    None => {
      let all : Array[Int32] = []
      for y in 0..<next.length() {
        all.push(y)
      }
      all
    }
  }
  let spans : Array[Span] = []
  for y in rows {
    if y < 0 || y >= next.length() {
      continue
    }
    let before = if y < prev.length() { cells(prev[y]) } else { [] }
    let after = padded(cells(next[y]), before.length(), base)
    for run in changed_runs(before, after) {
      let (from, to) = run
      spans.push({ y, x: from, line: line_of(after[from:to], base), })
    }
  }
  spans
}

///|
fn padded(row : Array[Cell], width : Int32, base : @style.Style) -> Array[Cell] {
  if row.length() >= width {
    return row
  }
  let out : Array[Cell] = []
  for cell in row {
    out.push(cell)
  }
  for _ in row.length()..<width {
    out.push(Cell::blank(base))
  }
  out
}

///|
pub fn full(next : Array[@strip.Strip]) -> Array[Span] {
  let spans : Array[Span] = []
  for y in 0..<next.length() {
    spans.push({ y, x: 0, line: next[y], })
  }
  spans
}

///|
/// The runs of changed cells in one row, each wide enough for a whole wide
/// character: a run never begins or ends in the middle of one.
fn changed_runs(
  before : Array[Cell],
  after : Array[Cell],
) -> Array[(Int32, Int32)] {
  let width = if after.length() > before.length() {
    after.length()
  } else {
    before.length()
  }
  let runs : Array[(Int32, Int32)] = []
  let mut from = -1
  let mut to = -1
  for x in 0..<width {
    if cell_at(before, x) == cell_at(after, x) {
      continue
    }
    if from >= 0 && x - to >= RUN_GAP {
      runs.push(whole(from, to, after))
      from = -1
    }
    if from < 0 {
      from = x
    }
    to = x + 1
  }
  if from >= 0 {
    runs.push(whole(from, to, after))
  }
  runs
}

///|
fn whole(from : Int32, to : Int32, after : Array[Cell]) -> (Int32, Int32) {
  let mut first = from
  let mut last = to
  if first > 0 && after.length() > first && after[first].continuation {
    first = first - 1
  }
  if last < after.length() && after[last].continuation {
    last = last + 1
  }
  (first, if last > after.length() { after.length() } else { last })
}

///|
fn cell_at(row : Array[Cell], x : Int32) -> Cell {
  if x < row.length() {
    row[x]
  } else {
    Cell::blank(@style.default)
  }
}

///|
pub extend Span with Debug::{to_repr}

///|
pub extend Span with Eq::{not_equal, equal}
