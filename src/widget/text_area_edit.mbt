// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// Every change a text area's text goes through, and the snapshots that make it
// undoable: typing, rubbing out, cutting a selection, and the history both ways.

///|
pub fn TextArea::insert(self : TextArea, text : String) -> Unit {
  self.follow = true
  self.checkpoint()
  self.insert_text(text)
}

///|
pub fn TextArea::undo(self : TextArea) -> Bool {
  self.follow = true
  self.run = false
  if self.undo.length() == 0 {
    return false
  }
  self.redo.push(self.snap())
  let last = self.undo.length() - 1
  let snap = self.undo[last]
  ignore(self.undo.pop())
  self.restore(snap)
  true
}

///|
pub fn TextArea::redo(self : TextArea) -> Bool {
  self.follow = true
  self.run = false
  if self.redo.length() == 0 {
    return false
  }
  self.undo.push(self.snap())
  let last = self.redo.length() - 1
  let snap = self.redo[last]
  ignore(self.redo.pop())
  self.restore(snap)
  true
}

///|
fn TextArea::checkpoint(self : TextArea) -> Unit {
  if self.run {
    return
  }
  self.run = true
  self.undo.push(self.snap())
  if self.undo.length() > self.history {
    let kept : Array[Snap] = []
    let count = self.undo.length()
    for i in 1..<count {
      kept.push(self.undo[i])
    }
    self.undo = kept
  }
  self.redo = []
}

///|
fn TextArea::snap(self : TextArea) -> Snap {
  let lines : Array[String] = []
  for line in self.lines {
    lines.push(line)
  }
  { lines, row: self.row, col: self.col, }
}

///|
fn TextArea::restore(self : TextArea, snap : Snap) -> Unit {
  let lines : Array[String] = []
  for line in snap.lines {
    lines.push(line)
  }
  self.lines = lines
  self.row = clamp(snap.row, 0, self.lines.length() - 1)
  self.col = clamp(snap.col, 0, self.lines[self.row].length())
  self.selecting = false
}

///|
fn TextArea::insert_text(self : TextArea, text : String) -> Unit {
  let _ = self.delete_selection()
  let pieces = line_pieces(text)
  if pieces.length() == 0 {
    return
  }
  if pieces.length() == 1 {
    let line = self.lines[self.row]
    self.lines[self.row] = line[0:self.col].to_owned() +
      pieces[0] +
      line[self.col:].to_owned()
    self.col = self.col + pieces[0].length()
    return
  }
  let line = self.lines[self.row]
  let before = line[0:self.col].to_owned()
  let after = line[self.col:].to_owned()
  self.lines[self.row] = before + pieces[0]
  let last = pieces.length() - 1
  for j in 1..<last {
    self.lines.insert(self.row + j, pieces[j])
  }
  self.lines.insert(self.row + last, pieces[last] + after)
  self.row = self.row + last
  self.col = pieces[last].length()
}

///|
fn TextArea::backspace(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  let line = self.lines[self.row]
  if self.col > 0 {
    let start = prev_char(line, self.col)
    self.lines[self.row] = line[0:start].to_owned() + line[self.col:].to_owned()
    self.col = start
    return
  }
  if self.row > 0 {
    let prev = self.lines[self.row - 1]
    self.col = prev.length()
    self.lines[self.row - 1] = prev + line
    self.drop_row(self.row)
    self.row = self.row - 1
  }
}

///|
fn TextArea::delete_right(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  let line = self.lines[self.row]
  if self.col < line.length() {
    let after = next_char(line, self.col)
    self.lines[self.row] = line[0:self.col].to_owned() + line[after:].to_owned()
    return
  }
  if self.row < self.lines.length() - 1 {
    self.lines[self.row] = line + self.lines[self.row + 1]
    self.drop_row(self.row + 1)
  }
}

///|
fn TextArea::delete_word_left(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  let (row, col) = self.word_left()
  self.delete_range(row, col, self.row, self.col)
}

///|
fn TextArea::delete_word_right(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  let (row, col) = self.word_right()
  self.delete_range(self.row, self.col, row, col)
}

///|
fn TextArea::delete_to_start(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  self.delete_range(self.row, 0, self.row, self.col)
}

///|
fn TextArea::delete_to_end(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  if self.lines[self.row].length() == 0 {
    self.delete_line()
    return
  }
  let end = self.lines[self.row].length()
  self.delete_range(self.row, self.col, self.row, end)
}

///|
fn TextArea::delete_line(self : TextArea) -> Unit {
  if self.delete_selection() {
    return
  }
  if self.lines.length() == 1 {
    self.lines[0] = ""
    self.col = 0
    return
  }
  self.drop_row(self.row)
  if self.row >= self.lines.length() {
    self.row = self.lines.length() - 1
  }
  self.col = clamp(self.col, 0, self.lines[self.row].length())
}

///|
fn TextArea::delete_selection(self : TextArea) -> Bool {
  if !self.selecting {
    return false
  }
  let ((r1, c1), (r2, c2)) = self.selection()
  self.delete_range(r1, c1, r2, c2)
  true
}

///|
fn TextArea::delete_range(
  self : TextArea,
  from_row : Int32,
  from_col : Int32,
  to_row : Int32,
  to_col : Int32,
) -> Unit {
  let (r1, c1, r2, c2) = if from_row < to_row ||
    (from_row == to_row && from_col <= to_col) {
    (from_row, from_col, to_row, to_col)
  } else {
    (to_row, to_col, from_row, from_col)
  }
  if r1 == r2 {
    if c1 == c2 {
      self.selecting = false
      return
    }
    let line = self.lines[r1]
    self.lines[r1] = line[0:c1].to_owned() + line[c2:].to_owned()
  } else {
    let first = self.lines[r1]
    let last = self.lines[r2]
    self.lines[r1] = first[0:c1].to_owned() + last[c2:].to_owned()
    let kept : Array[String] = []
    let count = self.lines.length()
    for i in 0..<count {
      if i > r1 && i <= r2 {
        continue
      }
      kept.push(self.lines[i])
    }
    self.lines = kept
  }
  self.row = r1
  self.col = c1
  self.selecting = false
}

///|
fn TextArea::drop_row(self : TextArea, at : Int32) -> Unit {
  let kept : Array[String] = []
  let count = self.lines.length()
  for i in 0..<count {
    if i == at {
      continue
    }
    kept.push(self.lines[i])
  }
  self.lines = kept
}
