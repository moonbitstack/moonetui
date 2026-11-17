// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A key on the prompt line: what it does to the draft.
pub fn State::type_key(self : State, key : String) -> Bool {
  if key == "esc" {
    self.mode = Browse
    self.draft = ""
    true
  } else if key == "enter" {
    self.mode = Browse
    true
  } else if key == "backspace" {
    if self.draft.length() > 0 {
      self.draft = self.draft.exact_view(end=self.draft.length() - 1).to_owned()
    }
    true
  } else if key.length() == 1 {
    self.draft = self.draft + key
    true
  } else {
    false
  }
}

///|
/// The palette's candidates: every action, then every table.
pub fn State::palette_items(self : State) -> Array[String] {
  let out : Array[String] = []
  let actions : Array[@keymap.Action] = [
    @keymap.Action::Quit,
    @keymap.Action::Help,
    @keymap.Action::Reload,
    @keymap.Action::Sort,
    @keymap.Action::Filter,
    @keymap.Action::FilterCell,
    @keymap.Action::ClearFilter,
    @keymap.Action::EditCell,
    @keymap.Action::AddRow,
    @keymap.Action::DeleteRow,
    @keymap.Action::Save,
    @keymap.Action::Revert,
    @keymap.Action::Transpose,
    @keymap.Action::Columns,
    @keymap.Action::PickColumns,
    @keymap.Action::Limit,
    @keymap.Action::ExportCsv,
    @keymap.Action::ExportJson,
    @keymap.Action::RunQuery,
    @keymap.Action::NextTab,
    @keymap.Action::PrevTab,
    @keymap.Action::CloseTab,
  ]
  for action in actions {
    out.push(action.name())
  }
  for table in self.tables {
    out.push("table: " + table.name)
  }
  out
}

///|
/// The palette narrowed to what the query says, matched in order so `gt`
/// finds `next tab`.
pub fn State::palette_matches(self : State) -> Array[String] {
  let out : Array[String] = []
  for item in self.palette_items() {
    if fuzzy(item.to_lower(), self.palette_query.to_lower()) {
      out.push(item)
    }
  }
  out
}

///|
/// Whether every character of `needle` appears in `hay` in order.
pub fn fuzzy(hay : String, needle : String) -> Bool {
  if needle == "" {
    return true
  }
  let chars = hay.to_array()
  let want = needle.to_array()
  let mut i = 0
  let mut j = 0
  while i < chars.length() && j < want.length() {
    if chars[i] == want[j] {
      j = j + 1
    }
    i = i + 1
  }
  j == want.length()
}
