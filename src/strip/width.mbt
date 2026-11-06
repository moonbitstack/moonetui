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
/// The grapheme clusters of `text` with the cells each takes, as `(start, end, cells)` in UTF-16
/// offsets. A cluster is what a reader sees as one character and a cursor steps over (UAX #29): a
/// letter with its combining marks, an emoji ZWJ sequence, a flag. A ZWJ sequence takes the cells
/// of its first emoji, and a Variation Selector 16 widens a text-style character to two, as
/// terminals draw them. A control character takes none.
pub fn clusters(text : String) -> Array[(Int32, Int32, Int32)] {
  let out = []
  let mut i = 0
  while i < text.length() {
    let (_, end) = @segment.grapheme_at(text, i)
    let end = if end > i { end } else { i + 1 }
    out.push((i, end, @width.text_width(text[i:end]).max(0)))
    i = end
  }
  out
}

///|
/// Where the cluster after the one at `index` starts.
pub fn next_cluster(text : String, index : Int32) -> Int32 {
  if index >= text.length() {
    return text.length()
  }
  let (_, end) = @segment.grapheme_at(text, index)
  if end > index {
    end
  } else {
    index + 1
  }
}

///|
/// Where the cluster before `index` starts.
pub fn prev_cluster(text : String, index : Int32) -> Int32 {
  if index <= 0 {
    return 0
  }
  @segment.grapheme_at(text, index - 1).0
}

///|
pub fn str_cells(text : String) -> Int32 {
  let mut total = 0
  for cluster in clusters(text) {
    total = total + cluster.2
  }
  total
}

///|
pub fn cut_at(text : String, max_cells : Int32) -> Int32 {
  if max_cells <= 0 {
    return 0
  }
  let mut used = 0
  for cluster in clusters(text) {
    let (start, _, cells) = cluster
    if used + cells > max_cells {
      return start
    }
    used = used + cells
  }
  text.length()
}

///|
pub fn cells_before(text : String, index : Int32) -> Int32 {
  let stop = if index > text.length() { text.length() } else { index }
  let mut total = 0
  for cluster in clusters(text) {
    let (start, _, cells) = cluster
    if start >= stop {
      break
    }
    total = total + cells
  }
  total
}
