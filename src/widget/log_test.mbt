// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "log writes lines and renders them" {
  let log = @widget.Log::new()
  log.write_line("hello")
  log.write_line("world")
  assert_eq(log.line_count(), 2)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(7, 4)), ["hello  ", "world  ", "       ", "       "])
  assert_eq(log.hint(size(80, 24)), size(5, 2))
}

///|
test "log write accumulates partial lines" {
  let log = @widget.Log::new()
  log.write("ab")
  log.write("cd\n")
  log.write("ef")
  assert_eq(log.lines(), ["abcd", "ef"])
  assert_eq(log.line_count(), 2)
  log.write("gh\r\nij")
  assert_eq(log.lines(), ["abcd", "efgh", "ij"])
}

///|
test "log scrubs control codes and expands tabs" {
  let log = @widget.Log::new()
  log.write_line("\u{1}x\ry")
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(10, 1)), ["\u{FFFD}x\u{FFFD}y      "])
  log.clear()
  log.write_line("\tab")
  assert_eq(rows(w, size(10, 1)), ["        ab"])
}

///|
test "log follows the tail and lets the reader pull free" {
  let log = @widget.Log::new()
  for i in 0..<3 {
    log.write_line("line\{i}")
  }
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(6, 3)), ["line0 ", "line1 ", "line2 "])
  log.write_line("line3")
  log.write_line("line4")
  assert_eq(rows(w, size(6, 3)), ["line2 ", "line3 ", "line4 "])
  assert_eq(log.offset(), (0, 2))
  ignore(press(w, 1, size(6, 3), key(Up)))
  log.write_line("line5")
  assert_eq(rows(w, size(6, 3)), ["line1 ", "line2 ", "line3 "])
  ignore(press(w, 1, size(6, 3), key(End)))
  assert_eq(rows(w, size(6, 3)), ["line3 ", "line4 ", "line5 "])
  ignore(press(w, 1, size(6, 3), key(Home)))
  assert_eq(rows(w, size(6, 3)), ["line0 ", "line1 ", "line2 "])
}

///|
test "log scroll_end overrides auto scroll" {
  let log = @widget.Log::new()
  log.write_line("one")
  log.write_line("two", scroll_end=false)
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(6, 1)), ["one   "])
  log.write_line("three", scroll_end=true)
  assert_eq(rows(w, size(6, 1)), ["three "])
}

///|
test "log prunes to max_lines" {
  let log = @widget.Log::new(max_lines=2)
  for i in 0..<5 {
    log.write_line("nope\{i}")
  }
  assert_eq(log.lines(), ["nope3", "nope4"])
  assert_eq(log.line_count(), 2)
}

///|
test "log scrolls sideways" {
  let log = @widget.Log::new()
  log.write_line("abcdefgh")
  let w : &@widget.Widget = log
  assert_eq(rows(w, size(4, 1)), ["abcd"])
  ignore(press(w, 1, size(4, 1), key(Right)))
  assert_eq(rows(w, size(4, 1)), ["bcde"])
  assert_eq(log.offset(), (1, 0))
}

///|
test "log takes focus on click and answers the wheel" {
  let log = @widget.Log::new()
  log.write_line("a")
  log.write_line("b")
  log.write_line("c")
  log.write_line("d")
  let w : &@widget.Widget = log
  let out = press(
    w,
    7,
    size(4, 2),
    Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [@widget.TakeFocus(id=7)])
  ignore(press(w, 7, size(4, 2), key(Home)))
  assert_eq(rows(w, size(4, 2)), ["a   ", "b   "])
  ignore(
    press(
      w,
      7,
      size(4, 2),
      Mouse({ kind: ScrollDown, button: 0, x: 0, y: 0, mods: @event.none, }),
    ),
  )
  assert_eq(rows(w, size(4, 2)), ["b   ", "c   "])
  ignore(
    press(
      w,
      7,
      size(4, 2),
      Mouse({ kind: ScrollUp, button: 0, x: 0, y: 0, mods: @event.none, }),
    ),
  )
  assert_eq(rows(w, size(4, 2)), ["a   ", "b   "])
}

///|
test "log keys page and pan through what it holds" {
  let log = @widget.Log::new()
  for i in 0..<10 {
    log.write_line("line \{i} is long")
  }
  let w : &@widget.Widget = log
  let at = size(6, 4)
  ignore(rows(w, at))
  ignore(feed(w, at, key(PageUp)))
  ignore(feed(w, at, key(PageUp)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 0))
  ignore(feed(w, at, key(PageDown)))
  ignore(feed(w, at, key(Down)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 4))
  ignore(feed(w, at, key(Right)))
  ignore(feed(w, at, key(Right)))
  ignore(feed(w, at, key(Left)))
  ignore(feed(w, at, mouse(ScrollRight, 0, 0)))
  ignore(feed(w, at, mouse(ScrollRight, 0, 0)))
  ignore(feed(w, at, mouse(ScrollLeft, 0, 0)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (2, 4))
  log.set_auto_scroll(false)
  let ctrl = @event.Mods::of_param(5)
  assert_eq(feed(w, at, Key(@event.Key::with_mods(Up, ctrl))), (false, []))
  assert_eq(feed(w, at, key(Enter)), (false, []))
  assert_eq(feed(w, at, mouse(Move, 0, 0)), (false, []))
  assert_eq(feed(w, at, Paste("x")), (false, []))
}

///|
test "log pages by one row in a one-row view" {
  let log = @widget.Log::new()
  for i in 0..<5 {
    log.write_line("\{i}")
  }
  let w : &@widget.Widget = log
  let at = size(4, 1)
  ignore(rows(w, at))
  ignore(feed(w, at, key(PageUp)))
  ignore(rows(w, at))
  assert_eq(log.offset(), (0, 3))
}
