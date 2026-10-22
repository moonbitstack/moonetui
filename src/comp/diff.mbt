// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Span {
  y : Int32
  x : Int32
  line : @strip.Strip
} derive(Eq, Debug)

///|
pub fn diff(
  prev : Array[@strip.Strip],
  next : Array[@strip.Strip],
  base~ : @style.Style = @style.default,
) -> Array[Span] {
  let spans : Array[Span] = []
  for y in 0..<next.length() {
    let before = if y < prev.length() { cells(prev[y]) } else { [] }
    let after = padded(cells(next[y]), before.length(), base)
    match span_of(before, after) {
      None => ()
      Some((from, to)) =>
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
fn span_of(before : Array[Cell], after : Array[Cell]) -> (Int32, Int32)? {
  let width = if after.length() > before.length() {
    after.length()
  } else {
    before.length()
  }
  let mut from = -1
  let mut to = -1
  for x in 0..<width {
    if cell_at(before, x) != cell_at(after, x) {
      if from < 0 {
        from = x
      }
      to = x + 1
    }
  }
  if from < 0 {
    return None
  }
  if from > 0 && after.length() > from && after[from].continuation {
    from = from - 1
  }
  if to < after.length() && after[to].continuation {
    to = to + 1
  }
  Some((from, if to > after.length() { after.length() } else { to }))
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
