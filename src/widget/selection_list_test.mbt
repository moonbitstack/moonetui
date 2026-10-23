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

///|
test "the wheel scrolls a selection list past its highlight" {
  let list = @widget.SelectionList::new(options=[
    @widget.Selection::new("a", "a"),
    @widget.Selection::new("b", "b"),
    @widget.Selection::new("c", "c"),
    @widget.Selection::new("d", "d"),
  ])
  let w : &@widget.Widget = list
  let at = size(8, 2)
  let wheel = @widget.Msg::Mouse({
    kind: ScrollDown,
    button: 0,
    x: 0,
    y: 0,
    mods: @event.none,
  })
  ignore(rows(w, at))
  ignore(press(w, 1, at, wheel))
  ignore(press(w, 1, at, wheel))
  assert_eq(rows(w, at)[0].contains("c"), true)
}

///|
fn picks(count : Int32, off~ : Array[Int32] = []) -> @widget.SelectionList {
  @widget.SelectionList::new(
    options=Array::makei(count, i => {
      @widget.Selection::new("o\{i}", "\{i}", disabled=off.contains(i))
    }),
  )
}

///|
test "selection list state is set by call, held to its options" {
  let list = picks(3)
  assert_eq(list.options().length(), 3)
  assert_eq(list.is_selected(9), false)
  list.set_selected(1, true)
  list.set_selected(9, true)
  list.toggle(2)
  list.toggle(-1)
  assert_eq(list.selected(), ["1", "2"])
  assert_eq(list.is_selected(1), true)
  list.select_all()
  assert_eq(list.selected(), ["0", "1", "2"])
  list.deselect_all()
  assert_eq(list.selected(), [])
  assert_eq(@widget.SelectionList::new().highlighted(), -1)
}

///|
test "selection list keys walk past disabled options" {
  let list = picks(8, off=[0, 7])
  let w : &@widget.Widget = list
  let at = size(8, 4)
  ignore(rows(w, at))
  assert_eq(list.highlighted(), 1)
  ignore(press(w, 1, at, key(End)))
  assert_eq(list.highlighted(), 6)
  ignore(press(w, 1, at, key(Home)))
  assert_eq(list.highlighted(), 1)
  ignore(press(w, 1, at, key(PageDown)))
  assert_eq(list.highlighted(), 4)
  ignore(press(w, 1, at, key(PageDown)))
  assert_eq(list.highlighted(), 6)
  ignore(press(w, 1, at, key(PageUp)))
  assert_eq(list.highlighted(), 3)
  ignore(press(w, 1, at, key(Up)))
  assert_eq(list.highlighted(), 2)
  ignore(press(w, 1, at, key(End)))
  assert_eq(rows(w, at)[3].contains("o6"), true)
  ignore(press(w, 1, at, key(Home)))
  assert_eq(rows(w, at)[0].contains("o1"), true)
}

///|
test "selection list leaves modified keys, other keys and pastes alone" {
  let w : &@widget.Widget = picks(3)
  let at = size(8, 3)
  let ctrl = @event.Mods::of_param(5)
  assert_eq(feed(w, at, Key(@event.Key::with_mods(Down, ctrl))), (false, []))
  assert_eq(feed(w, at, key(Escape)), (false, []))
  assert_eq(feed(w, at, Paste("x")), (false, []))
}

///|
test "selection list hovers by the pointer and scrolls with the wheel" {
  let list = picks(8)
  let w : &@widget.Widget = list
  let at = size(8, 3)
  ignore(rows(w, at))
  assert_eq(feed(w, at, mouse(Move, 0, 2)), (true, [Repaint(id=1)]))
  assert_eq(feed(w, at, mouse(Move, 0, 2)), (true, []))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  assert_eq(rows(w, at)[0].contains("o2"), true)
  ignore(feed(w, at, mouse(ScrollUp, 0, 0)))
  assert_eq(rows(w, at)[0].contains("o1"), true)
  assert_eq(feed(w, at, mouse(Up, 0, 0)), (false, []))
}

///|
test "selection list pages stop at the ends rather than wrapping round" {
  let list = picks(8)
  let w : &@widget.Widget = list
  let at = size(8, 4)
  ignore(rows(w, at))
  ignore(press(w, 1, at, key(Down)))
  ignore(press(w, 1, at, key(PageUp)))
  assert_eq(list.highlighted(), 0)
  ignore(press(w, 1, at, key(End)))
  ignore(press(w, 1, at, key(PageDown)))
  assert_eq(list.highlighted(), 7)
}
