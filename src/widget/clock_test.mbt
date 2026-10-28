// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a clock prints hours, minutes and seconds as two digits" {
  let clock = @widget.Clock::new(hour=1, minute=2, second=3)
  assert_eq(clock.text(), "01:02:03")
  assert_eq(clock.hour(), 1)
  assert_eq(clock.minute(), 2)
  assert_eq(clock.second(), 3)
}

///|
test "a clock wraps the time it is given" {
  assert_eq(@widget.Clock::new(hour=25).text(), "01:00:00")
  assert_eq(@widget.Clock::new(minute=61).text(), "00:01:00")
  assert_eq(@widget.Clock::new(second=61).text(), "00:00:01")
}

///|
test "a clock counts forward from the milliseconds the frames give it" {
  let clock = @widget.Clock::new()
  assert_eq(clock.advance(1000), true)
  assert_eq(clock.text(), "00:00:01")
  assert_eq(clock.advance(500), false)
  assert_eq(clock.text(), "00:00:01")
  assert_eq(clock.advance(1500), true)
  assert_eq(clock.text(), "00:00:03")
}

///|
test "a clock rolls over midnight and compares by the second" {
  let clock = @widget.Clock::new(hour=23, minute=59, second=59)
  assert_eq(clock.advance(2000), true)
  assert_eq(clock.text(), "00:00:01")
  let other = @widget.Clock::new(hour=0, minute=0, second=1)
  assert_eq(clock.seconds(), other.seconds())
  clock.set(hour=0, minute=0, second=30)
  assert_eq(clock.text(), "00:00:30")
}
