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

///|
test "a header takes a clock as it is, and none when it is not given" {
  let head = @widget.Header::new(
    "moonetui",
    clock=@widget.Clock::new(hour=1, minute=2, second=3),
  )
  assert_eq(head.time(), Some("01:02:03"))
  assert_eq(@widget.Header::new("moonetui").time(), None)
  assert_eq(@widget.Header::new("moonetui", note="v1").time(), None)
}
