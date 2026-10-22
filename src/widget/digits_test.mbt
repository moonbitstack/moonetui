// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "digits draws three rows of glyphs" {
  let digits = @widget.Digits::new(value="12:34")
  assert_eq(@widget.Digits::width_of("12:34"), 15)
  let w : &@widget.Widget = digits
  assert_eq(rows(w, size(15, 3)), [
    "╶╮ ╶─╮   ╶─╮╷ ╷", " │ ┌─┘ :  ─┤╰─┤", "╶┴╴╰─╴   ╶─╯  ╵",
  ])
  assert_eq(w.hint(size(80, 24)), size(15, 3))
  digits.update("20")
  assert_eq(rows(w, size(6, 3)), [
    "╶─╮╭─╮", "┌─┘│ │", "╰─╴╰─╯",
  ])
}

///|
test "digits goes bold and passes strangers through" {
  let bold = @widget.Digits::new(value="0", style=@style.Style::new(bold=true))
  let w : &@widget.Widget = bold
  assert_eq(rows(w, size(3, 3)), ["┏━┓", "┃ ┃", "┗━┛"])
  let mixed = @widget.Digits::new(value="1.5")
  assert_eq(@widget.Digits::width_of("1.5"), 7)
  let m : &@widget.Widget = mixed
  assert_eq(rows(m, size(7, 3)), [
    "╶╮  ╭─╴", " │  ╰─╮", "╶┴╴•╶─╯",
  ])
  assert_eq(rows(m, size(20, 3))[0], "╶╮  ╭─╴             ")
}
