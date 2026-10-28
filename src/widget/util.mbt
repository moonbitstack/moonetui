// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Numbers a widget has to hold within bounds, and the one glyph a frame is
/// built from: what every widget that draws a box reaches for.
fn at_least_zero(value : Int32) -> Int32 {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn at_least_one(value : Int32) -> Int32 {
  if value < 1 {
    1
  } else {
    value
  }
}

///|
fn constrain(value : Int32, low : Int32, high : Int32) -> Int32 {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn smallest(a : Int32, b : Int32) -> Int32 {
  if a < b {
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
