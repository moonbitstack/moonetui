// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn encode(spans : Array[Span], base : @style.Style) -> String {
  if spans.length() == 0 {
    return ""
  }
  let out = StringBuilder()
  out.write_string(@style.render(base))
  let mut current = base
  for span in spans {
    out.write_string(cursor_to(span.y, span.x))
    for seg in span.line.segs {
      out.write_string(@style.delta(current, seg.style))
      current = seg.style
      out.write_string(seg.text)
    }
  }
  out.write_string(@style.delta(current, base))
  out.to_string()
}

///|
pub fn cursor_to(y : Int32, x : Int32) -> String {
  "\u{1b}[" + (y + 1).to_string() + ";" + (x + 1).to_string() + "H"
}

///|
pub let clear : String = "\u{1b}[2J\u{1b}[H"

///|
pub fn show_cursor(visible : Bool) -> String {
  if visible {
    "\u{1b}[?25h"
  } else {
    "\u{1b}[?25l"
  }
}
