// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a masked input shows its template and fills the places" {
  let field = @widget.MaskedInput::new("##-##")
  assert_eq(field.text(), "__-__")
  let out = press(field, 1, size(20, 1), key(Char(0x31)))
  assert_eq(field.text(), "1_-__")
  assert_eq(field.cursor(), 1)
  ignore(out)
  let out2 = press(field, 1, size(20, 1), key(Char(0x32)))
  assert_eq(field.text(), "12-__")
  ignore(out2)
}

///|
test "a masked input submits and moves with the arrows and backspace" {
  let field = @widget.MaskedInput::new("##-##")
  ignore(press(field, 1, size(20, 1), key(Char(0x31))))
  ignore(press(field, 1, size(20, 1), key(Char(0x32))))
  ignore(press(field, 1, size(20, 1), key(Char(0x33))))
  ignore(press(field, 1, size(20, 1), key(Char(0x34))))
  assert_eq(field.text(), "12-34")
  assert_eq(field.is_complete(), true)
  let back = press(field, 1, size(20, 1), key(Backspace))
  assert_eq(field.text(), "12-3_")
  ignore(back)
  let left = press(field, 1, size(20, 1), key(Left))
  assert_eq(field.cursor(), 2)
  ignore(left)
  let enter = press(field, 1, size(20, 1), key(Enter))
  assert_eq(enter.contains(@widget.Submitted(id=1, value="12-3_")), true)
  ignore(enter)
}

///|
test "a masked input moves its caret to a click" {
  let field = @widget.MaskedInput::new("##-##")
  let clicked = press(field, 1, size(20, 1), mouse(Down, 3, 0))
  assert_eq(field.cursor(), 2)
  ignore(clicked)
}

///|
test "a masked input fills from a whole value and clears" {
  let field = @widget.MaskedInput::new("##-##")
  field.set("5678")
  assert_eq(field.text(), "56-78")
  assert_eq(field.is_complete(), true)
  field.clear()
  assert_eq(field.text(), "__-__")
  assert_eq(field.is_complete(), false)
}
