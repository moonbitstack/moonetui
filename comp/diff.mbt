// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A run of columns to repaint: where it goes and what goes there.
pub(all) struct Span {
  y : Int
  x : Int
  line : @strip.Strip
} derive(Eq, Debug)

///|
/// What has to be repainted to turn one screen into the next.
///
/// One span per row at most: the columns from the first difference to the last.
/// Repainting the untouched columns between two changes costs a few bytes;
/// moving the cursor to skip them costs about as many, and a terminal redraws a
/// contiguous run faster than it handles two jumps.
pub fn diff(
  prev : Array[@strip.Strip],
  next : Array[@strip.Strip],
  base? : @style.Style = @style.default,
) -> Array[Span] {
  let spans : Array[Span] = []
  for y in 0..<next.length() {
    let before = if y < prev.length() { cells(prev[y]) } else { [] }
    // A row that used to be longer leaves columns behind that nothing draws any
    // more. They belong to the new row as blanks, or the old text stays on the
    // screen.
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
fn padded(row : Array[Cell], width : Int, base : @style.Style) -> Array[Cell] {
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
/// Every row, as if nothing had been drawn before. Used on the first frame and
/// after anything that invalidates the terminal's contents, such as a resize.
pub fn full(next : Array[@strip.Strip]) -> Array[Span] {
  let spans : Array[Span] = []
  for y in 0..<next.length() {
    spans.push({ y, x: 0, line: next[y], })
  }
  spans
}

///|
/// The half-open column range in which the two rows differ, or `None` when they
/// are the same. A column that is the second half of a wide character drags its
/// first half into the range, since neither half can be painted alone.
fn span_of(before : Array[Cell], after : Array[Cell]) -> (Int, Int)? {
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
/// The column, or a blank one past the end of the row: a row that used to be
/// longer has to have its tail cleared, so the comparison has to see something
/// there.
fn cell_at(row : Array[Cell], x : Int) -> Cell {
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
