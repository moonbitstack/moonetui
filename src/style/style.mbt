// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Attrs {
  bold : Bool
  dim : Bool
  italic : Bool
  underline : Bool
  blink : Bool
  reverse : Bool
  strike : Bool
} derive(Eq, Debug)

///|
pub let plain : Attrs = {
  bold: false,
  dim: false,
  italic: false,
  underline: false,
  blink: false,
  reverse: false,
  strike: false,
}

///|
pub fn Attrs::is_plain(self : Attrs) -> Bool {
  self == plain
}

///|
pub fn Attrs::union(self : Attrs, other : Attrs) -> Attrs {
  {
    bold: self.bold || other.bold,
    dim: self.dim || other.dim,
    italic: self.italic || other.italic,
    underline: self.underline || other.underline,
    blink: self.blink || other.blink,
    reverse: self.reverse || other.reverse,
    strike: self.strike || other.strike,
  }
}

///|
pub fn Attrs::drops_from(self : Attrs, other : Attrs) -> Bool {
  (self.bold && not_set(other.bold)) ||
  (self.dim && not_set(other.dim)) ||
  (self.italic && not_set(other.italic)) ||
  (self.underline && not_set(other.underline)) ||
  (self.blink && not_set(other.blink)) ||
  (self.reverse && not_set(other.reverse)) ||
  (self.strike && not_set(other.strike))
}

///|
fn not_set(flag : Bool) -> Bool {
  !flag
}

///|
pub(all) struct Style {
  fg : Colour
  bg : Colour
  attrs : Attrs
} derive(Eq, Debug)

///|
pub let default : Style = { fg: Default, bg: Default, attrs: plain, }

///|
pub fn Style::new(
  fg~ : Colour = Default,
  bg~ : Colour = Default,
  bold~ : Bool = false,
  dim~ : Bool = false,
  italic~ : Bool = false,
  underline~ : Bool = false,
  blink~ : Bool = false,
  reverse~ : Bool = false,
  strike~ : Bool = false,
) -> Style {
  { fg, bg, attrs: { bold, dim, italic, underline, blink, reverse, strike, }, }
}

///|
pub fn Style::merge(self : Style, other : Style) -> Style {
  {
    fg: match other.fg {
      Default => self.fg
      _ => other.fg
    },
    bg: match other.bg {
      Default => self.bg
      _ => other.bg
    },
    attrs: self.attrs.union(other.attrs),
  }
}

///|
pub fn Style::is_default(self : Style) -> Bool {
  self == default
}

///|
pub fn Style::swap(self : Style) -> Style {
  { ..self, fg: self.bg, bg: self.fg, }
}

///|
pub fn Style::to_ansi256(self : Style) -> Style {
  { ..self, fg: self.fg.to_ansi256(), bg: self.bg.to_ansi256(), }
}

///|
pub fn Style::to_ansi16(self : Style) -> Style {
  { ..self, fg: self.fg.to_ansi16(), bg: self.bg.to_ansi16(), }
}

///|
pub extend Attrs with Debug::{to_repr}

///|
pub extend Attrs with Eq::{not_equal, equal}

///|
pub extend Style with Debug::{to_repr}

///|
pub extend Style with Eq::{not_equal, equal}
