// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a stateful list draws the choice the caller holds" {
  let state = @widget.ListState::new(selected=1)
  let list = @widget.StatefulList::new(items=["alpha", "beta", "gamma"], state~)
  let w : &@widget.Widget = list
  assert_eq(rows(w, size(8, 3)), ["alpha   ", "beta    ", "gamma   "])
  assert_eq(state.selected(), 1)
  assert_eq(list.render_line(1, size(8, 3)).segs[0].style.attrs.reverse, true)
}

///|
test "a stateful list moves the choice the caller holds" {
  let state = @widget.ListState::new(selected=0)
  let list = @widget.StatefulList::new(items=["a", "b", "c"], state~)
  let w : &@widget.Widget = list
  let out = press(w, 2, size(8, 3), key(Down))
  assert_eq(out, [@widget.Selected(id=2, index=1), @widget.Repaint(id=2)])
  assert_eq(state.selected(), 1)
  assert_eq(list.state().selected(), 1)
  ignore(press(w, 2, size(8, 3), key(End)))
  assert_eq(state.selected(), 2)
  ignore(press(w, 2, size(8, 3), key(Home)))
  assert_eq(state.selected(), 0)
  assert_eq(press(w, 2, size(8, 3), key(Up)), [])
}

///|
test "two lists share one state" {
  let state = @widget.ListState::new()
  let left = @widget.StatefulList::new(items=["a", "b"], state~)
  let right = @widget.StatefulList::new(items=["a", "b"], state~)
  let w : &@widget.Widget = left
  ignore(press(w, 1, size(8, 2), key(Down)))
  assert_eq(right.state().selected(), 0)
  assert_eq(right.render_line(0, size(8, 2)).segs[0].style.attrs.reverse, true)
}

///|
test "a caller's choice shows up in the list that draws it" {
  let state = @widget.ListState::new()
  let list = @widget.StatefulList::new(items=["a", "b", "c"], state~)
  assert_eq(list.render_line(1, size(8, 3)).segs[0].style.attrs.reverse, false)
  state.select(2, 3) |> ignore
  assert_eq(list.render_line(2, size(8, 3)).segs[0].style.attrs.reverse, true)
  state.clear()
  assert_eq(state.is_set(), false)
  assert_eq(list.render_line(2, size(8, 3)).segs[0].style.attrs.reverse, false)
}

///|
test "the wheel scrolls the view of a stateful list and leaves the choice" {
  let state = @widget.ListState::new(selected=0)
  let list = @widget.StatefulList::new(items=["a", "b", "c"], state~)
  let w : &@widget.Widget = list
  assert_eq(
    press(
      w,
      2,
      size(8, 2),
      Mouse({ kind: ScrollDown, button: 0, x: 1, y: 1, mods: @event.none, }),
    ),
    [@widget.Repaint(id=2)],
  )
  assert_eq(state.offset(), 1)
  assert_eq(state.selected(), 0)
  assert_eq(list.render_line(0, size(8, 2)).text(), "b       ")
  assert_eq(press(w, 2, size(8, 2), key(Down)) |> ignore, ())
}

///|
test "a click on a row of a stateful list chooses it" {
  let state = @widget.ListState::new()
  let list = @widget.StatefulList::new(items=["a", "b", "c"], state~)
  let w : &@widget.Widget = list
  let out = press(
    w,
    3,
    size(8, 3),
    Mouse({ kind: Down, button: 0, x: 1, y: 2, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=3),
    @widget.Selected(id=3, index=2),
    @widget.Repaint(id=3),
  ])
  assert_eq(state.selected(), 2)
}

///|
test "a stateful list scrolls a long list back to its choice" {
  let items : Array[String] = []
  for i in 0..<12 {
    items.push("row" + i.to_string())
  }
  let state = @widget.ListState::new()
  let list = @widget.StatefulList::new(items~, state~)
  let w : &@widget.Widget = list
  for _ in 0..<12 {
    press(w, 4, size(8, 3), key(Down)) |> ignore
  }
  assert_eq(state.selected(), 11)
  assert_eq(state.offset(), 9)
  assert_eq(list.render_line(2, size(8, 3)).text().has_prefix("row11"), true)
  assert_eq(list.items().length(), 12)
}

///|
test "a stateful table draws its cells from the state it was given" {
  let state = @widget.TableState::new(row=1, column=0)
  let table = @widget.StatefulTable::new(
    header=["name", "size"],
    rows=[["a", "1"], ["b", "2"]],
    state~,
  )
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(10, 3)), ["name size ", "a    1    ", "b    2    "])
  assert_eq(table.columns(), 2)
  assert_eq(table.render_line(2, size(10, 3)).segs[0].style.attrs.reverse, true)
}

///|
test "a stateful table moves its cell and says where it went" {
  let state = @widget.TableState::new()
  let table = @widget.StatefulTable::new(
    header=["name", "size"],
    rows=[["a", "1"], ["b", "2"]],
    state~,
  )
  let w : &@widget.Widget = table
  let out = press(w, 5, size(10, 3), key(Down))
  assert_eq(out, [
    @widget.CellHighlighted(id=5, row=0, col=0),
    @widget.Repaint(id=5),
  ])
  ignore(press(w, 5, size(10, 3), key(Right)))
  assert_eq(state.column(), 1)
  assert_eq(state.row(), 0)
  assert_eq(state.is_set(), true)
  state.clear()
  assert_eq(state.is_set(), false)
}

///|
test "a stateful table takes a click on a cell and on a header" {
  let state = @widget.TableState::new()
  let table = @widget.StatefulTable::new(
    header=["name", "size"],
    rows=[["a", "1"], ["b", "2"]],
    state~,
  )
  let w : &@widget.Widget = table
  let cell = press(
    w,
    5,
    size(10, 3),
    Mouse({ kind: Down, button: 0, x: 7, y: 2, mods: @event.none, }),
  )
  assert_eq(cell, [
    @widget.TakeFocus(id=5),
    @widget.CellSelected(id=5, row=1, col=1),
    @widget.Repaint(id=5),
  ])
  let head = press(
    w,
    5,
    size(10, 3),
    Mouse({ kind: Down, button: 0, x: 7, y: 0, mods: @event.none, }),
  )
  assert_eq(head, [@widget.TakeFocus(id=5), @widget.HeaderSelected(id=5, col=1)])
}

///|
test "a stateful table scrolls its rows and keeps the columns it was given" {
  let state = @widget.TableState::new()
  let table = @widget.StatefulTable::new(
    rows=[["a"], ["b"], ["c"]],
    state~,
    widths=Some([4]),
  )
  let w : &@widget.Widget = table
  assert_eq(
    press(
      w,
      5,
      size(6, 2),
      Mouse({ kind: ScrollDown, button: 0, x: 1, y: 1, mods: @event.none, }),
    ),
    [@widget.Repaint(id=5)],
  )
  assert_eq(state.offset(), 1)
  assert_eq(table.render_line(0, size(6, 2)).text(), "b     ")
  table.set_rows([["z"]])
  table.set_header(["only"])
  assert_eq(table.rows().length(), 1)
  assert_eq(table.state().offset(), 1)
}

///|
test "a stateful list and table focus and blur" {
  let list = @widget.StatefulList::new(items=["a"])
  let w : &@widget.Widget = list
  assert_eq(w.focusable(), true)
  assert_eq(press(w, 1, size(8, 1), Focus(true)), [@widget.Repaint(id=1)])
  assert_eq(list.render_line(0, size(8, 1)).segs[0].style.attrs.reverse, false)
  let table = @widget.StatefulTable::new(rows=[["a"]])
  let w2 : &@widget.Widget = table
  assert_eq(w2.focusable(), true)
  assert_eq(press(w2, 1, size(8, 1), Focus(true)), [@widget.Repaint(id=1)])
}

///|
test "states hold to what is there" {
  let state = @widget.ListState::new()
  assert_eq(state.move_by(1, 0), false)
  assert_eq(state.select(5, 3), true)
  assert_eq(state.selected(), 2)
  assert_eq(state.select(2, 3), false)
  state.follow(2, 3)
  assert_eq(state.offset(), 1)
  assert_eq(state.seen(), 2)
  let table = @widget.TableState::new()
  assert_eq(table.move_by(1, 1, 0, 0), false)
  assert_eq(table.select(9, 9, 2, 2), true)
  assert_eq(table.row(), 1)
  assert_eq(table.column(), 1)
  assert_eq(table.select(1, 1, 2, 2), false)
  table.follow(1, 3)
  assert_eq(table.offset(), 1)
}

///|
test "states hold to nothing when there is nothing to hold to" {
  let table = @widget.TableState::new()
  assert_eq(table.select(0, 0, 0, 2), true)
  assert_eq(table.row(), -1)
  assert_eq(table.select(0, 0, 2, 0), true)
  assert_eq(table.column(), -1)
  assert_eq(table.scroll_by(1, 0), false)
  table.follow(0, 0)
  assert_eq(table.offset(), 0)
  let list = @widget.ListState::new()
  assert_eq(list.select(0, 0), false)
  assert_eq(list.selected(), -1)
  assert_eq(list.scroll_by(1, 0), false)
  list.follow(0, 0)
  assert_eq(list.offset(), 0)
  assert_eq(list.seen(), 0)
}

///|
test "a stateful table with no header puts its rows at the top" {
  let state = @widget.TableState::new()
  let table = @widget.StatefulTable::new(rows=[["a"], ["b"]], state~)
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(6, 2)), ["a     ", "b     "])
  let out = press(
    w,
    1,
    size(6, 2),
    Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=1),
    @widget.CellSelected(id=1, row=0, col=0),
    @widget.Repaint(id=1),
  ])
}

///|
test "a stateful table keeps the widths it was given" {
  let state = @widget.TableState::new(column=1)
  let table = @widget.StatefulTable::new(
    rows=[["a", "b"]],
    header=["one", "two"],
    state~,
    widths=Some([3, 4]),
  )
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(12, 2)), ["onetwo      ", "a  b        "])
  assert_eq(table.columns(), 2)
  ignore(press(w, 1, size(12, 2), key(Right)))
  assert_eq(state.column(), 1)
}

///|
test "a stateful list with nothing in it is blank and takes no keys" {
  let state = @widget.ListState::new()
  let list = @widget.StatefulList::new(state~)
  let w : &@widget.Widget = list
  assert_eq(rows(w, size(6, 2)), ["      ", "      "])
  assert_eq(press(w, 1, size(6, 2), key(Down)), [])
  assert_eq(
    press(
      w,
      1,
      size(6, 2),
      Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  list.set_items(["a", "b"])
  assert_eq(list.items().length(), 2)
}

///|
test "a stateful table with nothing in it is blank and takes no keys" {
  let state = @widget.TableState::new()
  let table = @widget.StatefulTable::new(state~)
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(6, 2)), ["      ", "      "])
  assert_eq(press(w, 1, size(6, 2), key(Down)), [])
  assert_eq(table.columns(), 0)
  assert_eq(
    press(
      w,
      1,
      size(6, 2),
      Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
}
