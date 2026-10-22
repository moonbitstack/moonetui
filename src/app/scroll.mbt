// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct ScrollState {
  mut x : Int32
  mut y : Int32
  mut vw : Int32
  mut vh : Int32
  mut cw : Int32
  mut ch : Int32
} derive(Eq, Debug)

///|
pub extend ScrollState with Debug::{to_repr}

///|
pub extend ScrollState with Eq::{not_equal, equal}

///|
pub fn ScrollState::new() -> ScrollState {
  { x: 0, y: 0, vw: 0, vh: 0, cw: 0, ch: 0, }
}

///|
pub fn ScrollState::max_x(self : ScrollState) -> Int32 {
  at_least_zero(self.cw - self.vw)
}

///|
pub fn ScrollState::max_y(self : ScrollState) -> Int32 {
  at_least_zero(self.ch - self.vh)
}

///|
pub fn ScrollState::scroll_to(
  self : ScrollState,
  x? : Int32,
  y? : Int32,
) -> Bool {
  let to_x = match x {
    Some(value) => clamp_int(value, 0, self.max_x())
    None => self.x
  }
  let to_y = match y {
    Some(value) => clamp_int(value, 0, self.max_y())
    None => self.y
  }
  if self.x == to_x && self.y == to_y {
    return false
  }
  self.x = to_x
  self.y = to_y
  true
}

///|
pub fn ScrollState::scroll_by(
  self : ScrollState,
  dx~ : Int32 = 0,
  dy~ : Int32 = 0,
) -> Bool {
  self.scroll_to(x=self.x + dx, y=self.y + dy)
}

///|
pub(all) struct View {
  state : ScrollState
  bar : @style.Style
  vbar : Bool
  hbar : Bool
} derive(Eq, Debug)

///|
pub extend View with Debug::{to_repr}

///|
pub extend View with Eq::{not_equal, equal}

///|
fn clamp_int(value : Int32, low : Int32, high : Int32) -> Int32 {
  if high < low {
    return low
  }
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn int_max(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn repeat_glyph(glyph : String, count : Int32) -> String {
  if count <= 0 {
    return ""
  }
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}
