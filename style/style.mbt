// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The text attributes a terminal can switch on per cell. They are plain flags
/// rather than a bit set so that a diff can name the one that changed.
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
/// No attribute set.
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
/// True when no attribute is set.
pub fn Attrs::is_plain(self : Attrs) -> Bool {
  self == plain
}

///|
/// The union of two attribute sets.
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
/// True when `self` sets an attribute that `other` does not. A terminal has no
/// way to switch one attribute off without a reset, so this is what decides
/// whether a differential render can be incremental.
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
/// A foreground colour, a background colour, and a set of attributes: the
/// complete description of how one cell looks.
pub(all) struct Style {
  fg : Color
  bg : Color
  attrs : Attrs
} derive(Eq, Debug)

///|
/// The terminal's own colours with no attributes — what a cell looks like when
/// nothing has claimed it.
pub let default : Style = { fg: Default, bg: Default, attrs: plain, }

///|
/// Build a style. Every part is optional, so `Style::new(fg=red)` reads as what
/// it is: a style that only claims the foreground.
pub fn Style::new(
  fg? : Color = Default,
  bg? : Color = Default,
  bold? : Bool = false,
  dim? : Bool = false,
  italic? : Bool = false,
  underline? : Bool = false,
  blink? : Bool = false,
  reverse? : Bool = false,
  strike? : Bool = false,
) -> Style {
  { fg, bg, attrs: { bold, dim, italic, underline, blink, reverse, strike, }, }
}

///|
/// Layer `other` over `self`: a colour it names replaces one below it, a colour
/// it leaves as `Default` lets the lower one show through, and attributes
/// accumulate. This is how a widget's style sits on top of its container's.
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
/// True when this style claims nothing at all.
pub fn Style::is_default(self : Style) -> Bool {
  self == default
}

///|
/// The same style with its colours swapped. Reverse video is an attribute the
/// terminal can do itself, but a widget that wants the swap to survive further
/// layering needs it applied to the colours.
pub fn Style::swap(self : Style) -> Style {
  { ..self, fg: self.bg, bg: self.fg, }
}

///|
/// Quantise both colours to the 256-colour cube.
pub fn Style::to_ansi256(self : Style) -> Style {
  { ..self, fg: self.fg.to_ansi256(), bg: self.bg.to_ansi256(), }
}

///|
/// Quantise both colours to the sixteen named colours.
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
