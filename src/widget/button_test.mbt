// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a button centres its label and asks for room around it" {
  let b = @widget.Button::new("Save")
  let w : &@widget.Widget = b
  assert_eq(w.hint(size(80, 24)), size(8, 1))
  assert_eq(w.render_line(0, size(8, 1)).text(), "  Save  ")
  assert_eq(w.focusable(), true)
}

///|
test "enter and space press a button, other keys do not" {
  let b = @widget.Button::new("Go")
  let w : &@widget.Widget = b
  assert_eq(press(w, 7, size(6, 1), key(Enter)), [Pressed(id=7)])
  assert_eq(press(w, 7, size(6, 1), @widget.Msg::Key(@event.Key::char(32))), [
    Pressed(id=7),
  ])
  assert_eq(press(w, 7, size(6, 1), key(Down)), [])
}

///|
test "clicking a button takes focus and presses it" {
  let b = @widget.Button::new("Go")
  let w : &@widget.Widget = b
  let clicked = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 1,
    y: 0,
    mods: @event.none,
  })
  assert_eq(press(w, 3, size(6, 1), clicked), [TakeFocus(id=3), Pressed(id=3)])
}

///|
test "a disabled button neither takes focus nor presses" {
  let b = @widget.Button::new("Go")
  b.disable(true)
  let w : &@widget.Widget = b
  assert_eq(w.focusable(), false)
  assert_eq(press(w, 1, size(6, 1), key(Enter)), [])
  assert_eq(b.is_disabled(), true)
}
