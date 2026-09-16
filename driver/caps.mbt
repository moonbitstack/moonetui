// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Switch to the alternate screen, so the shell's scrollback survives the run.
pub let enter_alt : String = "\u{1b}[?1049h"

///|
pub let leave_alt : String = "\u{1b}[?1049l"

///|
/// Report button presses, motion, and do it in the SGR encoding, which is the
/// only one that survives past column 223.
pub let enable_mouse : String = "\u{1b}[?1000h\u{1b}[?1003h\u{1b}[?1006h"

///|
pub let disable_mouse : String = "\u{1b}[?1006l\u{1b}[?1003l\u{1b}[?1000l"

///|
/// Wrap pasted text in markers, so it is not mistaken for someone typing.
pub let enable_paste : String = "\u{1b}[?2004h"

///|
pub let disable_paste : String = "\u{1b}[?2004l"

///|
/// Report when the window gains or loses focus.
pub let enable_focus : String = "\u{1b}[?1004h"

///|
pub let disable_focus : String = "\u{1b}[?1004l"

///|
/// Ask the terminal to report size changes in band. A browser and a Windows
/// console have no signal to send, so this is the only report that works
/// everywhere the library runs.
pub let enable_resize : String = "\u{1b}[?2048h"

///|
pub let disable_resize : String = "\u{1b}[?2048l"

///|
/// What an application sends on the way in. The parts are optional because a
/// program that never reads the mouse should not make the terminal send mouse
/// reports, and because a pipe — a test harness, a recording — wants none of it.
pub fn enter(
  alt? : Bool = true,
  mouse? : Bool = true,
  paste? : Bool = true,
  focus? : Bool = true,
  resize? : Bool = true,
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
/// What it sends on the way out, in the reverse order, so the terminal unwinds
/// exactly what was set.
pub fn leave(
  alt? : Bool = true,
  mouse? : Bool = true,
  paste? : Bool = true,
  focus? : Bool = true,
  resize? : Bool = true,
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
