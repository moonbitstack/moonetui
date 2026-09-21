// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A terminal colour. `Default` means the terminal's own foreground or
/// background — it is not black, and it is not white; it is whatever the user
/// configured, which is why it has to survive as its own case rather than being
/// resolved to a value.
pub(all) enum Color {
  Default
  /// One of the sixteen named colours, 0 to 15, the last eight being the bright
  /// half.
  Ansi(Int)
  /// An index into the 256-colour cube.
  Ansi256(Int)
  /// True colour, 0 to 255 per channel.
  Rgb(Int, Int, Int)
} derive(Eq, Debug)

///|
/// The sixteen named colours, in the order the terminal numbers them.
pub let black : Color = Ansi(0)

///|
pub let red : Color = Ansi(1)

///|
pub let green : Color = Ansi(2)

///|
pub let yellow : Color = Ansi(3)

///|
pub let blue : Color = Ansi(4)

///|
pub let magenta : Color = Ansi(5)

///|
pub let cyan : Color = Ansi(6)

///|
pub let white : Color = Ansi(7)

///|
pub let bright_black : Color = Ansi(8)

///|
pub let bright_red : Color = Ansi(9)

///|
pub let bright_green : Color = Ansi(10)

///|
pub let bright_yellow : Color = Ansi(11)

///|
pub let bright_blue : Color = Ansi(12)

///|
pub let bright_magenta : Color = Ansi(13)

///|
pub let bright_cyan : Color = Ansi(14)

///|
pub let bright_white : Color = Ansi(15)

///|
/// Build a true colour, clamping each channel to 0–255.
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  Rgb(channel(r), channel(g), channel(b))
}

///|
/// Parse `#rgb` or `#rrggbb`. Returns `None` for anything else, so it doubles as
/// validation for a colour written in a configuration file.
pub fn Color::parse(text : String) -> Color? {
  if text.length() == 0 || text[0] != '#' {
    return None
  }
  match text.length() {
    4 => {
      let r = hex(text[1])
      let g = hex(text[2])
      let b = hex(text[3])
      if r < 0 || g < 0 || b < 0 {
        None
      } else {
        // #abc means #aabbcc: each digit is repeated, not padded with zero.
        Some(Rgb(r * 17, g * 17, b * 17))
      }
    }
    7 => {
      let r = hex2(text[1], text[2])
      let g = hex2(text[3], text[4])
      let b = hex2(text[5], text[6])
      if r < 0 || g < 0 || b < 0 {
        None
      } else {
        Some(Rgb(r, g, b))
      }
    }
    _ => None
  }
}

///|
/// The true-colour triple this colour stands for, using the xterm palette for
/// the indexed cases. `Default` has no triple — only the terminal knows it.
pub fn Color::to_rgb(self : Color) -> (Int, Int, Int)? {
  match self {
    Default => None
    Ansi(i) => Some(ansi16_rgb(i))
    Ansi256(i) => Some(ansi256_rgb(i))
    Rgb(r, g, b) => Some((r, g, b))
  }
}

///|
/// Quantise to the 256-colour cube, for a terminal that cannot do true colour.
/// Named colours pass through: an `Ansi` index already exists in that cube, and
/// resolving it would throw away the user's palette.
pub fn Color::to_ansi256(self : Color) -> Color {
  match self {
    Default => Default
    Ansi(_) => self
    Ansi256(_) => self
    Rgb(r, g, b) => Ansi256(nearest_cube(r, g, b))
  }
}

///|
/// Quantise to the sixteen named colours, for a terminal that can do no better.
pub fn Color::to_ansi16(self : Color) -> Color {
  match self {
    Default => Default
    Ansi(_) => self
    Ansi256(i) => {
      let (r, g, b) = ansi256_rgb(i)
      Ansi(nearest_named(r, g, b))
    }
    Rgb(r, g, b) => Ansi(nearest_named(r, g, b))
  }
}

///|
/// Mix two colours, `factor` running from 0 (all `self`) to 100 (all `other`).
/// A colour the terminal owns cannot be mixed, so `Default` on either side wins
/// whenever it is the dominant end and is otherwise left alone.
pub fn Color::blend(self : Color, other : Color, factor : Int) -> Color {
  let f = clamp(factor, 0, 100)
  match (self.to_rgb(), other.to_rgb()) {
    (Some((r1, g1, b1)), Some((r2, g2, b2))) =>
      Rgb(mix(r1, r2, f), mix(g1, g2, f), mix(b1, b2, f))
    (None, _) => if f >= 50 { other } else { self }
    (_, None) => if f >= 50 { other } else { self }
  }
}

///|
fn mix(a : Int, b : Int, factor : Int) -> Int {
  a + (b - a) * factor / 100
}

///|
fn channel(value : Int) -> Int {
  clamp(value, 0, 255)
}

///|
fn clamp(value : Int, low : Int, high : Int) -> Int {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn hex(unit : UInt16) -> Int {
  let code = unit.to_int()
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else if code >= 65 && code <= 70 {
    code - 55
  } else {
    -1
  }
}

///|
fn hex2(hi : UInt16, lo : UInt16) -> Int {
  let h = hex(hi)
  let l = hex(lo)
  if h < 0 || l < 0 {
    -1
  } else {
    h * 16 + l
  }
}

///|
/// The xterm palette for the sixteen named colours.
let named : Array[(Int, Int, Int)] = [
  (0, 0, 0),
  (128, 0, 0),
  (0, 128, 0),
  (128, 128, 0),
  (0, 0, 128),
  (128, 0, 128),
  (0, 128, 128),
  (192, 192, 192),
  (128, 128, 128),
  (255, 0, 0),
  (0, 255, 0),
  (255, 255, 0),
  (0, 0, 255),
  (255, 0, 255),
  (0, 255, 255),
  (255, 255, 255),
]

///|
/// The six levels each channel takes inside the 6×6×6 cube.
let levels : Array[Int] = [0, 95, 135, 175, 215, 255]

///|
fn ansi16_rgb(index : Int) -> (Int, Int, Int) {
  named[clamp(index, 0, 15)]
}

///|
fn ansi256_rgb(index : Int) -> (Int, Int, Int) {
  let i = clamp(index, 0, 255)
  if i < 16 {
    named[i]
  } else if i < 232 {
    let n = i - 16
    (levels[n / 36], levels[n / 6 % 6], levels[n % 6])
  } else {
    // The trailing 24 entries are a grey ramp that misses both ends.
    let grey = 8 + (i - 232) * 10
    (grey, grey, grey)
  }
}

///|
fn nearest_cube(r : Int, g : Int, b : Int) -> Int {
  let cube = 16 +
    nearest_level(r) * 36 +
    nearest_level(g) * 6 +
    nearest_level(b)
  let grey = nearest_grey(r, g, b)
  // Grey text is common enough that the ramp usually wins for it; compare both
  // candidates rather than assuming the cube is closer.
  if dist(ansi256_rgb(cube), (r, g, b)) <= dist(ansi256_rgb(grey), (r, g, b)) {
    cube
  } else {
    grey
  }
}

///|
fn nearest_level(value : Int) -> Int {
  let mut best = 0
  let mut best_gap = 1000
  for i in 0..<levels.length() {
    let gap = abs(levels[i] - value)
    if gap < best_gap {
      best = i
      best_gap = gap
    }
  }
  best
}

///|
fn nearest_grey(r : Int, g : Int, b : Int) -> Int {
  let average = (r + g + b) / 3
  if average < 8 {
    232
  } else if average > 238 {
    255
  } else {
    232 + (average - 8 + 5) / 10
  }
}

///|
fn nearest_named(r : Int, g : Int, b : Int) -> Int {
  let mut best = 0
  let mut best_gap = 1000000
  for i in 0..<named.length() {
    let gap = dist(named[i], (r, g, b))
    if gap < best_gap {
      best = i
      best_gap = gap
    }
  }
  best
}

///|
fn dist(a : (Int, Int, Int), b : (Int, Int, Int)) -> Int {
  let (r1, g1, b1) = a
  let (r2, g2, b2) = b
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}

///|
fn abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
pub extend Color with Debug::{to_repr}

///|
pub extend Color with Eq::{not_equal, equal}
