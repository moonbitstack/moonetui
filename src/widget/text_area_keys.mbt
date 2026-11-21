// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// What the keys and the pointer do in a text area: where a caret goes, which
// character it lands on, and the one place the two kinds of input meet.

///|
fn TextArea::key(self : TextArea, ctx : Ctx, key : @event.Key) -> Bool {
  let ctrl = key.mods.ctrl
  let alt = key.mods.alt
  let shift = key.mods.shift
  if ctrl {
    return self.ctrl_key(ctx, key.code, shift)
  }
  if alt {
    match key.code {
      Backspace => self.edit(ctx, fn() { self.delete_word_left() })
      Delete => self.edit(ctx, fn() { self.delete_word_right() })
      _ => false
    }
  } else {
    match key.code {
      Char(code) => self.edit(ctx, fn() { self.insert_text(text_of(code)) })
      Enter => self.edit(ctx, fn() { self.insert_text("\n") })
      Tab =>
        if self.tab_indents {
          self.edit(ctx, fn() { self.insert_text(spaces(self.indent_width)) })
        } else {
          false
        }
      Backspace => self.edit(ctx, fn() { self.backspace() })
      Delete => self.edit(ctx, fn() { self.delete_right() })
      Left => {
        self.step(ctx)
        self.cursor_left(shift)
        true
      }
      Right => {
        self.step(ctx)
        self.cursor_right(shift)
        true
      }
      Up => {
        self.step(ctx)
        self.cursor_up(shift)
        true
      }
      Down => {
        self.step(ctx)
        self.cursor_down(shift)
        true
      }
      PageUp => {
        self.step(ctx)
        let by = if self.seen_h > 1 { self.seen_h - 1 } else { 1 }
        self.move_to(self.row - by, self.col, select=shift)
        true
      }
      PageDown => {
        self.step(ctx)
        let by = if self.seen_h > 1 { self.seen_h - 1 } else { 1 }
        self.move_to(self.row + by, self.col, select=shift)
        true
      }
      Home => {
        self.step(ctx)
        self.cursor_home(shift)
        true
      }
      End => {
        self.step(ctx)
        self.cursor_end(shift)
        true
      }
      F(6) => {
        self.run = false
        self.anchor_row = self.row
        self.anchor_col = 0
        self.col = self.lines[self.row].length()
        self.selecting = true
        ctx.repaint()
        true
      }
      F(7) => {
        self.run = false
        self.select_all()
        ctx.repaint()
        true
      }
      _ => false
    }
  }
}

///|
fn TextArea::ctrl_key(
  self : TextArea,
  ctx : Ctx,
  code : @event.KeyCode,
  shift : Bool,
) -> Bool {
  match code {
    Left => {
      self.step(ctx)
      let (row, col) = self.word_left()
      self.move_to(row, col, select=shift)
      true
    }
    Right => {
      self.step(ctx)
      let (row, col) = self.word_right()
      self.move_to(row, col, select=shift)
      true
    }
    Backspace => self.edit(ctx, fn() { self.delete_word_left() })
    Char(0x61) => {
      self.step(ctx)
      self.cursor_home(shift)
      true
    }
    Char(0x65) => {
      self.step(ctx)
      self.cursor_end(shift)
      true
    }
    Char(0x64) => self.edit(ctx, fn() { self.delete_right() })
    Char(0x6B) =>
      if shift {
        self.edit(ctx, fn() { self.delete_line() })
      } else {
        self.edit(ctx, fn() { self.delete_to_end() })
      }
    Char(0x75) => self.edit(ctx, fn() { self.delete_to_start() })
    Char(0x76) =>
      if self.clipboard.length() > 0 {
        self.edit(ctx, fn() { self.insert_text(self.clipboard) })
      } else {
        false
      }
    Char(0x77) => self.edit(ctx, fn() { self.delete_word_left() })
    Char(0x78) =>
      if self.selecting {
        self.edit(ctx, fn() {
          self.clipboard = self.selected_text()
          let _ = self.delete_selection()
        })
      } else {
        false
      }
    Char(0x79) => {
      if self.redo() {
        ctx.emit(Changed(id=ctx.id, value=self.text()))
        ctx.repaint()
      }
      true
    }
    Char(0x7A) => {
      if self.undo() {
        ctx.emit(Changed(id=ctx.id, value=self.text()))
        ctx.repaint()
      }
      true
    }
    Char(0x63) =>
      if self.selecting {
        self.clipboard = self.selected_text()
        true
      } else {
        false
      }
    _ => false
  }
}

///|
fn TextArea::mouse(self : TextArea, ctx : Ctx, mouse : @event.Mouse) -> Bool {
  match mouse.kind {
    Down =>
      if mouse.button == 0 {
        ctx.emit(TakeFocus(id=ctx.id))
        self.run = false
        self.dragging = true
        let (row, col) = self.position_of(mouse.x, mouse.y)
        self.anchor_row = row
        self.anchor_col = col
        self.row = row
        self.col = col
        self.selecting = false
        self.follow = true
        ctx.repaint()
        true
      } else {
        false
      }
    Up =>
      if mouse.button == 0 && self.dragging {
        self.dragging = false
        true
      } else {
        false
      }
    Move =>
      if self.dragging {
        let (row, col) = self.position_of(mouse.x, mouse.y)
        if !self.selecting {
          self.selecting = true
        }
        self.row = row
        self.col = col
        ctx.repaint()
        true
      } else {
        false
      }
    ScrollUp => {
      self.offset_y = self.offset_y - 1
      self.follow = false
      ctx.repaint()
      true
    }
    ScrollDown => {
      self.offset_y = self.offset_y + 1
      self.follow = false
      ctx.repaint()
      true
    }
    _ => false
  }
}

///|
fn TextArea::edit(self : TextArea, ctx : Ctx, op : () -> Unit) -> Bool {
  self.checkpoint()
  self.follow = true
  op()
  ctx.emit(Changed(id=ctx.id, value=self.text()))
  ctx.repaint()
  true
}

///|
fn TextArea::step(self : TextArea, ctx : Ctx) -> Unit {
  self.run = false
  self.follow = true
  ctx.repaint()
}

///|
fn TextArea::position_of(
  self : TextArea,
  x : Int32,
  y : Int32,
) -> (Int32, Int32) {
  let row = clamp(self.offset_y + y, 0, self.lines.length() - 1)
  let line = self.lines[row]
  let cell = x - self.gutter_width() + self.offset_x
  let col = if cell <= 0 { 0 } else { @strip.cut_at(line, cell) }
  (row, col)
}

///|
fn TextArea::selection(self : TextArea) -> ((Int32, Int32), (Int32, Int32)) {
  let anchor = (self.anchor_row, self.anchor_col)
  let cursor = (self.row, self.col)
  if !self.selecting {
    return (cursor, cursor)
  }
  if anchor.0 < cursor.0 || (anchor.0 == cursor.0 && anchor.1 <= cursor.1) {
    (anchor, cursor)
  } else {
    (cursor, anchor)
  }
}

///|
fn TextArea::move_to(
  self : TextArea,
  row : Int32,
  col : Int32,
  select~ : Bool = false,
) -> Unit {
  let r = clamp(row, 0, self.lines.length() - 1)
  let c = clamp(col, 0, self.lines[r].length())
  if select {
    if !self.selecting {
      self.selecting = true
      self.anchor_row = self.row
      self.anchor_col = self.col
    }
  } else {
    self.selecting = false
  }
  self.row = r
  self.col = c
}

///|
fn TextArea::cursor_left(self : TextArea, select : Bool) -> Unit {
  if self.col > 0 {
    let line = self.lines[self.row]
    self.move_to(self.row, prev_char(line, self.col), select~)
    return
  }
  if self.row > 0 {
    self.move_to(self.row - 1, self.lines[self.row - 1].length(), select~)
  }
}

///|
fn TextArea::cursor_right(self : TextArea, select : Bool) -> Unit {
  let line = self.lines[self.row]
  if self.col < line.length() {
    self.move_to(self.row, next_char(line, self.col), select~)
    return
  }
  if self.row < self.lines.length() - 1 {
    self.move_to(self.row + 1, 0, select~)
  }
}

///|
fn TextArea::cursor_up(self : TextArea, select : Bool) -> Unit {
  if self.row > 0 {
    self.move_to(self.row - 1, self.col, select~)
  }
}

///|
fn TextArea::cursor_down(self : TextArea, select : Bool) -> Unit {
  if self.row < self.lines.length() - 1 {
    self.move_to(self.row + 1, self.col, select~)
  }
}

///|
fn TextArea::cursor_home(self : TextArea, select : Bool) -> Unit {
  let line = self.lines[self.row]
  let mut first = 0
  while first < line.length() {
    let (code, used) = @strip.code_at(line, first)
    if code != 32 && code != 9 {
      break
    }
    first = first + used
  }
  let target = if self.col == first { 0 } else { first }
  self.move_to(self.row, target, select~)
}

///|
fn TextArea::cursor_end(self : TextArea, select : Bool) -> Unit {
  self.move_to(self.row, self.lines[self.row].length(), select~)
}

///|
fn TextArea::word_left(self : TextArea) -> (Int32, Int32) {
  if self.col == 0 && self.row > 0 {
    return (self.row - 1, self.lines[self.row - 1].length())
  }
  (self.row, word_start(self.lines[self.row], self.col))
}

///|
fn TextArea::word_right(self : TextArea) -> (Int32, Int32) {
  let line = self.lines[self.row]
  if self.col >= line.length() && self.row < self.lines.length() - 1 {
    return (self.row + 1, 0)
  }
  (self.row, word_end(line, self.col))
}
