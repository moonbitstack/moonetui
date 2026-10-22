// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "select shows the current choice and expands in flow" {
  let select = @widget.Select::new(
    options=[("Apple", "apple"), ("Banana", "banana"), ("Cherry", "cherry")],
    value="banana",
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
