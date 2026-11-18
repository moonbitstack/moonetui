// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// What every example's frame test hands to the terminal check in CI: one
// line per frame, the bytes written and the rows they must show.

///|
/// The UTF-16 units of `text` as hex, so what this test hands over survives the
/// trip through a test runner unchanged.
fn hex16(text : String) -> String {
  let out = StringBuilder()
  let digit = fn(v : Int32) {
    if v < 10 {
      (48 + v).unsafe_to_char()
    } else {
      (97 + v - 10).unsafe_to_char()
    }
  }
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    out.write_char(digit(unit / 0x1000 % 16))
    out.write_char(digit(unit / 0x100 % 16))
    out.write_char(digit(unit / 0x10 % 16))
    out.write_char(digit(unit % 16))
  }
  out.to_string()
}

///|
/// Whether the frames are announced at all. `moon test` prints what it was
/// asked for — a report — and a frame is tens of kilobytes of hex, which is
/// noise in a terminal that only wanted the count. CI sets `MOONETUI_INTEROP`
/// and reads the lines from there.
fn interop_wanted() -> Bool {
  match @env.get_env_var("MOONETUI_INTEROP") {
    Some(_) => true
    None => false
  }
}

///|
/// Announces one frame of the demo: its name, the emulators that can model it,
/// the bytes written since the demo started, and the rows it is meant to show.
/// `scripts/verify_terminals.py` replays those bytes in two terminal emulators
/// this repository has no part in; what they show has to be these rows.
pub fn announce(
  name : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  if !interop_wanted() {
    return
  }
  let line = StringBuilder()
  line.write_string(
    "interop\t" +
    name +
    "\tpyte,tmux\t" +
    size.width.to_string() +
    "\t" +
    size.height.to_string() +
    "\t" +
    hex16(stream),
  )
  for row in rows {
    line.write_string("\t" + hex16(row))
  }
  println(line.to_string())
}
