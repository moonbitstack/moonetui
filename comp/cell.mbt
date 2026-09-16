// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One column of the screen. A wide character occupies two columns: the first
/// holds it, the second holds nothing and is marked as its continuation, which
/// is what lets a diff say "this column changed" about something two columns
/// wide without producing half a character.
pub(all) struct Cell {
  text : String
  style : @style.Style
  continuation : Bool
} derive(Eq, Debug)

///|
/// A blank column in the given style.
pub fn Cell::blank(style : @style.Style) -> Cell {
  { text: " ", style, continuation: false, }
}

///|
/// Expand a line into one entry per column.
pub fn cells(line : @strip.Strip) -> Array[Cell] {
  let out : Array[Cell] = []
  for seg in line.segs {
    let text = seg.text
    let mut i = 0
    while i < text.length() {
      let (code, used) = @strip.code_at(text, i)
      let width = @strip.cell_width(code)
      if width == 0 {
        // A combining mark belongs to the column before it; with nothing to
        // attach to it is dropped, since a terminal would not place it either.
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
/// Rebuild a line from a range of columns.
///
/// A range that starts on the second half of a wide character cannot show that
/// character, so the column becomes a space — the same substitution cropping
/// makes, and the reason a diff may repaint one column more than it strictly
/// changed.
pub fn line_of(columns : ArrayView[Cell], style : @style.Style) -> @strip.Strip {
  let segs : Array[@strip.Seg] = []
  let text = StringBuilder()
  let mut current = style
  let mut started = false
  for i in 0..<columns.length() {
    let cell = columns[i]
    // A continuation column is written by the character that owns it, unless
    // that character starts before the range, in which case only this half is
    // visible and a terminal would show a space.
    let body = if cell.continuation {
      if i > 0 {
        continue
      }
      " "
    } else if @strip.str_cells(cell.text) == 2 &&
      (i + 1 >= columns.length() || not_continuation(columns[i + 1])) {
      // The other half of this character falls outside the range.
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
