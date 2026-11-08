// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a slider draws a track, a thumb and the number it holds" {
  let slider = @widget.Slider::new(value=40, low=0, high=100)
  assert_eq(
    rows(slider, size(24, 1))[0],
    "━━━━━━━━●───────────  40",
  )
  assert_eq(slider.hint(size(24, 3)), size(24, 1))
  assert_eq(slider.ratio(), 0.4)
  assert_eq(slider.bounds(), (0, 100))
}

///|
test "a slider holds its number between the ends" {
  let slider = @widget.Slider::new(value=500, low=0, high=100)
  assert_eq(slider.value(), 100)
  slider.set_value(-5)
  assert_eq(slider.value(), 0)
  assert_eq(slider.ratio(), 0.0)
  let flat = @widget.Slider::new(low=7, high=7)
  assert_eq(flat.ratio(), 0.0)
  assert_eq(flat.value(), 7)
}

///|
test "a slider walks by a step, a page and its ends, and says where it went" {
  let slider = @widget.Slider::new(value=40, low=0, high=100, step=5)
  let right = press(slider, 7, size(24, 1), key(Right))
  assert_eq(right[0], Changed(id=7, value="45"))
  assert_eq(right[1], Repaint(id=7))
  assert_eq(slider.value(), 45)
  assert_eq(
    press(slider, 7, size(24, 1), key(PageDown))[0],
    Changed(id=7, value="95"),
  )
  assert_eq(
    press(slider, 7, size(24, 1), key(End))[0],
    Changed(id=7, value="100"),
  )
  assert_eq(
    press(slider, 7, size(24, 1), key(Home))[0],
    Changed(id=7, value="0"),
  )
  assert_eq(press(slider, 7, size(24, 1), key(Up))[0], Changed(id=7, value="5"))
  assert_eq(
    press(slider, 7, size(24, 1), key(Left))[0],
    Changed(id=7, value="0"),
  )
}

///|
test "a slider stays put at an end and ignores what it does not answer" {
  let slider = @widget.Slider::new(value=0, low=0, high=100)
  assert_eq(press(slider, 7, size(24, 1), key(Left)), [])
  assert_eq(press(slider, 7, size(24, 1), key(Home)), [])
  assert_eq(press(slider, 7, size(24, 1), Paste("9")), [])
  assert_eq(slider.value(), 0)
}

///|
test "a click on the track goes to the place it landed on" {
  let slider = @widget.Slider::new(value=0, low=0, high=100)
  let out = press(slider, 3, size(24, 1), mouse(Down, 20, 0))
  assert_eq(out[0], TakeFocus(id=3))
  assert_eq(slider.value(), 100)
  let back = press(slider, 3, size(24, 1), mouse(Down, 0, 0))
  assert_eq(back[0], TakeFocus(id=3))
  assert_eq(back[1], Changed(id=3, value="0"))
  assert_eq(slider.value(), 0)
}

///|
test "the wheel moves a slider by one step" {
  let slider = @widget.Slider::new(value=50, low=0, high=100, step=2)
  assert_eq(
    press(slider, 1, size(24, 1), mouse(ScrollDown, 0, 0))[0],
    Changed(id=1, value="52"),
  )
  assert_eq(
    press(slider, 1, size(24, 1), mouse(ScrollUp, 0, 0))[0],
    Changed(id=1, value="50"),
  )
}

///|
test "a slider takes focus and remembers it" {
  let slider = @widget.Slider::new(value=10)
  assert_eq(slider.focusable(), true)
  assert_eq(press(slider, 1, size(24, 1), Focus(true)), [Repaint(id=1)])
}

///|
test "a narrow slider shows only the number" {
  let slider = @widget.Slider::new(value=12345, low=0, high=20000)
  assert_eq(rows(slider, size(5, 1))[0], "12345")
  assert_eq(rows(slider, size(24, 2))[1], "                        ")
}
