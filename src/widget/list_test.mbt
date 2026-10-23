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

///|
test "a list reports where its highlight moves" {
  let list = @widget.ListView::new(["a", "b", "c"])
  let w : &@widget.Widget = list
  let at = size(4, 3)
  assert_eq(press(w, 2, at, key(Down)), [
    Highlighted(id=2, index=1),
    Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, key(Up)), [
    Highlighted(id=2, index=0),
    Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, key(Up)), [])
}

///|
test "a click selects the row under it and nothing below the last" {
  let list = @widget.ListView::new(["a", "b"])
  let w : &@widget.Widget = list
  let at = size(4, 4)
  let click = (y : Int32) => {
    @widget.Msg::Mouse({ kind: Down, button: 0, x: 0, y, mods: @event.none, })
  }
  assert_eq(press(w, 3, at, click(1)), [
    TakeFocus(id=3),
    Highlighted(id=3, index=1),
    Repaint(id=3),
    Selected(id=3, index=1),
  ])
  assert_eq(press(w, 3, at, click(3)), [TakeFocus(id=3)])
  assert_eq(list.index(), 1)
}

///|
fn many(count : Int32) -> @widget.ListView {
  @widget.ListView::new(Array::makei(count, i => "i\{i}"))
}

///|
test "list view pages by the rows it shows" {
  let list = many(20)
  let w : &@widget.Widget = list
  let at = size(6, 5)
  assert_eq(press(w, 1, at, key(PageDown)), [
    Highlighted(id=1, index=4),
    Repaint(id=1),
  ])
  ignore(press(w, 1, at, key(PageDown)))
  ignore(press(w, 1, at, key(PageUp)))
  assert_eq(list.index(), 4)
  let row : &@widget.Widget = many(3)
  ignore(press(row, 1, size(6, 1), key(PageDown)))
  assert_eq(row.render_line(0, size(6, 1)).text(), "i1    ")
}

///|
test "the wheel scrolls a list view without moving its highlight" {
  let list = many(20)
  let w : &@widget.Widget = list
  let at = size(6, 4)
  ignore(rows(w, at))
  assert_eq(press(w, 1, at, mouse(ScrollDown, 0, 0)), [Repaint(id=1)])
  ignore(press(w, 1, at, mouse(ScrollDown, 0, 0)))
  assert_eq(rows(w, at)[0].trim(), "i2")
  assert_eq(list.index(), 0)
  ignore(press(w, 1, at, mouse(ScrollUp, 0, 0)))
  assert_eq(list.offset(), 1)
  ignore(press(w, 1, at, mouse(ScrollDown, 0, 0)))
  ignore(press(w, 1, at, mouse(ScrollDown, 0, 0)))
  ignore(press(w, 1, at, key(Down)))
  ignore(rows(w, at))
  assert_eq((list.index(), list.offset()), (1, 1))
}

///|
test "list view items are replaced by call, and the highlight kept in range" {
  let list = many(5)
  list.select(4)
  list.set(["a", "b"])
  assert_eq(list.items(), ["a", "b"])
  assert_eq(list.index(), 1)
  list.set([])
  assert_eq(list.index(), -1)
  let w : &@widget.Widget = many(2)
  let ctrl = @event.Mods::of_param(5)
  assert_eq(
    feed(w, size(4, 2), Key(@event.Key::with_mods(Down, ctrl))),
    (false, []),
  )
  assert_eq(feed(w, size(4, 2), mouse(Move, 0, 0)), (false, []))
}
