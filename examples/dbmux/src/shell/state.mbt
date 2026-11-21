// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The name of the table that lists a Redis server's keys.
pub let keys_table : String = "keys"

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
/// A pane holds tabs, and one of them is the one showing. A window has one
/// pane until it is split, and then two.
pub(all) struct Pane {
  mut tabs : Array[Tab]
  mut tab : Int32
}

///|
pub fn Pane::new() -> Pane {
  { tabs: [], tab: 0, }
}

///|
pub fn Pane::current(self : Pane) -> Tab? {
  if self.tab < self.tabs.length() {
    Some(self.tabs[self.tab])
  } else {
    None
  }
}

///|
/// How the main area is divided. `Single` is one pane; the two splits put a
/// second pane beside or below the first.
#derive(Eq, Debug)
pub(all) enum Layout {
  Single
  SplitVertical
  SplitHorizontal
}

///|
pub extend Layout with Eq::{equal, not_equal}

///|
pub extend Layout with Debug::{to_repr}

///|
/// Everything the screen shows and every key does.
pub(all) struct State {
  connection : String
  engine : @config.Engine
  dialect : @sqlkit.Dialect
  read_only : Bool
  production : Bool
  history : History
  mut schemas : Array[String]
  mut tables : Array[@db.TableInfo]
  mut tree_at : Int32
  mut panes : Array[Pane]
  mut pane : Int32
  mut layout : Layout
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
    history: History::new(),
    schemas: [],
    tables: [],
    tree_at: 0,
    panes: [Pane::new()],
    pane: 0,
    layout: Single,
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
/// The pane the keys go to.
pub fn State::active(self : State) -> Pane {
  if self.pane < self.panes.length() {
    self.panes[self.pane]
  } else {
    self.panes[0]
  }
}

///|
/// The tabs of one pane, for drawing both halves of a split.
pub fn State::pane_of(self : State, index : Int32) -> Pane? {
  if index < self.panes.length() {
    Some(self.panes[index])
  } else {
    None
  }
}

///|
pub fn State::tab_of(self : State) -> Tab? {
  self.active().current()
}

///|
/// The grid of one pane, or of the pane with the keyboard.
pub fn State::grid_of(self : State, index : Int32) -> @table.Grid? {
  match self.pane_of(index) {
    None => None
    Some(pane) =>
      match pane.current() {
        Some(tab) => Some(tab.grid)
        None => None
      }
  }
}

///|
/// The grid on screen.
pub fn State::grid(self : State) -> @table.Grid? {
  self.grid_of(self.pane)
}

///|
/// Whether the pane shows a Redis server's keys, which are narrowed by a
/// pattern Redis matches rather than by a WHERE.
pub fn State::keys_page(self : State) -> Bool {
  if !(self.engine is @config.Engine::Redis) {
    return false
  }
  match self.grid() {
    Some(grid) => grid.page.table == keys_table
    None => false
  }
}

///|
/// Put a page into the tab that asked for it, or open the tab when it is new.
/// A split shows the same table in both panes until one of them opens another.
pub fn State::show_page(self : State, page : @table.Page) -> Unit {
  let pane = self.active()
  let mut found = -1
  let mut i = 0
  while i < pane.tabs.length() {
    let tab = pane.tabs[i]
    if tab.table == page.table && tab.schema == page.schema {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    let tab = pane.tabs[found]
    tab.grid.page = page
    tab.grid.changes = Map([])
    tab.grid.added = []
    tab.grid.deleted = []
    pane.tab = found
  } else {
    let grid = @table.Grid::new(page)
    pane.tabs.push({ schema: page.schema, table: tab_label(page), grid, })
    pane.tab = pane.tabs.length() - 1
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
  let pane = self.active()
  if pane.tabs.length() > 0 {
    ignore(pane.tabs.remove(pane.tab))
    if pane.tab >= pane.tabs.length() && pane.tab > 0 {
      pane.tab = pane.tabs.length() - 1
    }
    if pane.tabs.length() == 0 {
      self.focus = Tree
    }
  }
}

///|
pub fn State::next_tab(self : State) -> Unit {
  let pane = self.active()
  if pane.tabs.length() > 0 {
    pane.tab = (pane.tab + 1) % pane.tabs.length()
  }
}

///|
pub fn State::prev_tab(self : State) -> Unit {
  let pane = self.active()
  if pane.tabs.length() > 0 {
    pane.tab = (pane.tab + pane.tabs.length() - 1) % pane.tabs.length()
  }
}

///|
/// Split the main area, with the table that is showing on both sides. A
/// second split turns the divider: from side by side to one above the other.
pub fn State::split(self : State, layout : Layout) -> Unit {
  if self.layout == layout && self.panes.length() > 1 {
    return
  }
  if self.panes.length() == 1 {
    let second = Pane::new()
    match self.active().current() {
      Some(tab) => {
        let copy = @table.Grid::new(tab.grid.page)
        copy.filter = tab.grid.filter
        copy.sorts = tab.grid.sorts
        copy.limit = tab.grid.limit
        copy.offset = tab.grid.offset
        copy.total = tab.grid.total
        second.tabs.push({ schema: tab.schema, table: tab.table, grid: copy, })
      }
      None => ()
    }
    self.panes.push(second)
  }
  self.layout = layout
}

///|
/// Close the split, keeping the pane that had the keyboard and its tabs.
pub fn State::unsplit(self : State) -> Unit {
  if self.panes.length() > 1 {
    let keep = self.pane
    let kept = self.panes[keep]
    self.panes = [kept]
    self.pane = 0
  }
  self.layout = Single
}

///|
/// Hand the keyboard to the other pane.
pub fn State::other_pane(self : State) -> Unit {
  if self.panes.length() > 1 {
    self.pane = (self.pane + 1) % self.panes.length()
  }
}

///|
/// The label of each pane for the tab strip: the tab it shows, or nothing.
pub fn State::pane_label(self : State, index : Int32) -> String {
  match self.grid_of(index) {
    Some(grid) =>
      match grid.page.schema {
        Some(s) => s + "." + grid.page.table
        None => grid.page.table
      }
    None => "(empty)"
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
  // Redis has no SQL to read: its commands are checked where they run.
  if self.engine is @config.Engine::Redis {
    return None
  }
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
  let where_ = match self.layout {
    Single => ""
    SplitVertical => " · 2 panes ⇔"
    SplitHorizontal => " · 2 panes ⇕"
  }
  match self.grid() {
    None =>
      self.connection +
      " · " +
      self.tables.length().to_string() +
      " tables" +
      where_
    Some(grid) => {
      let dirty = if grid.is_dirty() { " · unsaved changes" } else { "" }
      grid.range_text() +
      " · " +
      grid.visible().length().to_string() +
      " columns" +
      dirty +
      where_
    }
  }
}
