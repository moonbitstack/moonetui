// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a frame draws its own edges and wraps the row it is given" {
  let inner = @strip.Strip::of("ab", plain)
  let at = size(6, 3)
  assert_eq(
    @widget.frame(@widget.thin, 0, at, plain, inner).text(),
    "┌────┐",
  )
  assert_eq(
    @widget.frame(@widget.thin, 1, at, plain, inner).text(),
    "│ab  │",
  )
  assert_eq(
    @widget.frame(@widget.thin, 2, at, plain, inner).text(),
    "└────┘",
  )
}

///|
test "focus reaches a widget as a message it can act on" {
  let b = @widget.Button::new("Go")
  let w : &@widget.Widget = b
  assert_eq(press(w, 2, size(6, 1), @widget.Msg::Focus(true)), [Repaint(id=2)])
  assert_eq(b.has_focus(), true)
}
