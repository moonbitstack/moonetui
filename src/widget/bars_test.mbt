// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the header centres its title and keeps the note on the right" {
  let head = @widget.Header::new("moonetui", note="v0")
  let w : &@widget.Widget = head
  assert_eq(w.render_line(0, size(14, 1)).text(), "  moonetui  v0")
  head.set("short")
  head.set_note("")
  assert_eq(w.render_line(0, size(11, 1)).text(), "   short   ")
}

///|
test "the footer lists what it can fit and drops the rest" {
  let foot = @widget.Footer::new([("q", "quit"), ("?", "help")])
  let w : &@widget.Widget = foot
  assert_eq(w.render_line(0, size(20, 1)).text(), " q quit  ? help     ")
  assert_eq(w.render_line(0, size(8, 1)).text(), " q quit ")
}
