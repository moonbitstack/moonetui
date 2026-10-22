// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn crew() -> @widget.DataTable {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Name"))
  ignore(table.add_column("Qty", align=Right))
  ignore(table.add_row(["Paul", "3"], label="1"))
  ignore(table.add_row(["Jessica", "12"], label="2"))
  table
}

///|
test "data table renders a header and padded rows" {
  let table = crew()
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(16, 4)), [
    "    Name     Qty", " 1  Paul       3", " 2  Jessica   12", "                ",
  ])
  assert_eq(w.hint(size(16, 24)), size(17, 3))
}

///|
test "data table hides the header when asked" {
  let bare = @widget.DataTable::new(show_header=false)
  ignore(bare.add_column("Name"))
  ignore(bare.add_row(["Paul"], label="1"))
  let w : &@widget.Widget = bare
  assert_eq(rows(w, size(10, 2)), [" 1  Paul  ", "          "])
  assert_eq(w.hint(size(10, 24)), size(9, 1))
}

///|
test "data table walks a cell cursor and reports it" {
  let table = crew()
  let w : &@widget.Widget = table
  let at = size(16, 4)
  assert_eq(press(w, 7, at, key(Down)), [
    @widget.CellHighlighted(id=7, row=1, col=0),
    @widget.Repaint(id=7),
  ])
  assert_eq(press(w, 7, at, key(Right)), [
    @widget.CellHighlighted(id=7, row=1, col=1),
    @widget.Repaint(id=7),
  ])
  assert_eq(press(w, 7, at, key(Enter)), [
    @widget.CellSelected(id=7, row=1, col=1),
  ])
}

///|
test "data table row cursor reports rows and column cursor reports columns" {
  let by_row = @widget.DataTable::new(cursor_type=Row)
  ignore(by_row.add_column("Name"))
  ignore(by_row.add_column("Qty"))
  ignore(by_row.add_row(["Paul", "3"]))
  ignore(by_row.add_row(["Jessica", "12"]))
  let w : &@widget.Widget = by_row
  let at = size(16, 4)
  assert_eq(press(w, 2, at, key(Down)), [
    @widget.Highlighted(id=2, index=1),
    @widget.Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, key(Right)), [])
  assert_eq(press(w, 2, at, key(Enter)), [@widget.Selected(id=2, index=1)])
  let by_col = @widget.DataTable::new(cursor_type=Column)
  ignore(by_col.add_column("Name"))
  ignore(by_col.add_column("Qty"))
  ignore(by_col.add_row(["Paul", "3"]))
  let wc : &@widget.Widget = by_col
  assert_eq(press(wc, 3, at, key(Right)), [
    @widget.Highlighted(id=3, index=1),
    @widget.Repaint(id=3),
  ])
  assert_eq(press(wc, 3, at, key(Enter)), [@widget.Selected(id=3, index=1)])
}

///|
test "data table clicks select headers labels and cells" {
  let table = crew()
  let w : &@widget.Widget = table
  let at = size(16, 4)
  let click = fn(x : Int32, y : Int32) -> @widget.Msg {
    Mouse({ kind: Down, button: 0, x, y, mods: @event.none, })
  }
  assert_eq(press(w, 4, at, click(13, 0)), [@widget.HeaderSelected(id=4, col=1)])
  assert_eq(press(w, 4, at, click(0, 2)), [@widget.Selected(id=4, index=1)])
  assert_eq(press(w, 4, at, click(7, 2)), [
    @widget.CellHighlighted(id=4, row=1, col=0),
    @widget.Repaint(id=4),
  ])
  assert_eq(press(w, 4, at, click(7, 2)), [
    @widget.CellSelected(id=4, row=1, col=0),
  ])
}

///|
test "data table sorts rows by a column" {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Name"))
  ignore(table.add_column("Qty"))
  ignore(table.add_row(["Chani"], label="3"))
  ignore(table.add_row(["Alia"], label="1"))
  ignore(table.add_row(["Paul"], label="2"))
  table.sort(0)
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(14, 4)), [
    "    Name   Qty", " 1  Alia      ", " 3  Chani     ", " 2  Paul      ",
  ])
  table.sort(0, reverse=true)
  assert_eq(rows(w, size(14, 4)), [
    "    Name   Qty", " 2  Paul      ", " 3  Chani     ", " 1  Alia      ",
  ])
}

///|
test "data table scrolls to keep the cursor in view" {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Name"))
  let total = 8
  for i in 0..<total {
    ignore(table.add_row(["row \{i}"]))
  }
  let w : &@widget.Widget = table
  let at = size(10, 4)
  let mut steps = 0
  while steps < 5 {
    ignore(press(w, 9, at, key(Down)))
    steps = steps + 1
  }
  assert_eq(table.cursor_row(), 5)
  assert_eq(rows(w, at), [
    " Name     ", " row 3    ", " row 4    ", " row 5    ",
  ])
}
