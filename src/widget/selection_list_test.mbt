// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "selection list toggles and reports its values" {
  let list = @widget.SelectionList::new(options=[
    @widget.Selection::new("first", "1", initial_state=true),
    @widget.Selection::new("second", "2"),
    @widget.Selection::new("third", "3", disabled=true),
  ])
  assert_eq(list.selected(), ["1"])
  let w : &@widget.Widget = list
  let at = size(12, 4)
  assert_eq(rows(w, at), [
    "▐X▌ first   ", "▐X▌ second  ", "▐X▌ third   ", "            ",
  ])
  let out = press(w, 2, at, key(Char(32)))
  assert_eq(out, [
    @widget.ToggledAt(id=2, index=0, on=false),
    @widget.Changed(id=2, value=""),
    @widget.Repaint(id=2),
  ])
  ignore(press(w, 2, at, key(Down)))
  assert_eq(list.highlighted(), 1)
  ignore(press(w, 2, at, key(Enter)))
  assert_eq(list.selected(), ["2"])
  list.toggle_all()
  assert_eq(list.selected(), ["1", "3"])
  assert_eq(press(w, 2, at, key(Down)), [
    @widget.Highlighted(id=2, index=0),
    @widget.Repaint(id=2),
  ])
}

///|
test "selection list clicks toggle under the pointer" {
  let list = @widget.SelectionList::new(options=[
    @widget.Selection::new("a", "a"),
    @widget.Selection::new("b", "b", disabled=true),
  ])
  let w : &@widget.Widget = list
  let at = size(8, 4)
  let out = press(
    w,
    1,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 1, mods: @event.none, }),
  )
  assert_eq(out, [@widget.TakeFocus(id=1)])
  assert_eq(list.selected(), [])
  let out = press(
    w,
    1,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=1),
    @widget.ToggledAt(id=1, index=0, on=true),
    @widget.Changed(id=1, value="a"),
    @widget.Repaint(id=1),
  ])
  assert_eq(list.selected(), ["a"])
}
