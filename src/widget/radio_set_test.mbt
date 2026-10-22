// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a radio set presses one button and turns the others off" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one", value=true),
    @widget.RadioButton::new("two"),
    @widget.RadioButton::new("three"),
  ])
  assert_eq(set.pressed_index(), 0)
  press(set, 5, size(20, 3), key(Char(32))) |> ignore
  assert_eq(set.pressed_index(), 0)
  press(set, 5, size(20, 3), key(Down)) |> ignore
  assert_eq(set.selected_index(), 1)
  assert_eq(set.pressed_index(), 0)
  let out = press(set, 5, size(20, 3), key(Char(32)))
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
  press(set, 5, size(20, 3), key(Up)) |> ignore
  assert_eq(set.selected_index(), 2)
  press(set, 5, size(20, 3), key(Down)) |> ignore
  assert_eq(set.selected_index(), 0)
}

///|
test "left and right move the set's cursor the same as up and down" {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("one"),
    @widget.RadioButton::new("two"),
  ])
  press(set, 5, size(20, 2), key(Right)) |> ignore
  assert_eq(set.selected_index(), 1)
  press(set, 5, size(20, 2), key(Left)) |> ignore
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
  let out = press(set, 9, size(20, 3), click)
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
  w.render_line(0, size(20, 2)) |> ignore
  press(set, 5, size(20, 2), key(Down)) |> ignore
  press(set, 5, size(20, 2), key(Down)) |> ignore
  w.render_line(0, size(20, 2)) |> ignore
  assert_eq(w.render_line(1, size(20, 2)).text().length(), 20)
  assert_eq(set.selected_index(), 2)
}
