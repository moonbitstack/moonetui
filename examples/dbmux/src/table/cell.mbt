// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A value as the grid holds it: the text a driver gave, and whether the
/// database held NULL, which is not the empty string and must not be saved as
/// one.
pub(all) struct Cell {
  text : String
  is_null : Bool
}

///|
pub fn Cell::of(text : String) -> Cell {
  { text, is_null: false, }
}

///|
pub fn Cell::none() -> Cell {
  { text: "", is_null: true, }
}

///|
/// What the grid draws: the text, or the word NULL so an empty cell and a
/// null one read differently.
pub fn Cell::show(self : Cell) -> String {
  if self.is_null {
    "NULL"
  } else {
    self.text
  }
}

///|
/// The value a save writes: `None` for NULL.
pub fn Cell::value(self : Cell) -> String? {
  if self.is_null {
    None
  } else {
    Some(self.text)
  }
}

///|
/// A cell from a line of text, as an export reads one back.
pub fn Cell::parse(text : String, null_word : String) -> Cell {
  if text == null_word {
    Cell::none()
  } else {
    Cell::of(text)
  }
}
