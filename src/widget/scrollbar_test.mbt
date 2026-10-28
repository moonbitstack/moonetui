// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a vertical scrollbar draws its thumb over the track" {
  let bar = @widget.Scrollbar::new(content=20, viewport=10, position=0)
  let lines = rows(bar, size(1, 10))
  assert_eq(lines.length(), 10)
  assert_eq(lines.iter().any(fn(l) { l.contains("█") }), true)
  assert_eq(lines.iter().any(fn(l) { l.contains("░") }), true)
  assert_eq(bar.thumb(10), (0, 5))
  assert_eq(bar.is_needed(), true)
  assert_eq(bar.max(), 10)
}

///|
test "a scrollbar moves by a line and a view and reports where it went" {
  let bar = @widget.Scrollbar::new(content=20, viewport=10, position=0)
  let down = press(bar, 1, size(1, 10), key(Down))
  assert_eq(bar.position(), 1)
  assert_eq(down.contains(@widget.Scrolled(id=1, x=0, y=1)), true)
  let page = press(bar, 1, size(1, 10), key(PageDown))
  assert_eq(bar.position(), 10)
  assert_eq(page.contains(@widget.Scrolled(id=1, x=0, y=10)), true)
  let home = press(bar, 1, size(1, 10), key(Home))
  assert_eq(bar.position(), 0)
  ignore(home)
}

///|
test "a scrollbar goes to a click on the track and takes focus" {
  let bar = @widget.Scrollbar::new(content=20, viewport=10, position=0)
  let clicked = press(bar, 1, size(1, 10), mouse(Down, 0, 9))
  assert_eq(bar.position(), 10)
  assert_eq(clicked.contains(@widget.TakeFocus(id=1)), true)
  assert_eq(clicked.contains(@widget.Scrolled(id=1, x=0, y=10)), true)
}

///|
test "a horizontal scrollbar moves along its row" {
  let bar = @widget.Scrollbar::new(
    content=20,
    viewport=10,
    position=0,
    vertical=false,
  )
  assert_eq(bar.is_vertical(), false)
  let right = press(bar, 1, size(10, 1), key(Right))
  assert_eq(bar.position(), 1)
  assert_eq(right.contains(@widget.Scrolled(id=1, x=1, y=0)), true)
}

///|
test "a scrollbar with nothing to scroll stays put" {
  let bar = @widget.Scrollbar::new(content=5, viewport=10)
  assert_eq(bar.is_needed(), false)
  assert_eq(bar.thumb(10), (0, 10))
  let moved = press(bar, 1, size(1, 10), key(Down))
  assert_eq(bar.position(), 0)
  assert_eq(moved, [])
}
