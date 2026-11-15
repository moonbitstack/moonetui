// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What has the keyboard.
#derive(Eq, Debug)
pub(all) enum Focus {
  Tree
  Grid
  Editor
}

///|
pub extend Focus with Eq::{equal, not_equal}

///|
pub extend Focus with Debug::{to_repr}

///|
/// A dialog is a mode: while one is open the keys answer it, not the pane
/// behind it.
#derive(Eq, Debug)
pub(all) enum Mode {
  Browse
  Palette
  Help
  Confirm
  Preview
  Typing
}

///|
pub extend Mode with Eq::{equal, not_equal}

///|
pub extend Mode with Debug::{to_repr}

///|
/// What the state asks the host to do. The state never touches a database:
/// the host runs these and hands the answers back, which is what makes every
/// key reachable in a test.
pub(all) enum Command {
  OpenTable(schema~ : String?, table~ : String)
  Reload
  RunQuery(text~ : String)
  Save(statements~ : Array[String], expected~ : Array[Int64])
  ExportCsv(path~ : String)
  ExportJson(path~ : String)
  Quit
}

///|
/// A table tab: the grid it shows and the name on it.
pub(all) struct Tab {
  schema : String?
  table : String
  grid : @table.Grid
}

///|
/// Everything the screen shows and every key does.
pub(all) struct State {
  connection : String
  engine : @config.Engine
  dialect : @sqlkit.Dialect
  read_only : Bool
  production : Bool
  mut schemas : Array[String]
  mut tables : Array[@db.TableInfo]
  mut tree_at : Int32
  mut tabs : Array[Tab]
  mut tab : Int32
  mut focus : Focus
  mut mode : Mode
  mut message : String
  mut editor : String
  mut result : @db.Result?
  mut confirm : String
  mut preview : String
  mut prompt : String
  mut draft : String
  mut palette_query : String
  mut palette_pick : Int32
  mut filter : String
  mut vim : Bool
  mut pending : Array[String]
  mut pending_rows : Array[Int64]
  keymap : @keymap.Keymap
}

///|
pub fn State::new(
  connection : String,
  engine : @config.Engine,
  dialect : @sqlkit.Dialect,
  read_only : Bool,
  production : Bool,
  keymap : @keymap.Keymap,
) -> State {
  {
    connection,
    engine,
    dialect,
    read_only,
    production,
    schemas: [],
    tables: [],
    tree_at: 0,
    tabs: [],
    tab: 0,
    focus: Tree,
    mode: Browse,
    message: "",
    editor: "",
    result: None,
    confirm: "",
    preview: "",
    prompt: "",
    draft: "",
    palette_query: "",
    palette_pick: 0,
    filter: "",
    vim: true,
    pending: [],
    pending_rows: [],
    keymap,
  }
}

///|
pub fn State::tab_of(self : State) -> Tab? {
  if self.tab < self.tabs.length() {
    Some(self.tabs[self.tab])
  } else {
    None
  }
}

///|
pub fn State::current(self : State) -> @table.Grid? {
  match self.tab_of() {
    Some(tab) => Some(tab.grid)
    None => None
  }
}

///|
/// The grid on screen, or a fresh empty one so a key on no tab does nothing.
pub fn State::grid(self : State) -> @table.Grid? {
  self.current()
}

///|
/// Put a page into the tab that asked for it, or open the tab when it is new.
pub fn State::show_page(self : State, page : @table.Page) -> Unit {
  let mut found = -1
  let mut i = 0
  while i < self.tabs.length() {
    let tab = self.tabs[i]
    if tab.table == page.table && tab.schema == page.schema {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    let tab = self.tabs[found]
    tab.grid.page = page
    tab.grid.changes = Map([])
    tab.grid.added = []
    tab.grid.deleted = []
    self.tab = found
  } else {
    let grid = @table.Grid::new(page)
    self.tabs.push({ schema: page.schema, table: tab_label(page), grid, })
    self.tab = self.tabs.length() - 1
  }
  self.focus = Grid
}

///|
/// The name the tab is labelled with.
fn tab_label(page : @table.Page) -> String {
  match page.schema {
    Some(s) => s + "." + page.table
    None => page.table
  }
}

///|
pub fn State::close_tab(self : State) -> Unit {
  if self.tabs.length() > 0 {
    ignore(self.tabs.remove(self.tab))
    if self.tab >= self.tabs.length() && self.tab > 0 {
      self.tab = self.tabs.length() - 1
    }
    if self.tabs.length() == 0 {
      self.focus = Tree
    }
  }
}

///|
/// The catalog arrived: the tree is rebuilt from it.
pub fn State::set_catalog(
  self : State,
  schemas : Array[String],
  tables : Array[@db.TableInfo],
) -> Unit {
  self.schemas = schemas
  self.tables = tables
  self.tree_at = 0
}

///|
pub fn State::tree_row(self : State) -> @db.TableInfo? {
  if self.tree_at < self.tables.length() {
    Some(self.tables[self.tree_at])
  } else {
    None
  }
}

///|
/// The sentence a read-only connection answers a write with.
pub fn State::refusal(self : State, sql : String) -> String? {
  if self.read_only && @sqlkit.writes(sql, self.dialect) {
    Some("this connection is read-only")
  } else {
    None
  }
}

///|
/// The connection's mark in the header: production first, then read-only.
pub fn State::badge(self : State) -> String {
  if self.production {
    "PRODUCTION"
  } else if self.read_only {
    "read-only"
  } else {
    ""
  }
}

///|
/// The status line: what just happened, or where the reader is.
pub fn State::status(self : State) -> String {
  if self.message != "" {
    return self.message
  }
  match self.grid() {
    None =>
      self.connection + " · " + self.tables.length().to_string() + " tables"
    Some(grid) => {
      let dirty = if grid.is_dirty() { " · unsaved changes" } else { "" }
      grid.range_text() +
      " · " +
      grid.visible().length().to_string() +
      " columns" +
      dirty
    }
  }
}
