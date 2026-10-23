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
  log.write("aaa bbb ccc", width=8)
  assert_eq(log.line_count(), 2)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(8, 4)), [
    "aaa bbb ", "ccc     ", "        ", "        ",
  ])
}

///|
test "rich log honours a caller width" {
  let log = @widget.RichLog::new()
  log.write("abcdef", width=3)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(4, 2)), ["abc ", "    "])
  assert_eq(log.hint(size(80, 24)), size(3, 1))
}

///|
test "rich log prunes and clears" {
  let log = @widget.RichLog::new(max_lines=2)
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

///|
fn numbered(count : Int32) -> @widget.RichLog {
  let log = @widget.RichLog::new(min_width=4)
  for i in 0..<count {
    log.write("l\{i}")
  }
  log
}

///|
test "rich log keys scroll it, and reaching the end sticks again" {
  let log = numbered(10)
  let w : &@widget.Widget = log
  let at = size(4, 3)
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 7))
  assert_eq(feed(w, at, key(Up)), (true, [Repaint(id=1)]))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 6))
  log.write("l10")
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 6))
  ignore(feed(w, at, key(PageUp)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 4))
  ignore(feed(w, at, key(Home)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 0))
  ignore(feed(w, at, key(PageDown)))
  ignore(feed(w, at, key(Down)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 3))
  ignore(feed(w, at, key(End)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 8))
  log.write("l11")
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 9))
}

///|
test "rich log left and right pan across a wide line" {
  let log = @widget.RichLog::new(min_width=1)
  log.write("abcdefgh")
  let w : &@widget.Widget = log
  let at = size(4, 1)
  assert_eq(rows(w, at), ["abcd"])
  ignore(feed(w, at, key(Right)))
  ignore(feed(w, at, key(Right)))
  assert_eq(rows(w, at), ["cdef"])
  ignore(feed(w, at, key(Left)))
  assert_eq(rows(w, at), ["bcde"])
  for _ in 0..<9 {
    ignore(feed(w, at, key(Right)))
  }
  assert_eq(rows(w, at), ["efgh"])
  for _ in 0..<9 {
    ignore(feed(w, at, key(Left)))
  }
  assert_eq(rows(w, at), ["abcd"])
}

///|
test "rich log leaves modified and unknown keys alone" {
  let w : &@widget.Widget = numbered(3)
  let at = size(4, 2)
  let ctrl_up = @widget.Msg::Key(
    @event.Key::with_mods(Up, @event.Mods::of_param(5)),
  )
  assert_eq(feed(w, at, ctrl_up), (false, []))
  assert_eq(feed(w, at, key(Enter)), (false, []))
  assert_eq(feed(w, at, Paste("x")), (false, []))
}

///|
test "rich log takes focus on a click and scrolls with the wheel" {
  let log = numbered(10)
  log.write("abcdefgh")
  let w : &@widget.Widget = log
  let at = size(4, 3)
  ignore(rows(w, at))
  assert_eq(feed(w, at, mouse(Down, 0, 0)), (true, [TakeFocus(id=1)]))
  assert_eq(feed(w, at, mouse(ScrollUp, 0, 0)), (true, [Repaint(id=1)]))
  ignore(feed(w, at, mouse(ScrollUp, 0, 0)))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  ignore(feed(w, at, mouse(ScrollRight, 0, 0)))
  ignore(feed(w, at, mouse(ScrollRight, 0, 0)))
  ignore(feed(w, at, mouse(ScrollLeft, 0, 0)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (1, 7))
  assert_eq(feed(w, at, mouse(Move, 0, 0)), (false, []))
}

///|
test "rich log pages by one row in a one-row view" {
  let log = numbered(5)
  let w : &@widget.Widget = log
  let at = size(4, 1)
  ignore(rows(w, at))
  ignore(feed(w, at, key(PageUp)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 3))
}

///|
test "rich log writes an empty line, and the caller can pin the view" {
  let log = @widget.RichLog::new(min_width=3)
  log.write("")
  assert_eq(log.line_count(), 1)
  assert_eq(log.lines()[0].text(), "   ")
  log.write("", width=5)
  assert_eq(log.lines()[1].text(), "     ")
  for i in 0..<5 {
    log.write("\{i}")
  }
  let w : &@widget.Widget = log
  let at = size(3, 2)
  ignore(feed(w, at, key(Home)))
  ignore(rows(w, at))
  log.write("x", scroll_end=true)
  assert_eq(rows(w, at), ["4  ", "x  "])
  log.write("y", scroll_end=false)
  assert_eq(rows(w, at), ["4  ", "x  "])
}

///|
test "rich log wraps from the next write, cutting a word too long for a line" {
  let log = @widget.RichLog::new(min_width=4)
  log.write("abcdefghij", width=4)
  assert_eq(log.line_count(), 1)
  log.set_wrap(true)
  log.write("abcdefghij", width=4)
  assert_eq(log.lines().map(s => s.text()), ["abcd", "abcd", "efgh", "ij  "])
}
