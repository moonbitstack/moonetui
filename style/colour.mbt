// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum Colour {
  Default
  Ansi(Int32)
  Ansi256(Int32)
  Rgb(Int32, Int32, Int32)
} derive(Eq, Debug)

///|
pub let black : Colour = Ansi(0)

///|
pub let red : Colour = Ansi(1)

///|
pub let green : Colour = Ansi(2)

///|
pub let yellow : Colour = Ansi(3)

///|
pub let blue : Colour = Ansi(4)

///|
pub let magenta : Colour = Ansi(5)

///|
pub let cyan : Colour = Ansi(6)

///|
pub let white : Colour = Ansi(7)

///|
pub let bright_black : Colour = Ansi(8)

///|
pub let bright_red : Colour = Ansi(9)

///|
pub let bright_green : Colour = Ansi(10)

///|
pub let bright_yellow : Colour = Ansi(11)

///|
pub let bright_blue : Colour = Ansi(12)

///|
pub let bright_magenta : Colour = Ansi(13)

///|
pub let bright_cyan : Colour = Ansi(14)

///|
pub let bright_white : Colour = Ansi(15)

///|
pub fn Colour::rgb(r : Int32, g : Int32, b : Int32) -> Colour {
  Rgb(channel(r), channel(g), channel(b))
}

///|
pub fn Colour::parse(text : String) -> Colour? {
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
pub fn Colour::to_rgb(self : Colour) -> (Int32, Int32, Int32)? {
  match self {
    Default => None
    Ansi(i) => Some(ansi16_rgb(i))
    Ansi256(i) => Some(ansi256_rgb(i))
    Rgb(r, g, b) => Some((r, g, b))
  }
}

///|
pub fn Colour::to_ansi256(self : Colour) -> Colour {
  match self {
    Default => Default
    Ansi(_) => self
    Ansi256(_) => self
    Rgb(r, g, b) => Ansi256(nearest_cube(r, g, b))
  }
}

///|
pub fn Colour::to_ansi16(self : Colour) -> Colour {
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
pub fn Colour::blend(self : Colour, other : Colour, factor : Int32) -> Colour {
  let f = clamp(factor, 0, 100)
  match (self.to_rgb(), other.to_rgb()) {
    (Some((r1, g1, b1)), Some((r2, g2, b2))) =>
      Rgb(mix(r1, r2, f), mix(g1, g2, f), mix(b1, b2, f))
    (None, _) => if f >= 50 { other } else { self }
    (_, None) => if f >= 50 { other } else { self }
  }
}

///|
fn mix(a : Int32, b : Int32, factor : Int32) -> Int32 {
  a + (b - a) * factor / 100
}

///|
fn channel(value : Int32) -> Int32 {
  clamp(value, 0, 255)
}

///|
fn clamp(value : Int32, low : Int32, high : Int32) -> Int32 {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn hex(unit : UInt16) -> Int32 {
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
fn hex2(hi : UInt16, lo : UInt16) -> Int32 {
  let h = hex(hi)
  let l = hex(lo)
  if h < 0 || l < 0 {
    -1
  } else {
    h * 16 + l
  }
}

///|
let named : Array[(Int32, Int32, Int32)] = [
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
let levels : Array[Int32] = [0, 95, 135, 175, 215, 255]

///|
fn ansi16_rgb(index : Int32) -> (Int32, Int32, Int32) {
  named[clamp(index, 0, 15)]
}

///|
fn ansi256_rgb(index : Int32) -> (Int32, Int32, Int32) {
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
fn nearest_cube(r : Int32, g : Int32, b : Int32) -> Int32 {
  let cube = 16 +
    nearest_level(r) * 36 +
    nearest_level(g) * 6 +
    nearest_level(b)
  let grey = nearest_grey(r, g, b)
  if dist(ansi256_rgb(cube), (r, g, b)) <= dist(ansi256_rgb(grey), (r, g, b)) {
    cube
  } else {
    grey
  }
}

///|
fn nearest_level(value : Int32) -> Int32 {
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
fn nearest_grey(r : Int32, g : Int32, b : Int32) -> Int32 {
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
fn nearest_named(r : Int32, g : Int32, b : Int32) -> Int32 {
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
fn dist(a : (Int32, Int32, Int32), b : (Int32, Int32, Int32)) -> Int32 {
  let (r1, g1, b1) = a
  let (r2, g2, b2) = b
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}

///|
fn abs(value : Int32) -> Int32 {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
pub extend Colour with Debug::{to_repr}

///|
pub extend Colour with Eq::{not_equal, equal}
