// Copyright 2026 Kelei Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which key was pressed. `Char` carries a code point rather than a `Char` so
/// that an astral character — an emoji typed or pasted into an input — is one
/// key, not two halves of a surrogate pair.
pub(all) enum KeyCode {
  Char(Int)
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
  /// Function key, numbered from one.
  F(Int)
} derive(Eq, Debug)

///|
/// The modifier keys held down with a key or a mouse report.
pub(all) struct Mods {
  ctrl : Bool
  alt : Bool
  shift : Bool
} derive(Eq, Debug)

///|
/// No modifier held.
pub let none : Mods = { ctrl: false, alt: false, shift: false, }

///|
/// Decode the modifier parameter a terminal sends inside a CSI sequence, where
/// the value is one plus a bit per modifier.
pub fn Mods::of_param(param : Int) -> Mods {
  if param <= 1 {
    return none
  }
  let bits = param - 1
  { shift: bits % 2 == 1, alt: bits / 2 % 2 == 1, ctrl: bits / 4 % 2 == 1, }
}

///|
/// True when no modifier is held.
pub fn Mods::is_none(self : Mods) -> Bool {
  self == none
}

///|
/// A key press: what was pressed and what was held down with it.
pub(all) struct Key {
  code : KeyCode
  mods : Mods
} derive(Eq, Debug)

///|
/// A key with no modifier.
pub fn Key::of(code : KeyCode) -> Key {
  { code, mods: none, }
}

///|
/// A key with modifiers.
pub fn Key::with_mods(code : KeyCode, mods : Mods) -> Key {
  { code, mods, }
}

///|
/// A printable character with no modifier.
pub fn Key::char(code : Int) -> Key {
  { code: Char(code), mods: none, }
}

///|
/// What the mouse did. Scrolling is reported as its own kind because a terminal
/// sends it as a button press that is never released.
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
/// A mouse report. Coordinates are zero-based columns and rows, converted from
/// the one-based numbers the terminal sends.
pub(all) struct Mouse {
  kind : MouseKind
  button : Int
  x : Int
  y : Int
  mods : Mods
} derive(Eq, Debug)

///|
/// Everything the terminal can tell the program.
pub(all) enum Event {
  Key(Key)
  Mouse(Mouse)
  /// Text delivered in one piece by a bracketed paste, which is how a paste is
  /// told apart from someone typing very fast.
  Paste(String)
  /// The terminal reported a new size, in columns and rows.
  Resize(Int, Int)
  FocusIn
  FocusOut
} derive(Eq, Debug)
