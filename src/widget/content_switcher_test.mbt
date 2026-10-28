// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a content switcher shows the child it is on" {
  let switcher = @widget.ContentSwitcher::new(children=[
    @widget.Static::new("first"),
    @widget.Static::new("second"),
  ])
  assert_eq(rows(switcher, size(10, 1))[0].trim_end(), "first")
  switcher.switch_to(1)
  assert_eq(rows(switcher, size(10, 1))[0].trim_end(), "second")
  assert_eq(switcher.current(), 1)
  assert_eq(switcher.count(), 2)
  switcher.switch_to(0)
  assert_eq(rows(switcher, size(10, 1))[0].trim_end(), "first")
}

///|
test "a content switcher holds the index to what is there" {
  let switcher = @widget.ContentSwitcher::new(
    children=[@widget.Static::new("only")],
    current=5,
  )
  assert_eq(switcher.current(), 0)
  switcher.switch_to(-3)
  assert_eq(switcher.current(), 0)
  switcher.switch_to(99)
  assert_eq(switcher.current(), 0)
  let empty = @widget.ContentSwitcher::new(children=[])
  assert_eq(empty.current(), -1)
}

///|
test "a content switcher forwards keys and clicks to the child" {
  let button = @widget.Button::new("Go")
  let switcher = @widget.ContentSwitcher::new(children=[button])
  assert_eq(switcher.focusable(), true)
  let by_key = press(switcher, 2, size(10, 1), key(Enter))
  assert_eq(by_key.contains(@widget.Pressed(id=2)), true)
  let by_click = press(switcher, 2, size(10, 1), mouse(Down, 0, 0))
  assert_eq(by_click.contains(@widget.TakeFocus(id=2)), true)
  assert_eq(by_click.contains(@widget.Pressed(id=2)), true)
}
