// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a paginator draws an arrow at each end and the pages between" {
  let pager = @widget.Paginator::new(page=2, pages=9)
  assert_eq(rows(pager, size(24, 1))[0], "‹ 1 2 3 4 5 6 7 8 9  ›  ")
  assert_eq(pager.hint(size(24, 3)), size(24, 1))
  assert_eq(pager.pages(), 9)
  assert_eq(pager.page(), 2)
}

///|
test "a paginator clamps the page and the page count it is given" {
  let pager = @widget.Paginator::new(page=20, pages=3)
  assert_eq(pager.page(), 2)
  pager.set_pages(0)
  assert_eq(pager.pages(), 1)
  assert_eq(pager.page(), 0)
  pager.set_pages(4)
  pager.set_page(-3)
  assert_eq(pager.page(), 0)
}

///|
test "a paginator steps by key and says which page it is on" {
  let pager = @widget.Paginator::new(page=2, pages=9)
  assert_eq(
    press(pager, 5, size(24, 1), key(Right))[0],
    Selected(id=5, index=3),
  )
  assert_eq(press(pager, 5, size(24, 1), key(End))[0], Selected(id=5, index=8))
  assert_eq(press(pager, 5, size(24, 1), key(Left))[0], Selected(id=5, index=7))
  assert_eq(press(pager, 5, size(24, 1), key(Home))[0], Selected(id=5, index=0))
  assert_eq(press(pager, 5, size(24, 1), key(Left)), [])
  assert_eq(press(pager, 5, size(24, 1), Paste("2")), [])
}

///|
test "a click on a number goes to that page" {
  let pager = @widget.Paginator::new(page=2, pages=9)
  let out = press(pager, 4, size(24, 1), mouse(Down, 3, 0))
  assert_eq(out[0], TakeFocus(id=4))
  assert_eq(out[1], Selected(id=4, index=0))
  assert_eq(pager.page(), 0)
  let same = press(pager, 4, size(24, 1), mouse(Down, 20, 0))
  assert_eq(same, [TakeFocus(id=4)])
}

///|
test "the wheel steps a page" {
  let pager = @widget.Paginator::new(page=1, pages=5)
  assert_eq(
    press(pager, 1, size(24, 1), mouse(ScrollDown, 0, 0))[0],
    Selected(id=1, index=2),
  )
  assert_eq(
    press(pager, 1, size(24, 1), mouse(ScrollUp, 0, 0))[0],
    Selected(id=1, index=1),
  )
}

///|
test "a narrow paginator leaves the pages out and keeps the arrows" {
  let pager = @widget.Paginator::new(page=8, pages=40)
  let line = rows(pager, size(16, 1))[0]
  assert_eq(@strip.str_cells(line), 16)
  assert_eq(line.has_prefix("‹ …"), true)
  assert_eq(line.contains("… ›"), true)
}

///|
test "a paginator takes focus" {
  let pager = @widget.Paginator::new(page=0, pages=2)
  assert_eq(pager.focusable(), true)
  assert_eq(press(pager, 1, size(24, 1), Focus(true)), [Repaint(id=1)])
}
