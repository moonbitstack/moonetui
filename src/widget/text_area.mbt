// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
struct Snap {
  lines : Array[String]
  row : Int32
  col : Int32
}

///|
pub struct TextArea {
  mut lines : Array[String]
  mut row : Int32
  mut col : Int32
  mut anchor_row : Int32
  mut anchor_col : Int32
  mut selecting : Bool
  mut dragging : Bool
  mut offset_x : Int32
  mut offset_y : Int32
  mut seen_w : Int32
  mut seen_h : Int32
  mut focused : Bool
  indent_width : Int32
  tab_indents : Bool
  show_line_numbers : Bool
  mut clipboard : String
  mut undo : Array[Snap]
  mut redo : Array[Snap]
  mut run : Bool
  // Off while the wheel has moved the view away from the caret.
  mut follow : Bool
  history : Int32
  style : @style.Style
  cursor_style : @style.Style
  selection_style : @style.Style
  gutter_style : @style.Style
  gutter_focus_style : @style.Style
}

///|
pub fn TextArea::new(
  text~ : String = "",
  indent_width~ : Int32 = 4,
  tab_indents~ : Bool = false,
  show_line_numbers~ : Bool = true,
  style~ : @style.Style = @style.Style::new(),
  cursor_style~ : @style.Style = @style.Style::new(reverse=true),
  selection_style~ : @style.Style = @style.Style::new(reverse=true),
  gutter_style~ : @style.Style = @style.Style::new(dim=true),
  gutter_focus_style~ : @style.Style = @style.Style::new(),
  history~ : Int32 = 50,
) -> TextArea {
  let area : TextArea = {
    lines: [],
    row: 0,
    col: 0,
    anchor_row: 0,
    anchor_col: 0,
    selecting: false,
    dragging: false,
    offset_x: 0,
    offset_y: 0,
    seen_w: 0,
    seen_h: 0,
    focused: false,
    indent_width,
    tab_indents,
    show_line_numbers,
    clipboard: "",
    undo: [],
    redo: [],
    run: false,
    follow: true,
    history,
    style,
    cursor_style,
    selection_style,
    gutter_style,
    gutter_focus_style,
  }
  area.load_text(text)
  area
}

///|
pub fn TextArea::text(self : TextArea) -> String {
  let out = StringBuilder()
  for i, line in self.lines {
    if i > 0 {
      out.write_char('\n')
    }
    out.write_string(line)
  }
  out.to_string()
}

///|
pub fn TextArea::load_text(self : TextArea, text : String) -> Unit {
  self.follow = true
  let lines : Array[String] = []
  for piece in split_ending(text) {
    lines.push(piece.0)
  }
  if lines.length() == 0 {
    lines.push("")
  }
  self.lines = lines
  self.row = 0
  self.col = 0
  self.selecting = false
  self.dragging = false
  self.offset_x = 0
  self.offset_y = 0
  self.undo = []
  self.redo = []
  self.run = false
}

///|
pub fn TextArea::line_count(self : TextArea) -> Int32 {
  self.lines.length()
}

///|
pub fn TextArea::cursor(self : TextArea) -> (Int32, Int32) {
  (self.row, self.col)
}

///|
pub fn TextArea::offset(self : TextArea) -> (Int32, Int32) {
  (self.offset_x, self.offset_y)
}

///|
pub fn TextArea::has_selection(self : TextArea) -> Bool {
  self.selecting
}

///|
pub fn TextArea::selected_text(self : TextArea) -> String {
  let ((r1, c1), (r2, c2)) = self.selection()
  if r1 == r2 {
    return self.lines[r1][c1:c2].to_owned()
  }
  let out = StringBuilder()
  out.write_string(self.lines[r1][c1:].to_owned())
  let from = r1 + 1
  for i in from..<r2 {
    out.write_char('\n')
    out.write_string(self.lines[i])
  }
  out.write_char('\n')
  out.write_string(self.lines[r2][0:c2].to_owned())
  out.to_string()
}

///|
pub fn TextArea::select_all(self : TextArea) -> Unit {
  self.follow = true
  if self.lines.length() == 0 {
    return
  }
  self.anchor_row = 0
  self.anchor_col = 0
  let last = self.lines.length() - 1
  self.row = last
  self.col = self.lines[last].length()
  self.selecting = true
}

///|
pub fn TextArea::clear_selection(self : TextArea) -> Unit {
  self.selecting = false
}

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
pub impl Widget for TextArea with fn render_line(self, row, size) {
  self.scroll_to_fit(size)
  let gutter = self.gutter_width()
  let text_w = size.width - gutter
  if size.width <= 0 || text_w < 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let y = self.offset_y + row
  if y < 0 || y >= self.lines.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let line = self.lines[y]
  let mut body = @strip.Strip::of(line, self.style)
    .crop(self.offset_x, self.offset_x + text_w)
    .pad_to(text_w, self.style)
  if self.selecting {
    let ((r1, c1), (r2, c2)) = self.selection()
    if y >= r1 && y <= r2 {
      let start = if y == r1 { @strip.cells_before(line, c1) } else { 0 }
      let end = if y == r2 {
        @strip.cells_before(line, c2)
      } else {
        @strip.str_cells(line)
      }
      let s = start - self.offset_x
      let e = end - self.offset_x
      let lo = if s < 0 { 0 } else { s }
      let hi = if e > text_w { text_w } else { e }
      if hi > lo {
        body = @strip.Strip::join([
          body.crop(0, lo),
          body.crop(lo, hi).apply(self.selection_style),
          body.crop(hi, text_w),
        ])
      }
    }
  }
  if self.focused && y == self.row {
    let at = @strip.cells_before(line, self.col) - self.offset_x
    if at >= 0 && at < text_w {
      body = @strip.Strip::join([
        body.crop(0, at),
        body.crop(at, at + 1).apply(self.cursor_style),
        body.crop(at + 1, text_w),
      ])
    }
  }
  if gutter == 0 {
    return body
  }
  let number = "\{y + 1}"
  let pad = gutter - 1 - number.length()
  let gstyle = if y == self.row && self.focused {
    self.gutter_focus_style
  } else {
    self.gutter_style
  }
  @strip.Strip::join([
    @strip.Strip::blank(pad, gstyle),
    @strip.Strip::of(number, gstyle),
    @strip.Strip::blank(1, gstyle),
    body,
  ])
}

///|
pub impl Widget for TextArea with fn hint(self, _size) {
  let mut widest = 0
  for line in self.lines {
    let cells = @strip.str_cells(line)
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(widest + self.gutter_width(), self.lines.length())
}

///|
pub impl Widget for TextArea with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      self.run = false
      self.dragging = false
      ctx.repaint()
      true
    }
    Paste(text) => {
      self.checkpoint()
      self.follow = true
      self.insert_text(text)
      ctx.emit(Changed(id=ctx.id, value=self.text()))
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key)
    Mouse(mouse) => self.mouse(ctx, mouse)
    _ => false
  }
}

///|
pub impl Widget for TextArea with fn focusable(_self) {
  true
}

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

///|
fn TextArea::gutter_width(self : TextArea) -> Int32 {
  if !self.show_line_numbers {
    return 0
  }
  let mut digits = 1
  let mut n = self.lines.length()
  while n >= 10 {
    n = n / 10
    digits = digits + 1
  }
  digits + 2
}

///|
fn TextArea::scroll_to_fit(self : TextArea, size : @geom.Size) -> Unit {
  let h = size.height
  let w = size.width - self.gutter_width()
  self.seen_w = w
  self.seen_h = h
  if self.follow && self.row < self.offset_y {
    self.offset_y = self.row
  }
  if self.follow && h > 0 && self.row >= self.offset_y + h {
    self.offset_y = self.row - h + 1
  }
  let max_y = if self.lines.length() - h < 0 {
    0
  } else {
    self.lines.length() - h
  }
  self.offset_y = clamp(self.offset_y, 0, max_y)
  if w <= 0 {
    self.offset_x = 0
    return
  }
  let at = @strip.cells_before(self.lines[self.row], self.col)
  if !self.follow {
    ()
  } else if at < self.offset_x {
    self.offset_x = at
  } else if at - self.offset_x >= w {
    self.offset_x = at - w + 1
  }
  let mut widest = 0
  for row in self.lines {
    let cells = @strip.str_cells(row)
    if cells > widest {
      widest = cells
    }
  }
  // One column past the widest line, for the caret to sit after its end.
  let max_x = if widest + 1 - w < 0 { 0 } else { widest + 1 - w }
  self.offset_x = clamp(self.offset_x, 0, max_x)
}

///|
fn spaces(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_char(' ')
  }
  out.to_string()
}

///|
fn line_pieces(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut i = 0
  while i < text.length() {
    let (code, used) = @strip.code_at(text, i)
    // A lone CR breaks a line too: terminals paste newlines as CR.
    if code == 13 && i + used < text.length() {
      let (next, _) = @strip.code_at(text, i + used)
      if next == 10 {
        i = i + used
        continue
      }
    }
    if code == 10 || code == 13 {
      out.push(cur.to_string())
      cur = StringBuilder()
    } else {
      cur.write_string(text[i:i + used].to_owned())
    }
    i = i + used
  }
  out.push(cur.to_string())
  out
}

///|
pub extend TextArea with Widget::{focusable, handle, hint, render_line}
