// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The most queries the history keeps; the oldest goes first.
pub let history_limit : Int32 = 500

///|
/// The queries this connection has run, oldest first, and where stepping through them stands.
/// The host keeps them in `path`: one query a block, a blank line after each.
pub struct History {
  entries : Array[String]
  mut at : Int32
  mut path : String?
}

///|
pub fn History::new() -> History {
  { entries: [], at: 0, path: None, }
}

///|
/// Keep the history in `path` from now on, or nowhere.
pub fn History::keep_in(self : History, path : String?) -> Unit {
  self.path = path
}

///|
/// The file the history is kept in.
pub fn History::path(self : History) -> String? {
  self.path
}

///|
/// The queries a history file holds, the newest `history_limit` of them.
fn read_entries(text : String) -> Array[String] {
  let entries = text
    .split("\n\n")
    .map(block => block.trim().to_owned())
    .filter(block => block != "")
    .collect()
  let start = if entries.length() > history_limit {
    entries.length() - history_limit
  } else {
    0
  }
  entries[start:].to_owned()
}

///|
/// Take the queries a history file holds in place of what this one holds.
pub fn History::load(self : History, text : String) -> Unit {
  self.entries.clear()
  self.entries.append(read_entries(text))
  self.at = self.entries.length()
}

///|
/// Remember a query that ran. The same query twice in a row is kept once.
pub fn History::add(self : History, query : String) -> Unit {
  let text = query.trim().to_owned()
  if text != "" && self.entries.last() != Some(text) {
    self.entries.push(text)
    if self.entries.length() > history_limit {
      self.entries.remove(0) |> ignore
    }
  }
  self.at = self.entries.length()
}

///|
/// The query before the one shown, `None` at the oldest.
pub fn History::back(self : History) -> String? {
  guard self.at > 0 else { return None }
  self.at = self.at - 1
  Some(self.entries[self.at])
}

///|
/// The query after the one shown; past the newest, an empty editor.
pub fn History::forward(self : History) -> String? {
  guard self.at < self.entries.length() else { return None }
  self.at = self.at + 1
  Some(
    if self.at == self.entries.length() {
      ""
    } else {
      self.entries[self.at]
    },
  )
}

///|
/// The history file's text.
pub fn History::text(self : History) -> String {
  self.entries.map(q => q + "\n\n").join("")
}
