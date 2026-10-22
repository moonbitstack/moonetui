// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn toggle_size(width : Int32, height : Int32) -> @geom.Size {
  @geom.Size::new(width, height)
}

///|
test "a checkbox shows its mark with the label padded around it" {
  let off : &@widget.Widget = @widget.Checkbox::new("frozen")
  assert_eq(
    off.render_line(0, toggle_size(16, 1)).text(),
    "▐X▌ frozen      ",
  )
  assert_eq(off.hint(toggle_size(80, 24)), toggle_size(11, 1))
  let on = @widget.Checkbox::new("frozen", value=true)
  assert_eq(on.render_line(0, toggle_size(11, 1)).text(), "▐X▌ frozen ")
}

///|
test "a checkbox can put the button after the label" {
  let late = @widget.Checkbox::new("frozen", button_first=false)
  assert_eq(
    late.render_line(0, toggle_size(16, 1)).text(),
    " frozen ▐X▌     ",
  )
}

///|
test "a checkbox with no label draws only the button" {
  let bare = @widget.Checkbox::new("")
  assert_eq(bare.render_line(0, toggle_size(8, 1)).text(), "▐X▌     ")
  assert_eq(bare.hint(toggle_size(80, 24)), toggle_size(3, 1))
}

///|
test "space, enter and a click all toggle a checkbox and report it" {
  let box_ = @widget.Checkbox::new("frozen")
  let out = press(box_, 1, toggle_size(16, 1), key(Char(32)))
  assert_eq(out, [@widget.Toggled(id=1, on=true), Repaint(id=1)])
  assert_true(box_.value())
  press(box_, 1, toggle_size(16, 1), key(Enter)) |> ignore
  assert_false(box_.value())
  let click = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 0,
    y: 0,
    mods: @event.none,
  })
  let out = press(box_, 1, toggle_size(16, 1), click)
  assert_eq(out, [
    @widget.TakeFocus(id=1),
    @widget.Toggled(id=1, on=true),
    Repaint(id=1),
  ])
}

///|
test "a checkbox takes focus and restyles its label" {
  let box_ = @widget.Checkbox::new("frozen")
  let out = press(box_, 1, toggle_size(16, 1), Focus(true))
  assert_eq(out, [Repaint(id=1)])
  let strip = box_.render_line(0, toggle_size(11, 1))
  assert_eq(strip.segs[1].style.attrs.reverse, true)
}

///|
test "a radio button shows a dot instead of the cross" {
  let off : &@widget.Widget = @widget.RadioButton::new("one")
  assert_eq(off.render_line(0, toggle_size(12, 1)).text(), "▐●▌ one     ")
  assert_eq(off.hint(toggle_size(80, 24)), toggle_size(8, 1))
}

///|
test "a radio button turns on and stays on" {
  let radio = @widget.RadioButton::new("one")
  press(radio, 2, toggle_size(12, 1), key(Char(32))) |> ignore
  assert_true(radio.value())
  let out = press(radio, 2, toggle_size(12, 1), key(Char(32)))
  assert_eq(out.length(), 1)
  assert_true(radio.value())
}

///|
test "a switch is a four-wide strip with the thumb on the side of its value" {
  let off : &@widget.Widget = @widget.Switch::new()
  assert_eq(off.hint(toggle_size(80, 24)), toggle_size(4, 1))
  let on = @widget.Switch::new(value=true)
  let off_thumb = @strip.Strip::blank(
    2,
    @style.Style::new(
      fg=@style.bright_black,
      bg=@style.Colour::rgb(85, 85, 85),
      reverse=true,
    ),
  )
  assert_eq(
    off.render_line(0, toggle_size(4, 1)),
    @strip.Strip::join([
      off_thumb,
      @strip.Strip::blank(
        2,
        @style.Style::new(bg=@style.Colour::rgb(85, 85, 85)),
      ),
    ]),
  )
  ignore(on)
}

///|
test "space and a click toggle a switch and report it" {
  let sw = @widget.Switch::new()
  let out = press(sw, 3, toggle_size(4, 1), key(Enter))
  assert_eq(out, [@widget.Toggled(id=3, on=true), Repaint(id=3)])
  assert_true(sw.value())
  let out = press(sw, 3, toggle_size(4, 1), key(Enter))
  assert_eq(out, [@widget.Toggled(id=3, on=false), Repaint(id=3)])
  assert_false(sw.value())
}

///|
test "a radio set presses one button and turns the others off" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one", value=true),
    @widget.RadioButton::new("two"),
    @widget.RadioButton::new("three"),
  ])
  assert_eq(set.pressed_index(), 0)
  press(set, 5, toggle_size(20, 3), key(Char(32))) |> ignore
  assert_eq(set.pressed_index(), 0)
  press(set, 5, toggle_size(20, 3), key(Down)) |> ignore
  assert_eq(set.selected_index(), 1)
  assert_eq(set.pressed_index(), 0)
  let out = press(set, 5, toggle_size(20, 3), key(Char(32)))
  assert_eq(out, [@widget.Selected(id=5, index=1), Repaint(id=5)])
  assert_eq(set.pressed_index(), 1)
  assert_false(set.buttons()[0].value())
}

///|
test "a radio set keeps only the first button that arrived on" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one", value=true),
    @widget.RadioButton::new("two", value=true),
  ])
  assert_eq(set.pressed_index(), 0)
  assert_false(set.buttons()[1].value())
}

///|
test "the set's cursor wraps at both ends" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one"),
    @widget.RadioButton::new("two"),
    @widget.RadioButton::new("three"),
  ])
  assert_eq(set.selected_index(), 0)
  press(set, 5, toggle_size(20, 3), key(Up)) |> ignore
  assert_eq(set.selected_index(), 2)
  press(set, 5, toggle_size(20, 3), key(Down)) |> ignore
  assert_eq(set.selected_index(), 0)
}

///|
test "left and right move the set's cursor the same as up and down" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one"),
    @widget.RadioButton::new("two"),
  ])
  press(set, 5, toggle_size(20, 2), key(Right)) |> ignore
  assert_eq(set.selected_index(), 1)
  press(set, 5, toggle_size(20, 2), key(Left)) |> ignore
  assert_eq(set.selected_index(), 0)
}

///|
test "a click on a set row presses that row" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one"),
    @widget.RadioButton::new("two"),
    @widget.RadioButton::new("three"),
  ])
  let click = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 1,
    y: 2,
    mods: @event.none,
  })
  let out = press(set, 9, toggle_size(20, 3), click)
  assert_eq(out, [
    @widget.TakeFocus(id=9),
    @widget.Selected(id=9, index=2),
    Repaint(id=9),
  ])
  assert_eq(set.selected_index(), 2)
  assert_eq(set.pressed_index(), 2)
}

///|
test "a set taller than its box scrolls the cursor into view" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one"),
    @widget.RadioButton::new("two"),
    @widget.RadioButton::new("three"),
    @widget.RadioButton::new("four"),
  ])
  let w : &@widget.Widget = set
  w.render_line(0, toggle_size(20, 2)) |> ignore
  press(set, 5, toggle_size(20, 2), key(Down)) |> ignore
  press(set, 5, toggle_size(20, 2), key(Down)) |> ignore
  w.render_line(0, toggle_size(20, 2)) |> ignore
  assert_eq(w.render_line(1, toggle_size(20, 2)).text().length(), 20)
  assert_eq(set.selected_index(), 2)
}
