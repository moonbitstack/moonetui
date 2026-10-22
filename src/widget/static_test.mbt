// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "static text renders one line per line of text" {
  let s : &@widget.Widget = @widget.Static::new("one\ntwo")
  assert_eq(rows(s, size(5, 3)), ["one  ", "two  ", "     "])
  assert_eq(s.hint(size(80, 24)), size(3, 2))
  assert_eq(s.focusable(), false)
}

///|
test "alignment puts the slack where it was asked for" {
  let left : &@widget.Widget = @widget.Static::new("ab")
  let middle : &@widget.Widget = @widget.Static::new("ab", align=Centre)
  let right : &@widget.Widget = @widget.Static::new("ab", align=Right)
  assert_eq(left.render_line(0, size(6, 1)).text(), "ab    ")
  assert_eq(middle.render_line(0, size(6, 1)).text(), "  ab  ")
  assert_eq(right.render_line(0, size(6, 1)).text(), "    ab")
}

///|
test "text wider than the widget is cut at a character boundary" {
  let s : &@widget.Widget = @widget.Static::new("中文字")
  assert_eq(s.render_line(0, size(5, 1)).text(), "中文 ")
}
