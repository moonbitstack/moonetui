// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum CursorType {
  Cell
  Row
  Column
  None
} derive(Eq, Debug)

///|
pub extend CursorType with Debug::{to_repr}

///|
pub extend CursorType with Eq::{not_equal, equal}

///|
pub(all) struct Column {
  label : String
  width : Int32
  align : Align
} derive(Eq, Debug)

///|
pub extend Column with Debug::{to_repr}

///|
pub extend Column with Eq::{not_equal, equal}

///|
pub fn Column::new(
  label : String,
  width~ : Int32 = 0,
  align~ : Align = Left,
) -> Column {
  { label, width, align, }
}

///|
pub(all) struct Row {
  label : String
  cells : Array[String]
} derive(Eq, Debug)

///|
pub extend Row with Debug::{to_repr}

///|
pub extend Row with Eq::{not_equal, equal}

///|
pub fn Row::new(cells : Array[String], label~ : String = "") -> Row {
  { label, cells, }
}

///|
pub struct DataTable {
  mut columns : Array[Column]
  mut rows : Array[Row]
  mut cursor_row : Int32
  mut cursor_col : Int32
  cursor_type : CursorType
  show_cursor : Bool
  zebra : Bool
  show_header : Bool
  show_row_labels : Bool
  cell_padding : Int32
  mut hover_row : Int32
  mut hover_col : Int32
  mut offset_x : Int32
  mut offset_y : Int32
  mut seen : Int32
  mut focused : Bool
  header_style : @style.Style
  cursor_style : @style.Style
  hover_style : @style.Style
  odd_style : @style.Style
  even_style : @style.Style
  label_style : @style.Style
  style : @style.Style
} derive(Eq, Debug)

///|
pub extend DataTable with Debug::{to_repr}

///|
pub extend DataTable with Eq::{not_equal, equal}

///|
pub fn DataTable::new(
  show_header~ : Bool = true,
  show_row_labels~ : Bool = true,
  zebra~ : Bool = false,
  cursor_type~ : CursorType = Cell,
  cell_padding~ : Int32 = 1,
  header_style~ : @style.Style = @style.Style::new(bold=true),
  cursor_style~ : @style.Style = @style.Style::new(reverse=true),
  hover_style~ : @style.Style = @style.Style::new(bold=true),
  odd_style~ : @style.Style = @style.Style::new(),
  even_style~ : @style.Style = @style.Style::new(bg=@style.bright_black),
  label_style~ : @style.Style = @style.Style::new(dim=true),
  style~ : @style.Style = @style.Style::new(),
) -> DataTable {
  {
    columns: [],
    rows: [],
    cursor_row: 0,
    cursor_col: 0,
    cursor_type,
    show_cursor: true,
    zebra,
    show_header,
    show_row_labels,
    cell_padding,
    hover_row: -1,
    hover_col: -1,
    offset_x: 0,
    offset_y: 0,
    seen: 0,
    focused: false,
    header_style,
    cursor_style,
    hover_style,
    odd_style,
    even_style,
    label_style,
    style,
  }
}

///|
pub fn DataTable::add_column(
  self : DataTable,
  label : String,
  width~ : Int32 = 0,
  align~ : Align = Left,
) -> Int32 {
  let index = self.columns.length()
  self.columns.push(Column::new(label, width~, align~))
  index
}

///|
pub fn DataTable::add_row(
  self : DataTable,
  cells : Array[String],
  label~ : String = "",
) -> Int32 {
  let index = self.rows.length()
  self.rows.push(Row::new(cells, label~))
  index
}

///|
pub fn DataTable::clear_rows(self : DataTable) -> Unit {
  self.rows = []
  self.cursor_row = 0
  self.cursor_col = 0
  self.hover_row = -1
  self.hover_col = -1
  self.offset_x = 0
  self.offset_y = 0
}

///|
pub fn DataTable::clear(self : DataTable) -> Unit {
  self.clear_rows()
  self.columns = []
}

///|
pub fn DataTable::row_count(self : DataTable) -> Int32 {
  self.rows.length()
}

///|
pub fn DataTable::column_count(self : DataTable) -> Int32 {
  self.columns.length()
}

///|
pub fn DataTable::cell(self : DataTable, row : Int32, col : Int32) -> String {
  if row < 0 || row >= self.rows.length() {
    return ""
  }
  if col < 0 || col >= self.rows[row].cells.length() {
    return ""
  }
  self.rows[row].cells[col]
}

///|
pub fn DataTable::set_cell(
  self : DataTable,
  row : Int32,
  col : Int32,
  value : String,
) -> Unit {
  if row < 0 || row >= self.rows.length() {
    return
  }
  if col < 0 || col >= self.rows[row].cells.length() {
    return
  }
  self.rows[row].cells[col] = value
}

///|
fn text_before(a : String, b : String) -> Bool {
  // String `<` in the core compares lengths first; a table wants the
  // plain code-unit order.
  let span = if a.length() < b.length() { a.length() } else { b.length() }
  let mut at = 0
  while at < span {
    if a[at] != b[at] {
      return a[at].to_int() < b[at].to_int()
    }
    at = at + 1
  }
  a.length() < b.length()
}

///|
pub fn DataTable::sort(
  self : DataTable,
  col : Int32,
  reverse~ : Bool = false,
) -> Unit {
  if col < 0 || col >= self.columns.length() {
    return
  }
  let count = self.rows.length()
  for i in 1..<count {
    let held = self.rows[i]
    let mut at = i
    let mut go = text_before(held.cells[col], self.rows[at - 1].cells[col])
    if reverse {
      go = text_before(self.rows[at - 1].cells[col], held.cells[col])
    }
    while at > 0 && go {
      self.rows[at] = self.rows[at - 1]
      at = at - 1
      if at > 0 {
        go = text_before(held.cells[col], self.rows[at - 1].cells[col])
        if reverse {
          go = text_before(self.rows[at - 1].cells[col], held.cells[col])
        }
      }
    }
    self.rows[at] = held
  }
  self.hover_row = -1
  self.hover_col = -1
}

///|
pub fn DataTable::cursor_row(self : DataTable) -> Int32 {
  self.cursor_row
}

///|
pub fn DataTable::cursor_col(self : DataTable) -> Int32 {
  self.cursor_col
}

///|
pub fn DataTable::move_cursor(
  self : DataTable,
  row~ : Int32,
  col~ : Int32,
) -> Unit {
  let rows = self.rows.length()
  if rows > 0 {
    if row > rows - 1 {
      self.cursor_row = rows - 1
    } else if row < 0 {
      self.cursor_row = 0
    } else {
      self.cursor_row = row
    }
  }
  let cols = self.columns.length()
  if cols > 0 {
    if col > cols - 1 {
      self.cursor_col = cols - 1
    } else if col < 0 {
      self.cursor_col = 0
    } else {
      self.cursor_col = col
    }
  }
  self.hover_row = -1
  self.hover_col = -1
}

///|
fn DataTable::labels_shown(self : DataTable) -> Bool {
  if !self.show_row_labels {
    return false
  }
  let mut found = false
  for row in self.rows {
    if row.label != "" {
      found = true
    }
  }
  found
}

///|
fn DataTable::label_width(self : DataTable) -> Int32 {
  if !self.show_row_labels {
    return 0
  }
  let mut widest = 0
  for row in self.rows {
    let cells = @strip.str_cells(row.label)
    if cells > widest {
      widest = cells
    }
  }
  widest
}

///|
pub fn DataTable::column_width(self : DataTable, col : Int32) -> Int32 {
  if col < 0 || col >= self.columns.length() {
    return 0
  }
  let column = self.columns[col]
  if column.width > 0 {
    return column.width
  }
  let mut widest = @strip.str_cells(column.label)
  for row in self.rows {
    if col < row.cells.length() {
      let cells = @strip.str_cells(row.cells[col])
      if cells > widest {
        widest = cells
      }
    }
  }
  if widest < 1 {
    return 1
  }
  widest
}

///|
pub fn DataTable::content_width(self : DataTable) -> Int32 {
  let mut total = self.label_width()
  if self.labels_shown() {
    total = total + 2 * self.cell_padding
  }
  let count = self.columns.length()
  for i in 0..<count {
    total = total + self.column_width(i) + 2 * self.cell_padding
  }
  total
}

///|
pub fn DataTable::line_count(self : DataTable) -> Int32 {
  self.rows.length() + (if self.show_header { 1 } else { 0 })
}

///|
fn DataTable::cell_hits(
  self : DataTable,
  row : Int32,
  col : Int32,
  target_row : Int32,
  target_col : Int32,
) -> Bool {
  match self.cursor_type {
    Cell => target_row == row && target_col == col
    Row => target_row == row
    Column => target_col == col
    None => false
  }
}

///|
fn DataTable::cell_style(
  self : DataTable,
  row : Int32,
  col : Int32,
  base : @style.Style,
) -> @style.Style {
  if self.show_cursor &&
    self.cell_hits(row, col, self.cursor_row, self.cursor_col) {
    return self.cursor_style.merge(base)
  }
  if self.hover_row >= 0 &&
    self.cell_hits(row, col, self.hover_row, self.hover_col) {
    return self.hover_style.merge(base)
  }
  base
}

///|
fn DataTable::row_base(self : DataTable, row : Int32) -> @style.Style {
  if self.zebra && row % 2 == 1 {
    return self.odd_style.merge(self.style)
  }
  if self.zebra {
    return self.even_style.merge(self.style)
  }
  self.style
}

///|
fn DataTable::cell_strip(
  self : DataTable,
  text : String,
  width : Int32,
  align : Align,
  cell_style : @style.Style,
) -> @strip.Strip {
  let pad = @strip.Strip::blank(self.cell_padding, cell_style)
  let body = align_line(text, width, align, cell_style)
  @strip.Strip::join([pad, body, pad])
}

///|
fn DataTable::col_at(self : DataTable, x : Int32) -> Int32 {
  let labels = self.label_width()
  if self.labels_shown() && x < labels + 2 * self.cell_padding {
    return -1
  }
  let mut at = if self.labels_shown() {
    x - labels - 2 * self.cell_padding
  } else {
    x
  }
  at = at + self.offset_x
  let count = self.columns.length()
  for i in 0..<count {
    let span = self.column_width(i) + 2 * self.cell_padding
    if at < span {
      return i
    }
    at = at - span
  }
  count - 1
}

///|
fn DataTable::row_at(self : DataTable, y : Int32) -> Int32 {
  let top = if self.show_header { 1 } else { 0 }
  if y < top {
    return -1
  }
  y - top + self.offset_y
}

///|
pub impl Widget for DataTable with fn render_line(self, row, size) {
  self.seen = size.height
  if row < 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let top = if self.show_header { 1 } else { 0 }
  if self.show_header && row == 0 {
    let pieces : Array[@strip.Strip] = []
    if self.labels_shown() {
      pieces.push(
        @strip.Strip::blank(
          self.label_width() + 2 * self.cell_padding,
          self.header_style,
        ),
      )
    }
    let count = self.columns.length()
    for i in 0..<count {
      let style = if self.cursor_type == Column &&
        self.show_cursor &&
        i == self.cursor_col {
        self.cursor_style.merge(self.header_style)
      } else {
        self.header_style
      }
      pieces.push(
        self.cell_strip(
          self.columns[i].label,
          self.column_width(i),
          self.columns[i].align,
          style,
        ),
      )
    }
    let line = @strip.Strip::join(pieces)
    return line
      .crop(self.offset_x, self.offset_x + size.width)
      .pad_to(size.width, self.header_style)
  }
  let data = row - top + self.offset_y
  if data < 0 || data >= self.rows.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let row_data = self.rows[data]
  let base = self.row_base(data)
  let pieces : Array[@strip.Strip] = []
  if self.labels_shown() {
    pieces.push(
      @strip.Strip::join([
        @strip.Strip::blank(self.cell_padding, self.label_style),
        align_line(row_data.label, self.label_width(), Left, self.label_style),
        @strip.Strip::blank(self.cell_padding, self.label_style),
      ]),
    )
  }
  let count = self.columns.length()
  for i in 0..<count {
    let text = if i < row_data.cells.length() { row_data.cells[i] } else { "" }
    pieces.push(
      self.cell_strip(
        text,
        self.column_width(i),
        self.columns[i].align,
        self.cell_style(data, i, base),
      ),
    )
  }
  let line = @strip.Strip::join(pieces)
  line.crop(self.offset_x, self.offset_x + size.width).pad_to(size.width, base)
}

///|
pub impl Widget for DataTable with fn hint(self, _size) {
  @geom.Size::new(self.content_width(), self.line_count())
}

///|
pub impl Widget for DataTable with fn focusable(_self) {
  true
}

///|
fn DataTable::emit_highlight(self : DataTable, ctx : Ctx) -> Unit {
  if self.rows.length() == 0 {
    return
  }
  match self.cursor_type {
    Cell =>
      ctx.emit(
        CellHighlighted(id=ctx.id, row=self.cursor_row, col=self.cursor_col),
      )
    Row => ctx.emit(Highlighted(id=ctx.id, index=self.cursor_row))
    Column => ctx.emit(Highlighted(id=ctx.id, index=self.cursor_col))
    None => ()
  }
}

///|
fn DataTable::emit_selected(self : DataTable, ctx : Ctx) -> Unit {
  if self.rows.length() == 0 {
    return
  }
  match self.cursor_type {
    Cell =>
      ctx.emit(
        CellSelected(id=ctx.id, row=self.cursor_row, col=self.cursor_col),
      )
    Row => ctx.emit(Selected(id=ctx.id, index=self.cursor_row))
    Column => ctx.emit(Selected(id=ctx.id, index=self.cursor_col))
    None => ()
  }
}

///|
fn DataTable::step_cursor(
  self : DataTable,
  ctx : Ctx,
  row : Int32,
  col : Int32,
) -> Unit {
  let rows = self.rows.length()
  let cols = self.columns.length()
  if rows == 0 || cols == 0 {
    return
  }
  let mut moved = false
  if row != 0 && self.cursor_type != Column {
    let next = self.cursor_row + row
    if next < 0 {
      self.cursor_row = 0
    } else if next > rows - 1 {
      self.cursor_row = rows - 1
    } else {
      self.cursor_row = next
    }
    moved = true
  }
  if col != 0 && self.cursor_type != Row {
    let next = self.cursor_col + col
    if next < 0 {
      self.cursor_col = 0
    } else if next > cols - 1 {
      self.cursor_col = cols - 1
    } else {
      self.cursor_col = next
    }
    moved = true
  }
  if moved {
    self.hover_row = -1
    self.hover_col = -1
    self.emit_highlight(ctx)
    self.keep_visible(size=ctx.size)
    ctx.repaint()
  }
}

///|
fn DataTable::keep_visible(self : DataTable, size~ : @geom.Size) -> Unit {
  self.seen = size.height
  let top = if self.show_header { 1 } else { 0 }
  let view = size.height - top
  if view > 0 {
    if self.cursor_row < self.offset_y {
      self.offset_y = self.cursor_row
    }
    if self.cursor_row > self.offset_y + view - 1 {
      self.offset_y = self.cursor_row - view + 1
    }
    if self.offset_y < 0 {
      self.offset_y = 0
    }
  }
  if self.cursor_type == Row || self.cursor_type == None {
    return
  }
  let mut before = if self.show_row_labels {
    self.label_width() + 2 * self.cell_padding
  } else {
    0
  }
  let mut at = 0
  while at < self.cursor_col {
    before = before + self.column_width(at) + 2 * self.cell_padding
    at = at + 1
  }
  let cell_end = before +
    self.column_width(self.cursor_col) +
    2 * self.cell_padding
  if before < self.offset_x {
    self.offset_x = before
  }
  if cell_end > self.offset_x + size.width {
    self.offset_x = cell_end - size.width
  }
  if self.offset_x < 0 {
    self.offset_x = 0
  }
}

///|
fn DataTable::shift_x(
  self : DataTable,
  ctx : Ctx,
  size~ : @geom.Size,
  by~ : Int32,
) -> Unit {
  let span = self.content_width() - size.width
  if span <= 0 {
    return
  }
  let mut next = self.offset_x + by
  if next > span {
    next = span
  }
  if next < 0 {
    next = 0
  }
  if next != self.offset_x {
    self.offset_x = next
    ctx.repaint()
  }
}

///|
fn DataTable::page_step(self : DataTable) -> Int32 {
  let top = if self.show_header { 1 } else { 0 }
  let view = self.seen - top
  if view > 1 {
    view - 1
  } else {
    1
  }
}

///|
fn DataTable::scroll_by(self : DataTable, ctx : Ctx, lines : Int32) -> Unit {
  let top = if self.show_header { 1 } else { 0 }
  let view = self.seen - top
  let total = self.rows.length()
  if view <= 0 {
    return
  }
  let mut next = self.offset_y + lines
  if next > total - view {
    next = total - view
  }
  if next < 0 {
    next = 0
  }
  if next != self.offset_y {
    self.offset_y = next
    ctx.emit(Scrolled(id=ctx.id, x=self.offset_x, y=self.offset_y))
    ctx.repaint()
  }
}

///|
pub impl Widget for DataTable with fn handle(self, ctx, msg) {
  match msg {
    Focus(on) => {
      self.focused = on
      if on {
        ctx.emit(TakeFocus(id=ctx.id))
      }
      ctx.repaint()
      false
    }
    Key(k) =>
      match k.code {
        Enter => {
          self.emit_selected(ctx)
          true
        }
        Up =>
          match self.cursor_type {
            Column => {
              self.scroll_by(ctx, -1)
              true
            }
            _ => {
              self.step_cursor(ctx, -1, 0)
              true
            }
          }
        Down =>
          match self.cursor_type {
            Column => {
              self.scroll_by(ctx, 1)
              true
            }
            _ => {
              self.step_cursor(ctx, 1, 0)
              true
            }
          }
        Left =>
          match self.cursor_type {
            Row => {
              self.shift_x(ctx, size=ctx.size, by=-1)
              true
            }
            _ => {
              self.step_cursor(ctx, 0, -1)
              true
            }
          }
        Right =>
          match self.cursor_type {
            Row => {
              self.shift_x(ctx, size=ctx.size, by=1)
              true
            }
            _ => {
              self.step_cursor(ctx, 0, 1)
              true
            }
          }
        PageUp => {
          self.step_cursor(ctx, -self.page_step(), 0)
          true
        }
        PageDown => {
          self.step_cursor(ctx, self.page_step(), 0)
          true
        }
        Home => {
          if k.mods.ctrl {
            self.cursor_row = 0
            self.offset_y = 0
            ctx.repaint()
          } else {
            self.cursor_col = 0
            self.offset_x = 0
            ctx.repaint()
          }
          true
        }
        End => {
          let cols = self.columns.length()
          let rows = self.rows.length()
          if k.mods.ctrl {
            if rows > 0 {
              self.cursor_row = rows - 1
              self.keep_visible(size=ctx.size)
              ctx.repaint()
            }
          } else if cols > 0 {
            self.cursor_col = cols - 1
            self.keep_visible(size=ctx.size)
            ctx.repaint()
          }
          true
        }
        _ => false
      }
    Mouse(m) =>
      match m.kind {
        Move => {
          let row = self.row_at(m.y)
          let col = self.col_at(m.x)
          if row != self.hover_row || col != self.hover_col {
            self.hover_row = row
            self.hover_col = col
            if row >= 0 && self.cursor_type != None {
              match self.cursor_type {
                Cell => ctx.emit(CellHighlighted(id=ctx.id, row~, col~))
                Row => ctx.emit(Highlighted(id=ctx.id, index=row))
                Column => ctx.emit(Highlighted(id=ctx.id, index=col))
                None => ()
              }
            }
            ctx.repaint()
          }
          true
        }
        Down => {
          let row = self.row_at(m.y)
          let col = self.col_at(m.x)
          if row == -1 && self.show_header && col >= 0 {
            ctx.emit(HeaderSelected(id=ctx.id, col~))
            return true
          }
          if col == -1 && row >= 0 {
            ctx.emit(Selected(id=ctx.id, index=row))
            return true
          }
          if row < 0 || col < 0 {
            return true
          }
          if !self.show_cursor || self.cursor_type == None {
            return true
          }
          let same = row == self.cursor_row && col == self.cursor_col
          self.cursor_row = row
          self.cursor_col = col
          self.hover_row = -1
          self.hover_col = -1
          if same {
            self.emit_selected(ctx)
          } else {
            self.emit_highlight(ctx)
            self.keep_visible(size=ctx.size)
            ctx.repaint()
          }
          true
        }
        ScrollUp => {
          self.scroll_by(ctx, -self.page_step())
          true
        }
        ScrollDown => {
          self.scroll_by(ctx, self.page_step())
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub extend DataTable with Widget::{focusable, handle, hint, render_line}
