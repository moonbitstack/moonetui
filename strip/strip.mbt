// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A run of text in one style. `cells` is measured when the segment is built,
/// because a line is cropped and divided far more often than it is created, and
/// re-measuring on every crop is what makes a naive renderer quadratic.
pub(all) struct Seg {
  text : String
  style : @style.Style
  cells : Int
} derive(Eq, Debug)

///|
/// Build a segment, measuring its width.
pub fn Seg::new(text : String, style : @style.Style) -> Seg {
  { text, style, cells: str_cells(text), }
}

///|
/// One line of a rendered screen: the segments left to right, with the total
/// width kept alongside.
pub(all) struct Strip {
  segs : Array[Seg]
  cells : Int
} derive(Eq, Debug)

///|
/// A line with nothing on it.
pub fn Strip::empty() -> Strip {
  { segs: [], cells: 0, }
}

///|
/// A line holding one run of text.
pub fn Strip::of(text : String, style : @style.Style) -> Strip {
  if text.length() == 0 {
    return Strip::empty()
  }
  let seg = Seg::new(text, style)
  { segs: [seg], cells: seg.cells, }
}

///|
/// A line of `width` spaces in one style.
pub fn Strip::blank(width : Int, style : @style.Style) -> Strip {
  if width <= 0 {
    return Strip::empty()
  }
  Strip::of(spaces(width), style)
}

///|
/// Build a line from segments, measuring the total.
pub fn Strip::from_segs(segs : Array[Seg]) -> Strip {
  let mut total = 0
  for seg in segs {
    total = total + seg.cells
  }
  { segs, cells: total, }
}

///|
/// The width of this line in columns.
pub fn Strip::cell_length(self : Strip) -> Int {
  self.cells
}

///|
/// True when the line holds no columns.
pub fn Strip::is_empty(self : Strip) -> Bool {
  self.cells == 0
}

///|
/// The text of the line with its styles dropped.
pub fn Strip::text(self : Strip) -> String {
  let out = StringBuilder()
  for seg in self.segs {
    out.write_string(seg.text)
  }
  out.to_string()
}

///|
/// The columns from `start` up to but not including `end`.
///
/// A wide character that straddles either boundary cannot be shown in half, so
/// the visible half becomes a space — the same substitution a terminal makes
/// when a double-width character is overwritten from one side.
pub fn Strip::crop(self : Strip, start : Int, end : Int) -> Strip {
  let from = if start < 0 { 0 } else { start }
  let to = if end > self.cells { self.cells } else { end }
  if to <= from {
    return Strip::empty()
  }
  if from == 0 && to == self.cells {
    return self
  }
  let out : Array[Seg] = []
  let mut column = 0
  for seg in self.segs {
    let seg_end = column + seg.cells
    if seg_end <= from || column >= to {
      column = seg_end
      continue
    }
    let text = crop_text(seg.text, from - column, to - column)
    if text.length() > 0 {
      out.push(Seg::new(text, seg.style))
    }
    column = seg_end
  }
  Strip::from_segs(out)
}

///|
/// Split the line at each of the given columns, in ascending order. The parts
/// cover the line exactly, so joining them back gives the original width.
pub fn Strip::divide(self : Strip, cuts : Array[Int]) -> Array[Strip] {
  let parts : Array[Strip] = []
  let mut start = 0
  for cut in cuts {
    let end = if cut > self.cells { self.cells } else { cut }
    parts.push(self.crop(start, end))
    start = if end > start { end } else { start }
  }
  parts.push(self.crop(start, self.cells))
  parts
}

///|
/// Lay the lines end to end.
pub fn Strip::join(parts : Array[Strip]) -> Strip {
  let out : Array[Seg] = []
  for part in parts {
    for seg in part.segs {
      out.push(seg)
    }
  }
  Strip::from_segs(out)
}

///|
/// Extend the line to `width` columns with spaces in `style`, or crop it when
/// it is already longer.
pub fn Strip::pad_to(self : Strip, width : Int, style : @style.Style) -> Strip {
  if self.cells == width {
    return self
  }
  if self.cells > width {
    return self.crop(0, width)
  }
  Strip::join([self, Strip::blank(width - self.cells, style)])
}

///|
/// Layer a style under every segment of the line: the segment's own style wins
/// wherever it names something.
pub fn Strip::apply(self : Strip, style : @style.Style) -> Strip {
  let out : Array[Seg] = []
  for seg in self.segs {
    out.push({ ..seg, style: style.merge(seg.style), })
  }
  { segs: out, cells: self.cells, }
}

///|
/// Merge neighbouring segments that share a style, and drop empty ones. Two
/// lines that look identical compare equal only once both are simplified, so
/// the differ runs this first.
pub fn Strip::simplify(self : Strip) -> Strip {
  let out : Array[Seg] = []
  for seg in self.segs {
    if seg.text.length() == 0 {
      continue
    }
    if out.length() > 0 && out[out.length() - 1].style == seg.style {
      let last = out[out.length() - 1]
      out[out.length() - 1] = Seg::new(last.text + seg.text, last.style)
    } else {
      out.push(seg)
    }
  }
  { segs: out, cells: self.cells, }
}

///|
/// Crop one segment's text to the column range, substituting a space for a wide
/// character the range cuts in half.
fn crop_text(text : String, start : Int, end : Int) -> String {
  let out = StringBuilder()
  let mut column = 0
  let mut i = 0
  while i < text.length() {
    let (code, used) = code_at(text, i)
    let w = cell_width(code)
    let next = column + w
    if column >= end {
      break
    }
    if next > start {
      if w == 2 && (column < start || next > end) {
        out.write_string(" ")
      } else if w == 0 && column < start {
        // A combining mark whose base character was cropped away has nothing to
        // attach to, so it goes with the base.
        ()
      } else {
        out.write_substring(text, i, used)
      }
    }
    column = next
    i = i + used
  }
  out.to_string()
}

///|
fn spaces(count : Int) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(" ")
  }
  out.to_string()
}
