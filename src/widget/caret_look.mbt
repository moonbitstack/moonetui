// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The terminal's own cursor where a widget takes typing: the user's shape, or
/// one of DECSCUSR's three, blinking or steady. The terminal draws and blinks
/// it, so no frame is redrawn for a blink, and an input method opens its
/// candidates beside it.
#derive(Eq, Debug)
pub(all) enum Caret {
  Terminal
  Block(blink~ : Bool)
  Underline(blink~ : Bool)
  Bar(blink~ : Bool)
}

///|
/// The user's own shape and blink, which is what crossterm's
/// `DefaultUserShape` and a plain shell leave on the screen.
pub let caret : Caret = Terminal

///|
/// The DECSCUSR parameter: 0 for the terminal's own, then a blinking and a
/// steady code for each shape, in the order the sequence numbers them.
pub fn Caret::code(self : Caret) -> Int32 {
  let steady = fn(blink : Bool) { if blink { 0 } else { 1 } }
  match self {
    Terminal => 0
    Block(blink~) => 1 + steady(blink)
    Underline(blink~) => 3 + steady(blink)
    Bar(blink~) => 5 + steady(blink)
  }
}

///|
/// The sequence that sets this shape: `CSI Ps SP q`.
pub fn Caret::sequence(self : Caret) -> String {
  "\u{1b}[" + self.code().to_string() + " q"
}
