// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let long : Bytes = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

///|
test "a hex view shows offsets, bytes and the same bytes as text" {
  let view = @widget.HexView::new(data=b"Hello, world!")
  assert_eq(
    rows(view, size(80, 1))[0],
    "00000000  48 65 6c 6c 6f 2c 20 77  6f 72 6c 64 21            Hello, world!      ",
  )
  assert_eq(view.hint(size(80, 4)), size(80, 4))
  assert_eq(view.offset(), 0)
}

///|
test "a hex view draws a byte that is not text as a dot" {
  let view = @widget.HexView::new(data=b"ab\x00cd")
  let line = rows(view, size(80, 1))[0]
  assert_eq(line.contains("61 62 00 63 64"), true)
  assert_eq(line.contains("ab.cd"), true)
}

///|
test "a hex view walks a row and a screen and speaks in bytes" {
  let view = @widget.HexView::new(data=long)
  assert_eq(
    press(view, 3, size(80, 4), key(Down))[0],
    Scrolled(id=3, x=0, y=16),
  )
  assert_eq(view.offset(), 16)
  assert_eq(press(view, 3, size(80, 4), key(Up))[0], Scrolled(id=3, x=0, y=0))
  assert_eq(
    press(view, 3, size(80, 4), key(PageDown))[0],
    Scrolled(id=3, x=0, y=48),
  )
  assert_eq(
    press(view, 3, size(80, 4), key(PageUp))[0],
    Scrolled(id=3, x=0, y=0),
  )
  assert_eq(press(view, 3, size(80, 4), key(End))[0], Scrolled(id=3, x=0, y=48))
  assert_eq(press(view, 3, size(80, 4), key(Home))[0], Scrolled(id=3, x=0, y=0))
  assert_eq(press(view, 3, size(80, 4), key(Up)), [])
}

///|
test "a hex view holds its offset inside the bytes it has" {
  let short = @widget.HexView::new(data=b"Hello, world!", offset=4096)
  assert_eq(short.offset(), 0)
  short.set_offset(-9)
  assert_eq(short.offset(), 0)
  let deep = @widget.HexView::new(data=long, offset=99)
  assert_eq(deep.offset(), 48)
}

///|
test "a narrow hex view shows fewer bytes on a row" {
  let view = @widget.HexView::new(data=b"Hello, world!")
  let line = rows(view, size(60, 1))[0]
  assert_eq(line.has_prefix("00000000  48 65 6c 6c  6f 2c 20 77"), true)
  assert_eq(line.contains("Hello, w"), true)
  assert_eq(line.contains("6c 64"), false)
}

///|
test "the wheel moves a hex view by a row" {
  let view = @widget.HexView::new(data=long)
  assert_eq(
    press(view, 1, size(80, 2), mouse(ScrollDown, 0, 0))[0],
    Scrolled(id=1, x=0, y=16),
  )
  assert_eq(
    press(view, 1, size(80, 2), mouse(ScrollUp, 0, 0))[0],
    Scrolled(id=1, x=0, y=0),
  )
}

///|
test "a hex view paints nothing beyond its bytes and takes focus" {
  let empty = @widget.HexView::new()
  assert_eq(rows(empty, size(20, 1))[0], "                    ")
  let view = @widget.HexView::new(data=b"abc")
  assert_eq(
    rows(view, size(80, 2))[1],
    "                                                                                ",
  )
  assert_eq(view.focusable(), true)
  assert_eq(press(view, 1, size(80, 2), Focus(true)), [Repaint(id=1)])
  assert_eq(press(view, 1, size(80, 2), mouse(Down, 4, 0)), [TakeFocus(id=1)])
}
