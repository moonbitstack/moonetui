// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub let enter_alt : String = "\u{1b}[?1049h"

///|
pub let leave_alt : String = "\u{1b}[?1049l"

///|
pub let enable_mouse : String = "\u{1b}[?1000h\u{1b}[?1003h\u{1b}[?1006h"

///|
pub let disable_mouse : String = "\u{1b}[?1006l\u{1b}[?1003l\u{1b}[?1000l"

///|
pub let enable_paste : String = "\u{1b}[?2004h"

///|
pub let disable_paste : String = "\u{1b}[?2004l"

///|
pub let enable_focus : String = "\u{1b}[?1004h"

///|
pub let disable_focus : String = "\u{1b}[?1004l"

///|
pub let enable_resize : String = "\u{1b}[?2048h"

///|
pub let disable_resize : String = "\u{1b}[?2048l"

///|
pub fn enter(
  alt~ : Bool = true,
  mouse~ : Bool = true,
  paste~ : Bool = true,
  focus~ : Bool = true,
  resize~ : Bool = true,
) -> String {
  let out = StringBuilder()
  if alt {
    out.write_string(enter_alt)
  }
  if mouse {
    out.write_string(enable_mouse)
  }
  if paste {
    out.write_string(enable_paste)
  }
  if focus {
    out.write_string(enable_focus)
  }
  if resize {
    out.write_string(enable_resize)
  }
  out.write_string("\u{1b}[?25l")
  out.to_string()
}

///|
pub fn leave(
  alt~ : Bool = true,
  mouse~ : Bool = true,
  paste~ : Bool = true,
  focus~ : Bool = true,
  resize~ : Bool = true,
) -> String {
  let out = StringBuilder()
  out.write_string("\u{1b}[?25h")
  if resize {
    out.write_string(disable_resize)
  }
  if focus {
    out.write_string(disable_focus)
  }
  if paste {
    out.write_string(disable_paste)
  }
  if mouse {
    out.write_string(disable_mouse)
  }
  if alt {
    out.write_string(leave_alt)
  }
  out.to_string()
}
