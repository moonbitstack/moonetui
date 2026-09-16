// Copyright 2026 Heke 1228
// SPDX-License-Identifier: Apache-2.0

///|
/// Decode the code point starting at code unit `index`, returning it with the
/// number of code units it took. A `String` is UTF-16, so an astral character —
/// most emoji, for one — arrives as a surrogate pair that must be read as a
/// unit; indexing one half of it gives a number no width table knows.
pub fn code_at(text : String, index : Int) -> (Int, Int) {
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
/// How many columns a code point occupies: two for the East Asian wide and
/// fullwidth ranges, none for combining marks, format characters and control
/// characters, one for everything else.
pub fn cell_width(code : Int) -> Int {
  if code < 32 || (code >= 0x7F && code < 0xA0) {
    // Control characters do not advance the cursor; a caller that wants one to
    // mean something has to act on it before it reaches the buffer.
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
/// The number of columns a string occupies.
pub fn str_cells(text : String) -> Int {
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
/// The code unit index just past the longest prefix that fits in `max_cells`
/// columns. A wide character is never split: if only one of its two columns
/// fits, it is left out.
pub fn cut_at(text : String, max_cells : Int) -> Int {
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
/// The number of columns the prefix before code unit `index` occupies.
pub fn cells_before(text : String, index : Int) -> Int {
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
/// Binary search over the sorted, disjoint ranges the generated table holds.
fn in_ranges(table : Array[(Int, Int)], code : Int) -> Bool {
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
