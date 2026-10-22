// Copyright 2026 Kelei Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum KeyCode {
  // A code point, not a MoonBit `Char`, so an astral character is one key.
  Char(Int32)
  Enter
  Tab
  BackTab
  Backspace
  Delete
  Escape
  Insert
  Up
  Down
  Left
  Right
  Home
  End
  PageUp
  PageDown
  F(Int32)
} derive(Eq, Debug)

///|
pub(all) struct Mods {
  ctrl : Bool
  alt : Bool
  shift : Bool
} derive(Eq, Debug)

///|
pub let none : Mods = { ctrl: false, alt: false, shift: false, }

///|
pub fn Mods::of_param(param : Int32) -> Mods {
  if param <= 1 {
    return none
  }
  // A terminal sends one plus a bit per modifier: shift, then alt, then ctrl.
  let bits = param - 1
  { shift: bits % 2 == 1, alt: bits / 2 % 2 == 1, ctrl: bits / 4 % 2 == 1, }
}

///|
pub fn Mods::is_none(self : Mods) -> Bool {
  self == none
}

///|
pub(all) struct Key {
  code : KeyCode
  mods : Mods
} derive(Eq, Debug)

///|
pub fn Key::of(code : KeyCode) -> Key {
  { code, mods: none, }
}

///|
pub fn Key::with_mods(code : KeyCode, mods : Mods) -> Key {
  { code, mods, }
}

///|
pub fn Key::char(code : Int32) -> Key {
  { code: Char(code), mods: none, }
}

///|
pub(all) enum MouseKind {
  Down
  Up
  Move
  ScrollUp
  ScrollDown
  ScrollLeft
  ScrollRight
} derive(Eq, Debug)

///|
pub(all) struct Mouse {
  kind : MouseKind
  button : Int32
  x : Int32
  y : Int32
  mods : Mods
} derive(Eq, Debug)

///|
pub(all) enum Event {
  Key(Key)
  Mouse(Mouse)
  Paste(String)
  Resize(Int32, Int32)
  FocusIn
  FocusOut
} derive(Eq, Debug)

///|
pub extend Event with Debug::{to_repr}

///|
pub extend Event with Eq::{not_equal, equal}

///|
pub extend Key with Debug::{to_repr}

///|
pub extend Key with Eq::{not_equal, equal}

///|
pub extend KeyCode with Debug::{to_repr}

///|
pub extend KeyCode with Eq::{not_equal, equal}

///|
pub extend Mods with Debug::{to_repr}

///|
pub extend Mods with Eq::{not_equal, equal}

///|
pub extend Mouse with Debug::{to_repr}

///|
pub extend Mouse with Eq::{not_equal, equal}

///|
pub extend MouseKind with Debug::{to_repr}

///|
pub extend MouseKind with Eq::{not_equal, equal}
