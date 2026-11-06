// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
#derive(Eq, Debug)
pub(all) struct Cell {
  text : String
  style : @style.Style
  continuation : Bool
}

///|
pub fn Cell::blank(style : @style.Style) -> Cell {
  { text: " ", style, continuation: false, }
}

///|
pub fn cells(line : @strip.Strip) -> Array[Cell] {
  let out : Array[Cell] = []
  for seg in line.segs {
    let text = seg.text
    for cluster in @strip.clusters(text) {
      let (start, end, width) = cluster
      let (code, _) = @strip.code_at(text, start)
      // A control character would move the cursor or start a sequence on the
      // terminal itself, so it is dropped here rather than written.
      if code < 0x20 || (code >= 0x7F && code < 0xA0) {
        continue
      }
      let body = text[start:end].to_owned()
      if width == 0 {
        // A mark with nothing before it in this cluster rides on the last cell.
        if out.length() > 0 {
          let last = out[out.length() - 1]
          out[out.length() - 1] = { ..last, text: last.text + body, }
        }
        continue
      }
      out.push({ text: body, style: seg.style, continuation: false, })
      for _ in 1..<width {
        out.push({ text: "", style: seg.style, continuation: true, })
      }
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
