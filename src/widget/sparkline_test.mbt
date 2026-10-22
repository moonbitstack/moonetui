// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "sparkline bins data into bars" {
  let spark = @widget.Sparkline::new(data=[0.0, 10.0])
  let w : &@widget.Widget = spark
  assert_eq(rows(w, size(4, 1)), ["▁▁██"])
  spark.set([0.0, 5.0, 10.0])
  assert_eq(rows(w, size(3, 1)), ["▁▄█"])
  let median = @widget.Sparkline::new(
    data=[1.0, 2.0, 3.0, 4.0],
    summary=@widget.Summary::Median,
  )
  let m : &@widget.Widget = median
  assert_eq(rows(m, size(2, 1)), ["▂▆"])
}

///|
test "sparkline handles empty and single data" {
  let spark = @widget.Sparkline::new()
  let w : &@widget.Widget = spark
  assert_eq(rows(w, size(3, 2)), ["   ", "▁▁▁"])
  spark.set([42.0])
  assert_eq(rows(w, size(3, 2)), ["███", "███"])
}
