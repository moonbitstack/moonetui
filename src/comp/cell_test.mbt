// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "columns carry wide characters as a pair" {
  let columns = @comp.cells(@strip.Strip::of("a中b", plain))
  assert_eq(columns.length(), 4)
  assert_eq(columns[0].text, "a")
  assert_eq(columns[1].text, "中")
  assert_eq(columns[2].continuation, true)
  assert_eq(columns[3].text, "b")
}

///|
test "a combining mark rides along with the column before it" {
  let columns = @comp.cells(@strip.Strip::of("e\u{301}x", plain))
  assert_eq(columns.length(), 2)
  assert_eq(columns[0].text, "e\u{301}")
  assert_eq(columns[1].text, "x")
}

///|
test "rebuilding a range substitutes a space for a halved character" {
  let columns = @comp.cells(@strip.Strip::of("中文", plain))
  assert_eq(@comp.line_of(columns[0:4], plain).text(), "中文")
  assert_eq(@comp.line_of(columns[1:4], plain).text(), " 文")
  assert_eq(@comp.line_of(columns[0:3], plain).text(), "中 ")
}

///|
test "control characters never reach the terminal" {
  let columns = @comp.cells(
    @strip.Strip::of("a\u{1b}[2Jb\r\tc\u{7f}\u{9b}d", plain),
  )
  assert_eq(columns.map(c => c.text), ["a", "[", "2", "J", "b", "c", "d"])
}
