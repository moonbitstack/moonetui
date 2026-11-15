// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One page of one table: the columns the server named, the rows it returned,
/// and the columns that identify a row, which the catalog supplied. Empty
/// `keys` means the table has no primary key, and a save matches a whole row
/// instead of a key.
pub(all) struct Page {
  schema : String?
  table : String
  columns : Array[String]
  rows : Array[Array[Cell]]
  keys : Array[String]
}

///|
pub fn Page::new(
  schema : String?,
  table : String,
  columns : Array[String],
  rows : Array[Array[Cell]],
  keys : Array[String],
) -> Page {
  { schema, table, columns, rows, keys, }
}

///|
/// A table as the reader has it: the page the server sent, and what the
/// reader did to it since — the filter, the ordering, the page it is on, the
/// columns they hid, the cells they changed, the rows they added and marked
/// for deletion. Nothing here talks to a database, so all of it is testable
/// without one.
pub(all) struct Grid {
  mut page : Page
  mut filter : String
  mut sorts : Array[@sqlkit.SortKey]
  mut limit : Int32
  mut offset : Int64
  mut total : Int64?
  mut hidden : Array[String]
  mut transposed : Bool
  mut cursor_row : Int32
  mut cursor_col : Int32
  mut changes : Map[String, Cell]
  mut added : Array[Array[Cell]]
  mut deleted : Array[Int32]
  mut message : String
}

///|
pub fn Grid::new(page : Page) -> Grid {
  {
    page,
    filter: "",
    sorts: [],
    limit: 100,
    offset: 0,
    total: None,
    hidden: [],
    transposed: false,
    cursor_row: 0,
    cursor_col: 0,
    changes: Map([]),
    added: [],
    deleted: [],
    message: "",
  }
}

///|
/// The columns on screen, in the table's own order.
pub fn Grid::visible(self : Grid) -> Array[String] {
  let out : Array[String] = []
  for column in self.page.columns {
    if !self.hidden.contains(column) {
      out.push(column)
    }
  }
  out
}

///|
/// Where a column sits among the visible ones, or `None` when it is hidden.
pub fn Grid::visible_index(self : Grid, column : String) -> Int32? {
  let columns = self.visible()
  let mut i = 0
  while i < columns.length() {
    if columns[i] == column {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// A cell as it stands now: the reader's change if there is one, the added
/// row's value, the server's value otherwise.
pub fn Grid::cell(self : Grid, row : Int32, column : String) -> Cell {
  match self.changes.get(change_key(row, column)) {
    Some(cell) => cell
    None => self.original(row, column)
  }
}

///|
/// The cell the server sent, before any of the reader's changes.
pub fn Grid::original(self : Grid, row : Int32, column : String) -> Cell {
  if row >= self.page.rows.length() {
    let added = row - self.page.rows.length()
    if added < self.added.length() {
      match self.index_of(column) {
        Some(i) =>
          if i < self.added[added].length() {
            self.added[added][i]
          } else {
            Cell::none()
          }
        None => Cell::none()
      }
    } else {
      Cell::none()
    }
  } else {
    match self.index_of(column) {
      Some(i) => self.page.rows[row][i]
      None => Cell::none()
    }
  }
}

///|
fn Grid::index_of(self : Grid, column : String) -> Int32? {
  let mut i = 0
  while i < self.page.columns.length() {
    if self.page.columns[i] == column {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Every row on screen: the page, then the rows added below it.
pub fn Grid::row_count(self : Grid) -> Int32 {
  self.page.rows.length() + self.added.length()
}

///|
/// A change is recorded against the row's position and the column's name, so
/// hiding a column does not lose it and sorting the view does not move it.
fn change_key(row : Int32, column : String) -> String {
  row.to_string() + "\u{0}" + column
}

///|
/// Change one cell. Setting a cell back to what it was drops the change, so a
/// table that was looked at and left alone is not dirty.
pub fn Grid::set_cell(
  self : Grid,
  row : Int32,
  column : String,
  cell : Cell,
) -> Unit {
  let was = self.original(row, column)
  if was.text == cell.text && was.is_null == cell.is_null {
    self.changes.remove(change_key(row, column))
  } else {
    self.changes[change_key(row, column)] = cell
  }
}

///|
pub fn Grid::is_dirty(self : Grid) -> Bool {
  self.changes.length() > 0 ||
  self.added.length() > 0 ||
  self.deleted.length() > 0
}

///|
/// How many cells the reader changed.
pub fn Grid::changed_cells(self : Grid) -> Int32 {
  self.changes.length()
}

///|
/// The rows with at least one changed cell, in the order they appear.
pub fn Grid::changed_rows(self : Grid) -> Array[Int32] {
  let rows : Array[Int32] = []
  for row in 0..<self.row_count() {
    let mut touched = false
    for column in self.page.columns {
      if self.changes.contains(change_key(row, column)) {
        touched = true
      }
    }
    if touched {
      rows.push(row)
    }
  }
  rows
}

///|
/// A row added at the bottom, every column NULL. The reader fills what the
/// table needs; a column with a default may stay NULL.
pub fn Grid::add_row(self : Grid) -> Int32 {
  let row : Array[Cell] = []
  for _ in self.page.columns {
    row.push(Cell::none())
  }
  self.added.push(row)
  let at = self.row_count() - 1
  self.cursor_row = at
  at
}

///|
/// Mark a row for deletion, or take the mark back. An added row that has not
/// been saved is dropped outright, since the database never saw it.
pub fn Grid::toggle_delete(self : Grid, row : Int32) -> Unit {
  if self.deleted.contains(row) {
    self.deleted = self.deleted.filter(fn(r) { r != row })
    return
  }
  if row >= self.page.rows.length() {
    let added = row - self.page.rows.length()
    if added < self.added.length() {
      ignore(self.added.remove(added))
      if self.cursor_row >= self.row_count() && self.cursor_row > 0 {
        self.cursor_row = self.row_count() - 1
      }
      return
    }
  }
  self.deleted.push(row)
}

///|
pub fn Grid::is_marked(self : Grid, row : Int32) -> Bool {
  self.deleted.contains(row)
}

///|
/// Take every change back, keeping the page, the filter and the ordering.
pub fn Grid::revert(self : Grid) -> Unit {
  self.changes = Map([])
  self.added = []
  self.deleted = []
}

///|
/// Move the cursor, clamped to what is on screen.
pub fn Grid::step(self : Grid, down : Int32, right : Int32) -> Unit {
  let rows = self.row_count()
  let cols = self.visible().length()
  if rows > 0 {
    self.cursor_row = clamp(self.cursor_row + down, 0, rows - 1)
  }
  if cols > 0 {
    self.cursor_col = clamp(self.cursor_col + right, 0, cols - 1)
  }
}

///|
fn clamp(value : Int32, low : Int32, high : Int32) -> Int32 {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
/// The column the cursor is on.
pub fn Grid::cursor_column(self : Grid) -> String? {
  let columns = self.visible()
  if self.cursor_col < columns.length() {
    Some(columns[self.cursor_col])
  } else {
    None
  }
}

///|
/// Sort this way, the other way, or not at all: one column is pressed through
/// its three states, and the others keep the order they were given in.
pub fn Grid::press_column(self : Grid, column : String) -> Unit {
  let out : Array[@sqlkit.SortKey] = []
  let mut found = false
  for key in self.sorts {
    if key.column == column {
      found = true
      if key.descending {
        // third press: off
      } else {
        out.push({ column, descending: true, })
      }
    } else {
      out.push(key)
    }
  }
  if !found {
    out.push({ column, descending: false, })
  }
  self.sorts = out
  self.offset = 0
}

///|
/// What the header shows: `▲`, `▼`, or nothing.
pub fn Grid::sort_mark(self : Grid, column : String) -> String {
  for key in self.sorts {
    if key.column == column {
      return if key.descending { "▼" } else { "▲" }
    }
  }
  ""
}

///|
/// The next page, or the previous one. `true` means the caller has to load
/// again; a page that would start before the first row is refused.
pub fn Grid::turn_page(self : Grid, forward : Bool) -> Bool {
  if forward {
    self.offset = self.offset + self.limit.to_int64()
    true
  } else if self.offset == 0 {
    false
  } else {
    let step = self.limit.to_int64()
    self.offset = if self.offset > step { self.offset - step } else { 0 }
    true
  }
}

///|
/// The rows on this page, one-based, for the status line: `1-100 of 2400`.
pub fn Grid::range_text(self : Grid) -> String {
  let first = self.offset + 1
  let last = self.offset + self.page.rows.length().to_int64()
  match self.total {
    Some(total) =>
      if total == 0 {
        "0 rows"
      } else {
        first.to_string() + "-" + last.to_string() + " of " + total.to_string()
      }
    None => first.to_string() + "-" + last.to_string()
  }
}

///|
/// What a filter by a cell's value asks for. The value is quoted as a string
/// literal, which every engine coerces to the column's own type.
pub fn Grid::filter_for_cell(self : Grid, dialect : @sqlkit.Dialect) -> String? {
  match self.cursor_column() {
    None => None
    Some(column) => {
      let cell = self.cell(self.cursor_row, column)
      match cell.value() {
        None => Some(dialect.quote(column) + " IS NULL")
        Some(text) =>
          Some(dialect.quote(column) + " = " + dialect.literal(text))
      }
    }
  }
}

///|
/// Every row on this page that is not marked for deletion, cells and all, for
/// an export to write.
pub fn Grid::export_rows(self : Grid) -> Array[Array[Cell]] {
  let out : Array[Array[Cell]] = []
  for row in 0..<self.row_count() {
    if self.is_marked(row) {
      continue
    }
    let line : Array[Cell] = []
    for column in self.visible() {
      line.push(self.cell(row, column))
    }
    out.push(line)
  }
  out
}

///|
/// The rows as text, the way a CSV export writes them: visible columns only,
/// NULL as the empty string.
pub fn Grid::text_rows(self : Grid) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for row in 0..<self.row_count() {
    if self.is_marked(row) {
      continue
    }
    let line : Array[String] = []
    for column in self.visible() {
      let cell = self.cell(row, column)
      line.push(if cell.is_null { "" } else { cell.text })
    }
    out.push(line)
  }
  out
}
