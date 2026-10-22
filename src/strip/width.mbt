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
  if code < 32 || (code >= 0x7F && code < 0xA0) {
    return 0
  }
  if in_ranges(zero, code) {
    return 0
  }
  if in_ranges(wide, code) {
    return 2
  }
  1
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

///|
fn in_ranges(table : Array[(Int32, Int32)], code : Int32) -> Bool {
  let mut low = 0
  let mut high = table.length() - 1
  while low <= high {
    let mid = (low + high) / 2
    let (start, end) = table[mid]
    if code < start {
      high = mid - 1
    } else if code > end {
      low = mid + 1
    } else {
      return true
    }
  }
  false
}
