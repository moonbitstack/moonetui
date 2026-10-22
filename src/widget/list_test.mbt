// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a list moves its highlight and reports what was chosen" {
  let list = @widget.ListView::new(["one", "two", "three"])
  let w : &@widget.Widget = list
  let at = size(8, 3)
  assert_eq(rows(w, at), ["one     ", "two     ", "three   "])
  w.handle(@widget.Ctx::new(4, at), key(Down)) |> ignore
  assert_eq(list.index(), 1)
  assert_eq(press(w, 4, at, key(Enter)), [Selected(id=4, index=1)])
  w.handle(@widget.Ctx::new(4, at), key(End)) |> ignore
  assert_eq(list.index(), 2)
  w.handle(@widget.Ctx::new(4, at), key(Home)) |> ignore
  assert_eq(list.index(), 0)
}

///|
test "a list scrolls so the highlight stays on screen" {
  let list = @widget.ListView::new(["a", "b", "c", "d", "e"])
  let w : &@widget.Widget = list
  let at = size(4, 2)
  list.select(4)
  assert_eq(rows(w, at), ["d   ", "e   "])
  assert_eq(list.offset(), 3)
}

///|
test "an empty list has no selection and ignores the keys" {
  let list = @widget.ListView::new([])
  let w : &@widget.Widget = list
  assert_eq(list.index(), -1)
  assert_eq(press(w, 1, size(4, 2), key(Enter)), [])
  assert_eq(rows(w, size(4, 2)), ["    ", "    "])
}

///|
test "clicking a row takes focus and highlights it" {
  let list = @widget.ListView::new(["a", "b", "c"])
  let w : &@widget.Widget = list
  let clicked = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 0,
    y: 2,
    mods: @event.none,
  })
  let asked = press(w, 6, size(4, 3), clicked)
  assert_eq(asked[0], TakeFocus(id=6))
  assert_eq(list.index(), 2)
}
