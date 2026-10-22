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
test "the wheel scrolls the view past the highlight and keys bring it back" {
  let list = @widget.OptionList::new(
    options=choices(["a", "b", "c", "d", "e", "f"]),
  )
  let w : &@widget.Widget = list
  let at = size(4, 2)
  let wheel = @widget.Msg::Mouse({
    kind: ScrollDown,
    button: 0,
    x: 0,
    y: 0,
    mods: @event.none,
  })
  assert_eq(rows(w, at), ["a   ", "b   "])
  ignore(press(w, 1, at, wheel))
  ignore(press(w, 1, at, wheel))
  assert_eq(rows(w, at), ["c   ", "d   "])
  for _ in 0..<9 {
    ignore(press(w, 1, at, wheel))
  }
  assert_eq(rows(w, at), ["e   ", "f   "])
  ignore(press(w, 1, at, key(Down)))
  assert_eq(rows(w, at), ["b   ", "c   "])
}
