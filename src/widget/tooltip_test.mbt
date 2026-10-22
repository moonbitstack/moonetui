// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "tooltip wraps its content inside its padding" {
  let tip : &@widget.Widget = @widget.Tooltip::new("hello world")
  assert_eq(rows(tip, size(12, 6)), [
    "            ", "  hello     ", "  world     ", "            ", "            ",
    "            ",
  ])
  assert_eq(tip.hint(size(80, 24)), size(15, 3))
  assert_eq(tip.focusable(), false)
  assert_eq(press(tip, 1, size(12, 4), key(Down)), [])
}
