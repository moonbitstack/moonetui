// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Turn spans into the bytes that paint them.
///
/// The terminal keeps the last style it was given, so the style in effect is
/// tracked across the whole batch and each segment emits only the parameters
/// that changed. The batch starts and ends at `base`, which leaves the terminal
/// in a known state for whoever writes next.
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
/// Move the cursor to a zero-based column and row. Terminals count from one.
pub fn cursor_to(y : Int, x : Int) -> String {
  "\u{1b}[" + (y + 1).to_string() + ";" + (x + 1).to_string() + "H"
}

///|
/// Clear the screen and put the cursor at the top left.
pub let clear : String = "\u{1b}[2J\u{1b}[H"

///|
/// Show or hide the cursor.
pub fn show_cursor(visible : Bool) -> String {
  if visible {
    "\u{1b}[?25h"
  } else {
    "\u{1b}[?25l"
  }
}
