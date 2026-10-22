// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Seg {
  text : String
  style : @style.Style
  cells : Int32
} derive(Eq, Debug)

///|
pub fn Seg::new(text : String, style : @style.Style) -> Seg {
  { text, style, cells: str_cells(text), }
}

///|
pub(all) struct Strip {
  segs : Array[Seg]
  cells : Int32
} derive(Eq, Debug)

///|
pub fn Strip::empty() -> Strip {
  { segs: [], cells: 0, }
}

///|
pub fn Strip::of(text : String, style : @style.Style) -> Strip {
  if text.length() == 0 {
    return Strip::empty()
  }
  let seg = Seg::new(text, style)
  { segs: [seg], cells: seg.cells, }
}

///|
pub fn Strip::blank(width : Int32, style : @style.Style) -> Strip {
  if width <= 0 {
    return Strip::empty()
  }
  Strip::of(spaces(width), style)
}

///|
pub fn Strip::from_segs(segs : Array[Seg]) -> Strip {
  let mut total = 0
  for seg in segs {
    total = total + seg.cells
  }
  { segs, cells: total, }
}

///|
pub fn Strip::cell_length(self : Strip) -> Int32 {
  self.cells
}

///|
pub fn Strip::is_empty(self : Strip) -> Bool {
  self.cells == 0
}

///|
pub fn Strip::text(self : Strip) -> String {
  let out = StringBuilder()
  for seg in self.segs {
    out.write_string(seg.text)
  }
  out.to_string()
}

///|
pub fn Strip::crop(self : Strip, start : Int32, end : Int32) -> Strip {
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
pub fn Strip::divide(self : Strip, cuts : Array[Int32]) -> Array[Strip] {
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
pub fn Strip::pad_to(
  self : Strip,
  width : Int32,
  style : @style.Style,
) -> Strip {
  if self.cells == width {
    return self
  }
  if self.cells > width {
    return self.crop(0, width)
  }
  Strip::join([self, Strip::blank(width - self.cells, style)])
}

///|
pub fn Strip::apply(self : Strip, style : @style.Style) -> Strip {
  let out : Array[Seg] = []
  for seg in self.segs {
    out.push({ ..seg, style: style.merge(seg.style), })
  }
  { segs: out, cells: self.cells, }
}

///|
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
fn crop_text(text : String, start : Int32, end : Int32) -> String {
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
fn spaces(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(" ")
  }
  out.to_string()
}

///|
pub extend Seg with Debug::{to_repr}

///|
pub extend Seg with Eq::{not_equal, equal}

///|
pub extend Strip with Debug::{to_repr}

///|
pub extend Strip with Eq::{not_equal, equal}
