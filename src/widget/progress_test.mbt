// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a progress bar fills in eighths and prints its percentage" {
  let bar = @widget.Progress::new(total=8)
  let w : &@widget.Widget = bar
  bar.set(4)
  assert_eq(bar.percent(), 50)
  assert_eq(w.render_line(0, size(8, 1)).text(), "██   50%")
  bar.advance(4)
  assert_eq(bar.percent(), 100)
  assert_eq(w.render_line(0, size(9, 1)).text(), "████ 100%")
}

///|
test "a bar clamps rather than overflowing" {
  let bar = @widget.Progress::new(total=10)
  bar.set(99)
  assert_eq(bar.percent(), 100)
  bar.set(-5)
  assert_eq(bar.percent(), 0)
  bar.set_total(0)
  assert_eq(bar.percent(), 0)
}
