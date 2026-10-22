// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Cell {
  text : String
  style : @style.Style
  continuation : Bool
} derive(Eq, Debug)

///|
pub fn Cell::blank(style : @style.Style) -> Cell {
  { text: " ", style, continuation: false, }
}

///|
pub fn cells(line : @strip.Strip) -> Array[Cell] {
  let out : Array[Cell] = []
  for seg in line.segs {
    let text = seg.text
    let mut i = 0
    while i < text.length() {
      let (code, used) = @strip.code_at(text, i)
      let width = @strip.cell_width(code)
      if width == 0 {
        if out.length() > 0 {
          let last = out[out.length() - 1]
          out[out.length() - 1] = {
            ..last,
            text: last.text + text[i:i + used].to_owned(),
          }
        }
        i = i + used
        continue
      }
      out.push({
        text: text[i:i + used].to_owned(),
        style: seg.style,
        continuation: false,
      })
      if width == 2 {
        out.push({ text: "", style: seg.style, continuation: true, })
      }
      i = i + used
    }
  }
  out
}

///|
pub fn line_of(columns : ArrayView[Cell], style : @style.Style) -> @strip.Strip {
  let segs : Array[@strip.Seg] = []
  let text = StringBuilder()
  let mut current = style
  let mut started = false
  for i in 0..<columns.length() {
    let cell = columns[i]
    let body = if cell.continuation {
      if i > 0 {
        continue
      }
      " "
    } else if @strip.str_cells(cell.text) == 2 &&
      (i + 1 >= columns.length() || not_continuation(columns[i + 1])) {
      " "
    } else if cell.text.length() == 0 {
      " "
    } else {
      cell.text
    }
    if started && cell.style != current {
      segs.push(@strip.Seg::new(text.to_string(), current))
      text.reset()
    }
    current = cell.style
    started = true
    text.write_string(body)
  }
  if started {
    segs.push(@strip.Seg::new(text.to_string(), current))
  }
  @strip.Strip::from_segs(segs)
}

///|
fn not_continuation(cell : Cell) -> Bool {
  !cell.continuation
}

///|
pub extend Cell with Debug::{to_repr}

///|
pub extend Cell with Eq::{not_equal, equal}
