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
  assert_eq(press(w, 4, at, click(13, 0)), [
    @widget.TakeFocus(id=4),
    @widget.HeaderSelected(id=4, col=1),
  ])
  assert_eq(press(w, 4, at, click(0, 2)), [
    @widget.TakeFocus(id=4),
    @widget.Selected(id=4, index=1),
  ])
  assert_eq(press(w, 4, at, click(7, 2)), [
    @widget.TakeFocus(id=4),
    @widget.CellHighlighted(id=4, row=1, col=0),
    @widget.Repaint(id=4),
  ])
  assert_eq(press(w, 4, at, click(7, 2)), [
    @widget.TakeFocus(id=4),
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

///|
test "data table sorts numbers by value and keeps ties in place" {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Qty"))
  ignore(table.add_column("Tag"))
  ignore(table.add_row(["10", "x"]))
  ignore(table.add_row(["9", "y"]))
  ignore(table.add_row(["9", "z"]))
  ignore(table.add_row(["-2.5", "w"]))
  table.sort(0)
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(10, 5)).map(r => r.trim().to_owned()), [
    "Qty   Tag", "-2.5  w", "9     y", "9     z", "10    x",
  ])
}

///|
fn grid(
  rows : Int32,
  cursor_type~ : @widget.CursorType = Cell,
) -> @widget.DataTable {
  let table = @widget.DataTable::new(cursor_type~)
  for c in ["A", "B", "C", "D"] {
    ignore(table.add_column(c))
  }
  for r in 0..<rows {
    ignore(table.add_row(["a\{r}", "b\{r}", "c\{r}", "d\{r}"], label="\{r}"))
  }
  table
}

///|
test "data table reads, writes and clears its cells" {
  let table = grid(3)
  assert_eq((table.row_count(), table.column_count()), (3, 4))
  assert_eq(table.cell(1, 2), "c1")
  assert_eq(table.cell(-1, 0), "")
  assert_eq(table.cell(0, 9), "")
  table.set_cell(9, 0, "x")
  table.set_cell(0, 9, "x")
  table.set_cell(0, 0, "z")
  assert_eq(table.cell(0, 0), "z")
  table.sort(9)
  assert_eq(table.cell(0, 0), "z")
  table.clear_rows()
  assert_eq((table.row_count(), table.column_count()), (0, 4))
  table.clear()
  assert_eq((table.row_count(), table.column_count()), (0, 0))
}

///|
test "data table moves its cursor by call, held to the table" {
  let table = grid(5)
  table.move_cursor(row=2, col=3)
  assert_eq((table.cursor_row(), table.cursor_col()), (2, 3))
  table.move_cursor(row=99, col=99)
  assert_eq((table.cursor_row(), table.cursor_col()), (4, 3))
  table.move_cursor(row=-5, col=-5)
  assert_eq((table.cursor_row(), table.cursor_col()), (0, 0))
}

///|
test "data table pages, and Home and End go to an edge" {
  let table = grid(20)
  let w : &@widget.Widget = table
  let at = size(20, 6)
  ignore(rows(w, at))
  // Five rows show under the header, so a page is four.
  ignore(press(w, 1, at, key(PageDown)))
  assert_eq(table.cursor_row(), 4)
  ignore(press(w, 1, at, key(PageUp)))
  assert_eq(table.cursor_row(), 0)
  ignore(press(w, 1, at, key(End)))
  assert_eq(table.cursor_col(), 3)
  ignore(press(w, 1, at, key(Home)))
  assert_eq(table.cursor_col(), 0)
  let ctrl = @event.Mods::of_param(5)
  ignore(press(w, 1, at, Key(@event.Key::with_mods(End, ctrl))))
  assert_eq(table.cursor_row(), 19)
  ignore(rows(w, at))
  assert_eq(rows(w, at)[5].contains("a19"), true)
  ignore(press(w, 1, at, Key(@event.Key::with_mods(Home, ctrl))))
  assert_eq(table.cursor_row(), 0)
  ignore(press(w, 1, at, key(Up)))
  ignore(press(w, 1, at, key(Left)))
  assert_eq((table.cursor_row(), table.cursor_col()), (0, 0))
  assert_eq(press(w, 1, at, key(Enter)).length(), 1)
  assert_eq(press(w, 1, at, Paste("x")), [])
}

///|
test "data table column cursor scrolls with up and down" {
  let table = grid(20, cursor_type=Column)
  let w : &@widget.Widget = table
  let at = size(20, 6)
  ignore(rows(w, at))
  assert_eq(press(w, 1, at, key(Down)), [
    Scrolled(id=1, x=0, y=1),
    Repaint(id=1),
  ])
  ignore(press(w, 1, at, key(Up)))
  assert_eq(press(w, 1, at, key(Up)), [])
  assert_eq(table.cursor_row(), 0)
}

///|
test "data table row cursor pans with left and right" {
  let table = grid(3, cursor_type=Row)
  let w : &@widget.Widget = table
  let at = size(8, 4)
  let before = rows(w, at)
  assert_eq(press(w, 1, at, key(Right)), [Repaint(id=1)])
  assert_eq(rows(w, at) != before, true)
  ignore(press(w, 1, at, key(Left)))
  assert_eq(rows(w, at), before)
  assert_eq(press(w, 1, at, key(Left)), [])
}

///|
test "data table hovers by the pointer, by cursor type" {
  let at = size(20, 5)
  let cells = grid(3)
  let w : &@widget.Widget = cells
  ignore(rows(w, at))
  assert_eq(press(w, 1, at, mouse(Move, 6, 2)), [
    CellHighlighted(id=1, row=1, col=0),
    Repaint(id=1),
  ])
  assert_eq(press(w, 1, at, mouse(Move, 6, 2)), [])
  let by_row = grid(3, cursor_type=Row)
  let r : &@widget.Widget = by_row
  ignore(rows(r, at))
  assert_eq(press(r, 1, at, mouse(Move, 6, 3)), [
    Highlighted(id=1, index=2),
    Repaint(id=1),
  ])
  let by_col = grid(3, cursor_type=Column)
  let c : &@widget.Widget = by_col
  ignore(rows(c, at))
  assert_eq(press(c, 1, at, mouse(Move, 6, 1)), [
    Highlighted(id=1, index=0),
    Repaint(id=1),
  ])
  let none = grid(3, cursor_type=None)
  let n : &@widget.Widget = none
  ignore(rows(n, at))
  assert_eq(press(n, 1, at, mouse(Move, 6, 1)), [Repaint(id=1)])
  assert_eq(press(n, 1, at, mouse(Down, 6, 1)).contains(TakeFocus(id=1)), true)
  assert_eq(
    press(n, 1, at, mouse(Down, 6, 1)).iter().any(o => o is CellSelected(..)),
    false,
  )
}

///|
test "data table scrolls a page with the wheel" {
  let table = grid(20)
  let w : &@widget.Widget = table
  let at = size(20, 6)
  ignore(rows(w, at))
  assert_eq(press(w, 1, at, mouse(ScrollDown, 0, 0)), [
    Scrolled(id=1, x=0, y=4),
    Repaint(id=1),
  ])
  ignore(press(w, 1, at, mouse(ScrollUp, 0, 0)))
  assert_eq(press(w, 1, at, mouse(ScrollUp, 0, 0)), [])
  assert_eq(press(w, 1, at, mouse(Up, 0, 0)), [])
}
