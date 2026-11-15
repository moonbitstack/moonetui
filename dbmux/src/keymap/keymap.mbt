// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Everything a key can be asked to do. The list is the command palette's
/// list too: one name per thing, in the order the help page groups them.
#derive(Eq, Debug)
pub(all) enum Action {
  Quit
  Help
  Palette
  FocusNext
  FocusLeft
  FocusRight
  Up
  Down
  Left
  Right
  PageNext
  PagePrev
  Sort
  Filter
  FilterCell
  ClearFilter
  EditCell
  AddRow
  DeleteRow
  Save
  Revert
  Transpose
  Columns
  ExportCsv
  ExportJson
  RunQuery
  CloseTab
  NextTab
  PrevTab
  Reload
  OpenTable
  SplitRight
  SplitDown
  OtherPane
  ClosePane
}

///|
pub extend Action with Eq::{equal, not_equal}

///|
pub extend Action with Debug::{to_repr}

///|
pub fn Action::name(self : Action) -> String {
  match self {
    Quit => "quit"
    Help => "help"
    Palette => "palette"
    FocusNext => "next pane"
    FocusLeft => "left pane"
    FocusRight => "right pane"
    Up => "up"
    Down => "down"
    Left => "left"
    Right => "right"
    PageNext => "next page"
    PagePrev => "previous page"
    Sort => "sort column"
    Filter => "filter"
    FilterCell => "filter by cell"
    ClearFilter => "clear filter"
    EditCell => "edit cell"
    AddRow => "add row"
    DeleteRow => "delete row"
    Save => "save"
    Revert => "revert"
    Transpose => "transpose"
    Columns => "columns"
    ExportCsv => "export CSV"
    ExportJson => "export JSON"
    RunQuery => "run query"
    CloseTab => "close tab"
    NextTab => "next tab"
    PrevTab => "previous tab"
    Reload => "reload"
    OpenTable => "open table"
    SplitRight => "split right"
    SplitDown => "split down"
    OtherPane => "other pane"
    ClosePane => "close split"
  }
}

///|
/// The action a keymap file names, by the same words the palette shows.
pub fn Action::parse(text : String) -> Action? {
  let word = text.to_lower().replace_all(old=" ", new="-")
  let table : Array[(String, Action)] = [
    ("quit", Quit),
    ("help", Help),
    ("palette", Palette),
    ("focus-next", FocusNext),
    ("focus-left", FocusLeft),
    ("focus-right", FocusRight),
    ("up", Up),
    ("down", Down),
    ("left", Left),
    ("right", Right),
    ("page-next", PageNext),
    ("page-prev", PagePrev),
    ("sort", Sort),
    ("filter", Filter),
    ("filter-by-cell", FilterCell),
    ("filter-cell", FilterCell),
    ("clear-filter", ClearFilter),
    ("edit-cell", EditCell),
    ("add-row", AddRow),
    ("delete-row", DeleteRow),
    ("save", Save),
    ("revert", Revert),
    ("transpose", Transpose),
    ("columns", Columns),
    ("export-csv", ExportCsv),
    ("export-json", ExportJson),
    ("run-query", RunQuery),
    ("close-tab", CloseTab),
    ("next-tab", NextTab),
    ("prev-tab", PrevTab),
    ("reload", Reload),
    ("open-table", OpenTable),
    ("split-right", SplitRight),
    ("split-down", SplitDown),
    ("other-pane", OtherPane),
    ("close-pane", ClosePane),
  ]
  let mut i = 0
  while i < table.length() {
    if table[i].0 == word {
      return Some(table[i].1)
    }
    i = i + 1
  }
  None
}

///|
/// A key as text: `j`, `C-s`, `S-tab`, `S-j` for a capital, `esc` for escape.
/// The same spelling the keymap file uses, so a rebound key is written the way
/// it is shown.
pub fn key_text(key : @event.Key) -> String {
  let name = match key.code {
    Char(c) => String::from_array([c.unsafe_to_char()])
    Enter => "enter"
    Tab => "tab"
    BackTab => "S-tab"
    Backspace => "backspace"
    Delete => "del"
    Escape => "esc"
    Insert => "insert"
    Up => "up"
    Down => "down"
    Left => "left"
    Right => "right"
    Home => "home"
    End => "end"
    PageUp => "pgup"
    PageDown => "pgdown"
    F(n) => "F" + n.to_string()
  }
  if key.mods.ctrl {
    "C-" + name
  } else if key.mods.alt {
    "A-" + name
  } else if key.mods.shift && name.length() > 1 {
    "S-" + name
  } else {
    name
  }
}

///|
/// The bindings: one key per action by default, and whatever a keymap file
/// says on top of that.
pub(all) struct Keymap {
  keys : Map[String, Action]
}

///|
/// The defaults. A letter does what its pane has for it; `Ctrl` is for the
/// things that reach across panes.
pub fn Keymap::default() -> Keymap {
  Keymap::new([
    ("q", Quit),
    ("?", Help),
    ("C-p", Palette),
    ("tab", FocusNext),
    ("C-h", FocusLeft),
    ("C-l", FocusRight),
    ("k", Up),
    ("j", Down),
    ("h", Left),
    ("l", Right),
    ("J", PageNext),
    ("K", PagePrev),
    ("s", Sort),
    ("f", Filter),
    ("F", FilterCell),
    ("C-f", ClearFilter),
    ("e", EditCell),
    ("a", AddRow),
    ("d", DeleteRow),
    ("C-s", Save),
    ("r", Revert),
    ("t", Transpose),
    ("c", Columns),
    ("x", ExportCsv),
    ("X", ExportJson),
    ("C-r", RunQuery),
    ("C-w", CloseTab),
    ("gt", NextTab),
    ("gT", PrevTab),
    ("R", Reload),
    ("enter", OpenTable),
    ("C-v", SplitRight),
    ("C-x", SplitDown),
    ("C-o", OtherPane),
    ("C-q", ClosePane),
  ])
}

///|
pub fn Keymap::new(bindings : Array[(String, Action)]) -> Keymap {
  let keys : Map[String, Action] = Map([])
  for (key, action) in bindings {
    keys[key] = action
  }
  let map : Map[String, Action] = keys
  Keymap::{ keys: map, }
}

///|
pub fn Keymap::action(self : Keymap, key : String) -> Action? {
  self.keys.get(key)
}

///|
/// Read `[keys]` from a TOML file: `save = "C-w"` rebinds save, and a key with
/// no action takes the binding away. A name the table does not know is said,
/// not ignored, because a typo in a keymap is invisible until a key does
/// nothing.
pub fn Keymap::over(
  self : Keymap,
  text : String,
) -> Keymap raise @config.Refused {
  let root : @json.Json = @moontoml.loads(text) catch {
    _ => raise @config.Refused(text="the keymap file is not TOML")
  }
  let section = if root is Object(map) {
    match map.get("keys") {
      Some(v) => Some(v)
      None => None
    }
  } else {
    None
  }
  match section {
    None => self
    Some(v) =>
      if v is Object(entries) {
        let keys : Map[String, Action] = Map([])
        for key, value in self.keys {
          keys[key] = value
        }
        for name, value in entries {
          let action = match Action::parse(name) {
            Some(a) => a
            None => raise @config.Refused(text="no action is called " + name)
          }
          if value is String(k) {
            // one action, one key: take the old key away first
            let stale : Array[String] = []
            for existing, bound in keys {
              if bound == action {
                stale.push(existing)
              }
            }
            for old in stale {
              keys.remove(old)
            }
            keys[k] = action
          }
        }
        let map : Map[String, Action] = keys
        Keymap::{ keys: map, }
      } else {
        self
      }
  }
}

///|
/// The bindings of one action, for the help page and the palette.
pub fn Keymap::keys_of(self : Keymap, action : Action) -> Array[String] {
  let out : Array[String] = []
  for key, bound in self.keys {
    if bound == action {
      out.push(key)
    }
  }
  out.sort()
  out
}

///|
/// Every binding as a `(key, action)` pair, sorted by key, for the help panel.
pub fn Keymap::rows(self : Keymap) -> Array[(String, String)] {
  let keys : Array[String] = []
  for key, _ in self.keys {
    keys.push(key)
  }
  keys.sort()
  let out : Array[(String, String)] = []
  for key in keys {
    out.push((key, self.keys[key].name()))
  }
  out
}
