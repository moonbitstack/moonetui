// Copyright 2026 Heke 1228
// SPDX-License-Identifier: Apache-2.0

///|
pub fn code_at(text : String, index : Int32) -> (Int32, Int32) {
  let first = text[index].to_int()
  if first >= 0xD800 && first <= 0xDBFF && index + 1 < text.length() {
    let second = text[index + 1].to_int()
    if second >= 0xDC00 && second <= 0xDFFF {
      return (0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00), 2)
    }
  }
  (first, 1)
}

///|
pub fn cell_width(code : Int32) -> Int32 {
  // A lone surrogate has no character to ask about; it was always one cell here.
  if code >= 0xD800 && code <= 0xDFFF {
    return 1
  }
  // A control character takes no cell in the grid, where wcwidth answers -1 for "not text".
  @width.width(code.unsafe_to_char()).max(0)
}

///|
pub fn str_cells(text : String) -> Int32 {
  let mut total = 0
  let mut i = 0
  while i < text.length() {
    let (code, used) = code_at(text, i)
    total = total + cell_width(code)
    i = i + used
  }
  total
}

///|
pub fn cut_at(text : String, max_cells : Int32) -> Int32 {
  if max_cells <= 0 {
    return 0
  }
  let mut used = 0
  let mut i = 0
  while i < text.length() {
    let (code, size) = code_at(text, i)
    let w = cell_width(code)
    if used + w > max_cells {
      return i
    }
    used = used + w
    i = i + size
  }
  text.length()
}

///|
pub fn cells_before(text : String, index : Int32) -> Int32 {
  let stop = if index > text.length() { text.length() } else { index }
  let mut total = 0
  let mut i = 0
  while i < stop {
    let (code, used) = code_at(text, i)
    total = total + cell_width(code)
    i = i + used
  }
  total
}
