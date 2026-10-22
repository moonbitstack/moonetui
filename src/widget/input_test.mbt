// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "typing into an input edits it and reports the new value" {
  let input = @widget.Input::new()
  let w : &@widget.Widget = input
  let at = size(10, 1)
  assert_eq(press(w, 5, at, @widget.Msg::Key(@event.Key::char(104))), [
    Changed(id=5, value="h"),
    Repaint(id=5),
  ])
  w.handle(@widget.Ctx::new(5, at), @widget.Msg::Key(@event.Key::char(105)))
  |> ignore
  assert_eq(input.text(), "hi")
  assert_eq(input.cursor(), 2)
}

///|
test "backspace and delete take whole characters, surrogate pairs included" {
  let input = @widget.Input::new()
  input.set("a😀b")
  let w : &@widget.Widget = input
  let at = size(10, 1)
  w.handle(@widget.Ctx::new(1, at), key(Backspace)) |> ignore
  assert_eq(input.text(), "a😀")
  w.handle(@widget.Ctx::new(1, at), key(Backspace)) |> ignore
  assert_eq(input.text(), "a")
  input.set("xy")
  w.handle(@widget.Ctx::new(1, at), key(Home)) |> ignore
  w.handle(@widget.Ctx::new(1, at), key(Delete)) |> ignore
  assert_eq(input.text(), "y")
}

///|
test "the arrows move the cursor and home and end jump" {
  let input = @widget.Input::new()
  input.set("abc")
  let w : &@widget.Widget = input
  let at = size(10, 1)
  w.handle(@widget.Ctx::new(1, at), key(Left)) |> ignore
  assert_eq(input.cursor(), 2)
  w.handle(@widget.Ctx::new(1, at), key(Home)) |> ignore
  assert_eq(input.cursor(), 0)
  w.handle(@widget.Ctx::new(1, at), key(Right)) |> ignore
  assert_eq(input.cursor(), 1)
  w.handle(@widget.Ctx::new(1, at), key(End)) |> ignore
  assert_eq(input.cursor(), 3)
}

///|
test "a paste lands in the input in one piece" {
  let input = @widget.Input::new()
  let w : &@widget.Widget = input
  let asked = press(w, 9, size(10, 1), @widget.Msg::Paste("hello"))
  assert_eq(input.text(), "hello")
  assert_eq(asked[0], Changed(id=9, value="hello"))
}

///|
test "an empty unfocused input shows its placeholder" {
  let input = @widget.Input::new(placeholder="name")
  let w : &@widget.Widget = input
  assert_eq(w.render_line(0, size(8, 1)).text(), "name    ")
  w.handle(@widget.Ctx::new(1, size(8, 1)), @widget.Msg::Focus(true)) |> ignore
  assert_eq(w.render_line(0, size(8, 1)).text(), "        ")
}

///|
test "a long input scrolls to keep the cursor visible" {
  let input = @widget.Input::new()
  input.set("abcdefghij")
  let w : &@widget.Widget = input
  assert_eq(w.render_line(0, size(5, 1)).text(), "ghij ")
  assert_eq(input.cursor_column(5), 4)
}
