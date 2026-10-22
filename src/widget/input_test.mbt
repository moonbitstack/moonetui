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

///|
fn typed(text : String) -> @widget.Input {
  let field = @widget.Input::new()
  field.set(text)
  field
}

///|
fn chord(code : @event.KeyCode) -> @widget.Msg {
  Key(@event.Key::with_mods(code, { ctrl: true, alt: false, shift: false, }))
}

///|
test "control moves the input cursor a word at a time" {
  let field = typed("one two  three")
  let w : &@widget.Widget = field
  let at = size(20, 1)
  ignore(press(w, 1, at, chord(Left)))
  assert_eq(field.cursor(), 9)
  ignore(press(w, 1, at, chord(Left)))
  assert_eq(field.cursor(), 4)
  ignore(press(w, 1, at, chord(Right)))
  assert_eq(field.cursor(), 7)
  ignore(press(w, 1, at, chord(Char(97))))
  assert_eq(field.cursor(), 0)
  ignore(press(w, 1, at, chord(Char(101))))
  assert_eq(field.cursor(), 14)
}

///|
test "the input deletes words and halves of the line on control keys" {
  let at = size(20, 1)
  let field = typed("one two three")
  let w : &@widget.Widget = field
  assert_eq(press(w, 1, at, chord(Char(119))), [
    Changed(id=1, value="one two "),
    Repaint(id=1),
  ])
  field.set("one two three")
  ignore(press(w, 1, at, key(Home)))
  ignore(press(w, 1, at, chord(Char(102))))
  assert_eq(field.text(), " two three")
  ignore(press(w, 1, at, chord(Char(100))))
  assert_eq(field.text(), "two three")
  ignore(press(w, 1, at, key(Right)))
  ignore(press(w, 1, at, chord(Char(107))))
  assert_eq(field.text(), "t")
  field.set("one two")
  ignore(press(w, 1, at, key(Left)))
  ignore(press(w, 1, at, chord(Char(117))))
  assert_eq(field.text(), "o")
  assert_eq(field.cursor(), 0)
}

///|
test "a paste into an input keeps only its first line" {
  let field = @widget.Input::new()
  let w : &@widget.Widget = field
  ignore(press(w, 1, size(10, 1), Paste("first\nsecond")))
  assert_eq(field.text(), "first")
}

///|
test "a password input shows dots and a limited one stops at its limit" {
  let secret = @widget.Input::new(password=true)
  secret.set("abc")
  let w : &@widget.Widget = secret
  assert_eq(w.render_line(0, size(5, 1)).text(), "•••  ")
  let short = @widget.Input::new(max_length=3)
  let s : &@widget.Widget = short
  for c in [97, 98, 99, 100] {
    ignore(press(s, 1, size(5, 1), key(Char(c))))
  }
  assert_eq(short.text(), "abc")
  ignore(press(s, 1, size(5, 1), Paste("xyz")))
  assert_eq(short.text(), "abc")
}
