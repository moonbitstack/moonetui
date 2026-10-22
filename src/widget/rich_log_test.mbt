// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "rich log writes padded strips" {
  let log = @widget.RichLog::new(min_width=6)
  log.write("hi")
  log.write("there\nfriend")
  assert_eq(log.line_count(), 3)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(5, 5)), ["hi   ", "there", "frien", "     ", "     "])
}

///|
test "rich log wraps words when asked" {
  let log = @widget.RichLog::new(min_width=8, wrap=true)
  log.write("aaa bbb ccc", width=Some(8))
  assert_eq(log.line_count(), 2)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(8, 4)), [
    "aaa bbb ", "ccc     ", "        ", "        ",
  ])
}

///|
test "rich log honours a caller width" {
  let log = @widget.RichLog::new()
  log.write("abcdef", width=Some(3))
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(4, 2)), ["abc ", "    "])
  assert_eq(log.hint(size(80, 24)), size(3, 1))
}

///|
test "rich log prunes and clears" {
  let log = @widget.RichLog::new(max_lines=Some(2))
  for i in 0..<4 {
    log.write("n\{i}")
  }
  assert_eq(log.line_count(), 2)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(3, 2)), ["n2 ", "n3 "])
  log.clear()
  assert_eq(log.line_count(), 0)
  assert_eq(rows(w, size(3, 2)), ["   ", "   "])
}

///|
test "rich log follows the tail like the plain log" {
  let log = @widget.RichLog::new(min_width=1)
  for i in 0..<4 {
    log.write("\{i}")
  }
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(2, 2)), ["2 ", "3 "])
  log.set_auto_scroll(false)
  log.write("9")
  assert_eq(rows(w, size(2, 2)), ["2 ", "3 "])
}
