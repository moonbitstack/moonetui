// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a calendar lays a month out under its title and the weekdays" {
  let calendar = @widget.Calendar::new(date=@moondate.Date::new(2026, 3, 7))
  let lines = rows(calendar, size(21, 8))
  assert_eq(lines[0], "March 2026           ")
  assert_eq(lines[1], " Mo Tu We Th Fr Sa Su")
  assert_eq(lines[2], "                   1 ")
  assert_eq(lines[3], " 2  3  4  5  6  7  8 ")
  assert_eq(lines[7], "30 31                ")
  assert_eq(calendar.height(), 8)
  assert_eq(calendar.hint(size(21, 3)), size(21, 8))
}

///|
test "a calendar knows which days a month has, leap years included" {
  let leap = @widget.Calendar::new(date=@moondate.Date::new(2024, 2, 10))
  let lines = rows(leap, size(21, 8))
  assert_eq(lines[0], "February 2024        ")
  assert_eq(lines[6], "26 27 28 29          ")
  assert_eq(lines[7], "                     ")
  let month = @widget.Calendar::new(date=@moondate.Date::new(2026, 3, 7))
  month.set_date(@moondate.Date::new(2026, 4, 1))
  assert_eq(rows(month, size(21, 8))[0], "April 2026           ")
}

///|
test "a calendar walks a day, a week, a month and a year" {
  let calendar = @widget.Calendar::new(date=@moondate.Date::new(2026, 3, 7))
  let out = press(calendar, 2, size(21, 8), key(Right))
  assert_eq(out[0], Changed(id=2, value="2026-03-08"))
  assert_eq(out[1], Selected(id=2, index=8))
  assert_eq(calendar.date().to_string(), "2026-03-08")
  assert_eq(
    press(calendar, 2, size(21, 8), key(Down))[0],
    Changed(id=2, value="2026-03-15"),
  )
  assert_eq(
    press(calendar, 2, size(21, 8), key(PageDown))[0],
    Changed(id=2, value="2026-04-15"),
  )
  assert_eq(
    press(calendar, 2, size(21, 8), key(PageUp))[0],
    Changed(id=2, value="2026-03-15"),
  )
  assert_eq(
    press(calendar, 2, size(21, 8), key(Home))[0],
    Changed(id=2, value="2026-03-01"),
  )
  assert_eq(
    press(calendar, 2, size(21, 8), key(End))[0],
    Changed(id=2, value="2026-03-31"),
  )
  let still = @widget.Calendar::new(date=@moondate.Date::new(2026, 3, 1))
  assert_eq(press(still, 2, size(21, 8), key(Home)), [])
  assert_eq(press(still, 2, size(21, 8), Paste("7")), [])
}

///|
test "walking a month keeps the day the month has room for" {
  let calendar = @widget.Calendar::new(date=@moondate.Date::new(2026, 1, 31))
  assert_eq(
    press(calendar, 2, size(21, 8), key(PageDown))[0],
    Changed(id=2, value="2026-02-28"),
  )
  assert_eq(
    press(calendar, 2, size(21, 8), key(PageDown))[0],
    Changed(id=2, value="2026-03-28"),
  )
}

///|
test "a click on a day goes to it" {
  let calendar = @widget.Calendar::new(date=@moondate.Date::new(2026, 3, 7))
  let out = press(calendar, 6, size(21, 8), mouse(Down, 0, 3))
  assert_eq(out[0], TakeFocus(id=6))
  assert_eq(out[1], Changed(id=6, value="2026-03-02"))
  assert_eq(calendar.date().day, 2)
  let inside = press(calendar, 6, size(21, 8), mouse(Down, 10, 1))
  assert_eq(inside, [TakeFocus(id=6)])
  let outside = press(calendar, 6, size(21, 8), mouse(Down, 18, 7))
  assert_eq(outside, [TakeFocus(id=6)])
}

///|
test "the wheel walks a month" {
  let calendar = @widget.Calendar::new(date=@moondate.Date::new(2026, 3, 7))
  assert_eq(
    press(calendar, 1, size(21, 8), mouse(ScrollDown, 0, 0))[0],
    Changed(id=1, value="2026-04-07"),
  )
  assert_eq(
    press(calendar, 1, size(21, 8), mouse(ScrollUp, 0, 0))[0],
    Changed(id=1, value="2026-03-07"),
  )
}

///|
test "a calendar takes focus and starts on the epoch when given no day" {
  let calendar = @widget.Calendar::new()
  assert_eq(calendar.date().to_string(), "1970-01-01")
  assert_eq(calendar.focusable(), true)
  assert_eq(press(calendar, 1, size(21, 8), Focus(true)), [Repaint(id=1)])
}

///|
test "a calendar built from three numbers holds them to a day that exists" {
  assert_eq(@widget.Calendar::on(2026, 2, 31).date().to_string(), "2026-02-28")
  assert_eq(@widget.Calendar::on(2026, 13, 1).date().to_string(), "2026-12-01")
  assert_eq(@widget.Calendar::on(2024, 2, 29).date().to_string(), "2024-02-29")
}
