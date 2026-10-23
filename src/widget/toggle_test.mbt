// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a checkbox shows its mark with the label padded around it" {
  let off : &@widget.Widget = @widget.Checkbox::new("frozen")
  assert_eq(off.render_line(0, size(16, 1)).text(), "▐X▌ frozen      ")
  assert_eq(off.hint(size(80, 24)), size(11, 1))
  let on = @widget.Checkbox::new("frozen", value=true)
  assert_eq(on.render_line(0, size(11, 1)).text(), "▐X▌ frozen ")
}

///|
test "a checkbox can put the button after the label" {
  let late = @widget.Checkbox::new("frozen", button_first=false)
  assert_eq(late.render_line(0, size(16, 1)).text(), " frozen ▐X▌     ")
}

///|
test "a checkbox with no label draws only the button" {
  let bare = @widget.Checkbox::new("")
  assert_eq(bare.render_line(0, size(8, 1)).text(), "▐X▌     ")
  assert_eq(bare.hint(size(80, 24)), size(3, 1))
}

///|
test "space, enter and a click all toggle a checkbox and report it" {
  let box_ = @widget.Checkbox::new("frozen")
  let out = press(box_, 1, size(16, 1), key(Char(32)))
  assert_eq(out, [@widget.Toggled(id=1, on=true), Repaint(id=1)])
  assert_true(box_.value())
  press(box_, 1, size(16, 1), key(Enter)) |> ignore
  assert_false(box_.value())
  let click = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 0,
    y: 0,
    mods: @event.none,
  })
  let out = press(box_, 1, size(16, 1), click)
  assert_eq(out, [
    @widget.TakeFocus(id=1),
    @widget.Toggled(id=1, on=true),
    Repaint(id=1),
  ])
}

///|
test "a checkbox takes focus and restyles its label" {
  let box_ = @widget.Checkbox::new("frozen")
  let out = press(box_, 1, size(16, 1), Focus(true))
  assert_eq(out, [Repaint(id=1)])
  let strip = box_.render_line(0, size(11, 1))
  assert_eq(strip.segs[1].style.attrs.reverse, true)
}

///|
test "a radio button shows a dot instead of the cross" {
  let off : &@widget.Widget = @widget.RadioButton::new("one")
  assert_eq(off.render_line(0, size(12, 1)).text(), "▐●▌ one     ")
  assert_eq(off.hint(size(80, 24)), size(8, 1))
}

///|
test "a radio button turns on and stays on" {
  let radio = @widget.RadioButton::new("one")
  press(radio, 2, size(12, 1), key(Char(32))) |> ignore
  assert_true(radio.value())
  let out = press(radio, 2, size(12, 1), key(Char(32)))
  assert_eq(out.length(), 1)
  assert_true(radio.value())
}

///|
test "a checkbox changes label and value by call, and draws one line" {
  let box = @widget.Checkbox::new("old")
  box.set_label("new")
  assert_eq(box.label(), "new")
  box.set_value(true)
  assert_eq(box.value(), true)
  let w : &@widget.Widget = box
  assert_eq(rows(w, size(10, 2)), ["▐X▌ new   ", "          "])
}

///|
test "a checkbox ignores other keys, other mouse events and pastes" {
  let w : &@widget.Widget = @widget.Checkbox::new("a")
  let at = size(8, 1)
  assert_eq(feed(w, at, key(Char(97))), (false, []))
  assert_eq(feed(w, at, mouse(Move, 0, 0)), (false, []))
  assert_eq(feed(w, at, Paste(" ")), (false, []))
}

///|
test "a radio button changes label by call, takes focus, and turns on from a click" {
  let radio = @widget.RadioButton::new("old")
  radio.set_label("new")
  assert_eq(radio.label(), "new")
  let w : &@widget.Widget = radio
  let at = size(10, 2)
  assert_eq(rows(w, at)[1], "          ")
  let blurred = w.render_line(0, at)
  assert_eq(feed(w, at, Focus(true)), (true, [Repaint(id=1)]))
  assert_eq(w.render_line(0, at) != blurred, true)
  assert_eq(feed(w, at, mouse(Down, 0, 0)).1.contains(TakeFocus(id=1)), true)
  assert_eq(radio.value(), true)
  assert_eq(feed(w, at, mouse(Move, 0, 0)), (false, []))
  assert_eq(feed(w, at, key(Char(97))), (false, []))
  assert_eq(feed(w, at, Paste("x")), (false, []))
  assert_eq(w.focusable(), true)
}
