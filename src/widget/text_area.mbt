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
  caret : Caret?
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
  caret? : Caret,
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
    caret,
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
  if self.focused && y == self.row && self.caret is None {
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

///|
pub impl Widget for TextArea with fn caret(self, size) {
  guard self.focused && self.caret is Some(caret) else { return None }
  self.scroll_to_fit(size)
  let gutter = self.gutter_width()
  let y = self.row - self.offset_y
  let x = gutter +
    @strip.cells_before(self.lines[self.row], self.col) -
    self.offset_x
  if y < 0 || y >= size.height || x < gutter || x >= size.width {
    return None
  }
  Some(({ x, y, }, caret))
}
