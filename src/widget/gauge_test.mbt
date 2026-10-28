// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a gauge shows its label, a bar and the percentage" {
  let gauge = @widget.Gauge::new(ratio=0.5, label="load")
  let line = gauge.render_line(0, size(20, 1))
  assert_eq(line.text().contains("load"), true)
  assert_eq(line.text().contains("50%"), true)
  assert_eq(line.text().contains("█"), true)
  assert_eq(line.text().contains("░"), true)
  assert_eq(gauge.hint(size(20, 4)), size(20, 1))
}

///|
test "a gauge clamps the ratio it is given" {
  let gauge = @widget.Gauge::new()
  gauge.set_ratio(2.0)
  assert_eq(gauge.ratio(), 1.0)
  assert_eq(gauge.percent(), 100)
  gauge.set_ratio(-1.0)
  assert_eq(gauge.ratio(), 0.0)
  assert_eq(gauge.percent(), 0)
  gauge.set_ratio(0.5)
  assert_eq(gauge.percent(), 50)
  gauge.set_label("cpu")
  assert_eq(gauge.label(), "cpu")
}

///|
test "a gauge takes neither keys nor a click" {
  let gauge = @widget.Gauge::new(ratio=0.5)
  assert_eq(gauge.focusable(), false)
  assert_eq(press(gauge, 1, size(20, 1), key(Down)), [])
  assert_eq(press(gauge, 1, size(20, 1), mouse(Down, 0, 0)), [])
}
