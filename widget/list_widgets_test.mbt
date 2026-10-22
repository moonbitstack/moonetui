// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn choices(names : Array[String]) -> Array[@widget.Choice] {
  let out : Array[@widget.Choice] = []
  for name in names {
    out.push(@widget.Choice::new(name))
  }
  out
}

///|
test "option list walks its enabled options with wraparound" {
  let list = @widget.OptionList::new(options=[
    @widget.Choice::new("alpha", disabled=true),
    @widget.Choice::new("beta"),
    @widget.Choice::new("gamma"),
  ])
  assert_eq(list.highlighted(), 1)
  let w : &@widget.Widget = list
  let at = size(10, 4)
  let out = press(w, 1, at, key(Down))
  assert_eq(list.highlighted(), 2)
  assert_eq(out, [@widget.Highlighted(id=1, index=2), @widget.Repaint(id=1)])
  ignore(press(w, 1, at, key(Down)))
  assert_eq(list.highlighted(), 1)
  ignore(press(w, 1, at, key(Up)))
  assert_eq(list.highlighted(), 2)
  ignore(press(w, 1, at, key(Home)))
  assert_eq(list.highlighted(), 1)
  ignore(press(w, 1, at, key(End)))
  assert_eq(list.highlighted(), 2)
}

///|
test "option list renders prompts and separators" {
  let list = @widget.OptionList::new(options=choices(["alpha", "beta"]))
  list.add_separator()
  list.add_option(@widget.Choice::new("gamma"))
  let w : &@widget.Widget = list
  assert_eq(rows(w, size(7, 4)), [
    "alpha  ", "beta   ", "───────", "gamma  ",
  ])
  assert_eq(w.hint(size(80, 24)), size(5, 4))
}

///|
test "option list selects on enter and click" {
  let list = @widget.OptionList::new(options=choices(["one", "two"]))
  let w : &@widget.Widget = list
  let at = size(6, 4)
  assert_eq(press(w, 3, at, key(Enter)), [@widget.Selected(id=3, index=0)])
  let out = press(
    w,
    3,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 1, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=3),
    @widget.Highlighted(id=3, index=1),
    @widget.Repaint(id=3),
    @widget.Selected(id=3, index=1),
  ])
  assert_eq(list.highlighted(), 1)
}

///|
test "option list releases a disabled highlight" {
  let list = @widget.OptionList::new(options=choices(["one", "two", "three"]))
  let w : &@widget.Widget = list
  list.set_disabled(0, true)
  assert_eq(list.highlighted(), 1)
  list.set_disabled(1, true)
  assert_eq(list.highlighted(), 2)
  let out = press(
    w,
    5,
    size(6, 4),
    Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [@widget.TakeFocus(id=5)])
  list.set_disabled(2, true)
  assert_eq(list.highlighted(), -1)
  assert_eq(press(w, 5, size(6, 4), key(Enter)), [])
}

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
test "select shows the current choice and expands in flow" {
  let select = @widget.Select::new(
    options=[("Apple", "apple"), ("Banana", "banana"), ("Cherry", "cherry")],
    value=Some("banana"),
  )
  let w : &@widget.Widget = select
  let at = size(12, 6)
  assert_eq(rows(w, size(12, 1)), [" Banana    ▼"])
  assert_eq(w.hint(at), size(12, 1))
  let out = press(w, 1, at, key(Enter))
  assert_eq(out, [@widget.Repaint(id=1)])
  assert_eq(select.expanded(), true)
  assert_eq(w.hint(at), size(12, 4))
  assert_eq(rows(w, size(12, 4)), [
    " Banana    ▲", " Apple      ", " Banana     ", " Cherry     ",
  ])
}

///|
test "select chooses, escapes and searches" {
  let select = @widget.Select::new(options=[
    ("Apple", "apple"),
    ("Banana", "banana"),
    ("Cherry", "cherry"),
  ])
  let w : &@widget.Widget = select
  let at = size(12, 6)
  ignore(press(w, 1, at, key(Char(32))))
  assert_eq(select.expanded(), true)
  ignore(press(w, 1, at, key(Char(98))))
  ignore(press(w, 1, at, key(Char(97))))
  let out = press(w, 1, at, key(Enter))
  assert_eq(out, [
    @widget.Selected(id=1, index=1),
    @widget.Changed(id=1, value="banana"),
    @widget.Repaint(id=1),
  ])
  assert_eq(select.value(), Some("banana"))
  assert_eq(select.expanded(), false)
  assert_eq(rows(w, size(12, 1)), [" Banana    ▼"])
  ignore(press(w, 1, at, key(Down)))
  assert_eq(select.expanded(), true)
  assert_eq(press(w, 1, at, key(Escape)), [@widget.Repaint(id=1)])
  assert_eq(select.expanded(), false)
}

///|
test "select picks from clicks and blanks when allowed" {
  let select = @widget.Select::new(options=[("One", "one"), ("Two", "two")])
  let w : &@widget.Widget = select
  let at = size(8, 4)
  assert_eq(rows(w, size(8, 1)), [" Select▼"])
  let out = press(
    w,
    1,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [@widget.TakeFocus(id=1), @widget.Repaint(id=1)])
  let out = press(
    w,
    1,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 2, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=1),
    @widget.Selected(id=1, index=1),
    @widget.Changed(id=1, value="two"),
    @widget.Repaint(id=1),
  ])
  select.clear()
  assert_eq(select.is_blank(), true)
  let strict = @widget.Select::new(options=[("One", "one")], allow_blank=false)
  assert_eq(strict.value(), Some("one"))
}
