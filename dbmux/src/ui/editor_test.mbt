// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "insert mode types, and escape comes back to normal" {
  let editor = @ui.Editor::new()
  ignore(editor.press("i"))
  assert_eq(editor.is_insert(), true)
  for key in ["s", "e", "l"] {
    ignore(editor.press(key))
  }
  editor.insert_text("ect 1")
  assert_eq(editor.text(), "select 1")
  ignore(editor.press("esc"))
  assert_eq(editor.is_insert(), false)
}

///|
test "a new line opens below, and the buffer keeps both" {
  let editor = @ui.Editor::new()
  editor.set_text("select 1\nselect 2")
  ignore(editor.press("j"))
  ignore(editor.press("o"))
  editor.insert_text("select 3")
  assert_eq(editor.text(), "select 1\nselect 2\nselect 3")
}

///|
test "dd takes a line, p puts it back below the cursor" {
  let editor = @ui.Editor::new()
  editor.set_text("one\ntwo\nthree")
  ignore(editor.press("d"))
  ignore(editor.press("d"))
  assert_eq(editor.text(), "two\nthree")
  ignore(editor.press("p"))
  assert_eq(editor.text(), "two\none\nthree")
}

///|
test "u takes the last change back" {
  let editor = @ui.Editor::new()
  editor.set_text("abc")
  ignore(editor.press("$"))
  ignore(editor.press("x"))
  assert_eq(editor.text(), "ab")
  ignore(editor.press("u"))
  assert_eq(editor.text(), "abc")
}

///|
test "w jumps a word and b comes back" {
  let editor = @ui.Editor::new()
  editor.set_text("select * from orders")
  ignore(editor.press("w"))
  ignore(editor.press("w"))
  ignore(editor.press("b"))
  assert_eq(editor.is_insert(), false)
}

///|
test "a key the editor does not know is left to the pane" {
  let editor = @ui.Editor::new()
  assert_eq(editor.press("C-r"), false)
  assert_eq(editor.press("enter"), false)
}
