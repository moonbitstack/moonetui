// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a bar chart draws taller columns for larger values" {
  let chart = @widget.BarChart::new(bars=[
    @widget.Bar::new("a", value=4.0),
    @widget.Bar::new("b", value=2.0),
  ])
  let lines = rows(chart, size(10, 5))
  assert_eq(lines.length(), 5)
  assert_eq(lines.iter().any(fn(l) { l.contains("█") }), true)
  assert_eq(lines[4].contains("a"), true)
  assert_eq(lines[4].contains("b"), true)
}

///|
test "a bar chart holds every column to one scale" {
  let chart = @widget.BarChart::new(bars=[
    @widget.Bar::new("a", value=4.0),
    @widget.Bar::new("b", value=2.0),
  ])
  assert_eq(chart.scale(), 4.0)
  chart.set_max(Some(8.0))
  assert_eq(chart.scale(), 8.0)
  chart.set_max(None)
  assert_eq(chart.scale(), 4.0)
  chart.set_bars([@widget.Bar::new("x", value=0.0)])
  assert_eq(chart.scale(), 1.0)
  chart.set_bars([])
  assert_eq(chart.bars().length(), 0)
}

///|
test "a bar chart can show the values above the columns" {
  let chart = @widget.BarChart::new(
    bars=[@widget.Bar::new("a", value=3.0)],
    values=true,
  )
  let lines = rows(chart, size(8, 4))
  assert_eq(lines.length(), 4)
  assert_eq(lines[0].trim() != "", true)
  assert_eq(lines[3].contains("a"), true)
}

///|
test "a bar chart takes neither keys nor a click" {
  let chart = @widget.BarChart::new(bars=[@widget.Bar::new("a", value=1.0)])
  assert_eq(chart.focusable(), false)
  assert_eq(press(chart, 1, size(10, 5), key(Down)), [])
  assert_eq(press(chart, 1, size(10, 5), mouse(Down, 0, 0)), [])
}
