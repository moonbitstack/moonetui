// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a chart plots a line and scatter series with a legend" {
  let chart = @widget.Chart::new(
    datasets=[
      @widget.Dataset::new("load", [(0.0, 0.0), (1.0, 2.0), (2.0, 4.0)]),
      @widget.Dataset::new(
        "spikes",
        [(0.0, 4.0), (1.0, 1.0), (2.0, 3.0)],
        kind=Scatter,
      ),
    ],
    y=@widget.Axis::new(bounds=@widget.Bounds::new(low=0.0, high=4.0)),
  )
  let w : &@widget.Widget = chart
  let lines = rows(w, size(20, 7))
  assert_eq(lines[0].has_prefix("• load ▪ spikes"), true)
  assert_eq(lines[1].trim_end().has_suffix("▪"), true)
  assert_eq(lines[6].trim_end().has_suffix("•"), true)
  assert_eq(lines[0].length(), 20)
}

///|
test "a chart draws the words on both of its axes" {
  let chart = @widget.Chart::new(
    datasets=[@widget.Dataset::new("a", [(0.0, 1.0), (1.0, 3.0)])],
    x=@widget.Axis::new(
      labels=["mon", "tue"],
      bounds=@widget.Bounds::new(low=0.0, high=1.0),
      title="day",
    ),
    y=@widget.Axis::new(
      labels=["0", "2", "4"],
      bounds=@widget.Bounds::new(low=0.0, high=4.0),
    ),
    legend=false,
  )
  let lines = rows(chart, size(16, 6))
  assert_eq(lines[0].has_prefix("4 "), true)
  assert_eq(lines[4].contains("mon"), true)
  assert_eq(lines[4].contains("tue"), true)
  assert_eq(lines[5].contains("day"), true)
  assert_eq(chart.bounds(), @widget.Bounds::new(low=0.0, high=4.0))
}

///|
test "a chart takes its bounds from the data when it is given none" {
  let chart = @widget.Chart::new(datasets=[
    @widget.Dataset::new("a", [(0.0, 2.0), (1.0, 8.0)]),
  ])
  assert_eq(chart.bounds().low, 2.0)
  assert_eq(chart.bounds().high > 8.0, true)
  let empty = @widget.Chart::new()
  assert_eq(empty.bounds(), @widget.Bounds::new(low=0.0, high=1.0))
  let flat = @widget.Chart::new(datasets=[
    @widget.Dataset::new("a", [(0.0, 5.0)]),
  ])
  assert_eq(flat.bounds().high > flat.bounds().low, true)
}

///|
test "a chart takes no input and fills the box it is given" {
  let chart = @widget.Chart::new(datasets=[
    @widget.Dataset::new("a", [(0.0, 1.0)]),
  ])
  let w : &@widget.Widget = chart
  assert_eq(w.focusable(), false)
  assert_eq(press(w, 1, size(20, 6), key(Down)), [])
  assert_eq(w.hint(size(20, 6)), size(20, 6))
  chart.set_datasets([@widget.Dataset::new("b", [(0.0, 1.0)])])
  chart.set_x(@widget.Axis::new(title="x"))
  chart.set_y(@widget.Axis::new(title="y"))
  assert_eq(chart.datasets().length(), 1)
}

///|
test "a bar chart stands a column for every bar" {
  let chart = @widget.BarChart::new(bars=[
    @widget.Bar::new("a", value=2.0),
    @widget.Bar::new("b", value=4.0),
  ])
  let w : &@widget.Widget = chart
  assert_eq(w.hint(size(9, 5)), size(9, 5))
  assert_eq(rows(w, size(9, 5)), [
    "     ████", "     ████", "████ ████", "████ ████",
    "a    b   ",
  ])
  assert_eq(chart.scale(), 4.0)
}

///|
test "a bar chart holds to a scale it is given" {
  let chart = @widget.BarChart::new(
    bars=[@widget.Bar::new("a", value=2.0), @widget.Bar::new("b", value=4.0)],
    max=Some(8.0),
    values=true,
  )
  let w : &@widget.Widget = chart
  assert_eq(rows(w, size(9, 5)), [
    " 2    4  ", "         ", "     ████", "████ ████", "a    b   ",
  ])
  chart.set_max(None)
  assert_eq(chart.scale(), 4.0)
  chart.set_bars([@widget.Bar::new("c", value=1.0)])
  assert_eq(chart.bars().length(), 1)
}

///|
test "a bar chart with nothing to draw is blank" {
  let chart = @widget.BarChart::new()
  let w : &@widget.Widget = chart
  assert_eq(chart.scale(), 1.0)
  assert_eq(w.focusable(), false)
  assert_eq(rows(w, size(6, 3)), ["      ", "      ", "      "])
}

///|
test "a gauge shows how far round it is" {
  let gauge = @widget.Gauge::new(ratio=0.5, label="load")
  let w : &@widget.Widget = gauge
  assert_eq(gauge.percent(), 50)
  assert_eq(w.hint(size(20, 4)), size(20, 1))
  assert_eq(rows(w, size(20, 1)), ["load ██████░░░░░ 50%"])
  assert_eq(w.focusable(), false)
  assert_eq(press(w, 1, size(20, 1), key(Down)), [])
}

///|
test "a gauge holds its ratio between nothing and all of it" {
  let gauge = @widget.Gauge::new()
  assert_eq(gauge.ratio(), 0.0)
  gauge.set_ratio(2.0)
  assert_eq(gauge.ratio(), 1.0)
  gauge.set_ratio(-1.0)
  assert_eq(gauge.ratio(), 0.0)
  gauge.set_label("memory")
  assert_eq(gauge.label(), "memory")
  assert_eq(gauge.percent(), 0)
}

///|
test "a vertical scrollbar shows a thumb in a track" {
  let bar = @widget.Scrollbar::new(content=20, viewport=10)
  let w : &@widget.Widget = bar
  assert_eq(w.hint(size(4, 10)), size(1, 10))
  assert_eq(bar.is_needed(), true)
  assert_eq(bar.max(), 10)
  assert_eq(bar.thumb(10), (0, 5))
  assert_eq(rows(w, size(1, 10)), [
    "█", "█", "█", "█", "█", "░", "░", "░", "░", "░",
  ])
}

///|
test "a scrollbar moves by keys and reports where it went" {
  let bar = @widget.Scrollbar::new(content=20, viewport=10)
  let w : &@widget.Widget = bar
  let out = press(w, 3, size(1, 10), key(Down))
  assert_eq(out, [@widget.Scrolled(id=3, x=0, y=1), @widget.Repaint(id=3)])
  ignore(press(w, 3, size(1, 10), key(PageDown)))
  assert_eq(bar.position(), 10)
  assert_eq(press(w, 3, size(1, 10), key(Down)), [])
  ignore(press(w, 3, size(1, 10), key(Home)))
  assert_eq(bar.position(), 0)
  ignore(press(w, 3, size(1, 10), key(End)))
  assert_eq(bar.position(), 10)
  assert_eq(bar.thumb(10), (5, 5))
  assert_eq(w.focusable(), true)
}

///|
test "a scrollbar goes to the part of the track that was clicked" {
  let bar = @widget.Scrollbar::new(content=20, viewport=10)
  let w : &@widget.Widget = bar
  let out = press(
    w,
    3,
    size(1, 10),
    Mouse({ kind: Down, button: 0, x: 0, y: 8, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=3),
    @widget.Scrolled(id=3, x=0, y=10),
    @widget.Repaint(id=3),
  ])
  assert_eq(bar.position(), 10)
  assert_eq(
    press(
      w,
      3,
      size(1, 10),
      Mouse({ kind: ScrollUp, button: 0, x: 0, y: 3, mods: @event.none, }),
    ),
    [@widget.Scrolled(id=3, x=0, y=9), @widget.Repaint(id=3)],
  )
}

///|
test "a horizontal scrollbar lies along a row" {
  let bar = @widget.Scrollbar::new(content=10, viewport=5, vertical=false)
  let w : &@widget.Widget = bar
  assert_eq(w.hint(size(10, 3)), size(10, 1))
  assert_eq(rows(w, size(10, 1)), ["█████░░░░░"])
  assert_eq(rows(w, size(10, 2))[1], "          ")
  ignore(press(w, 3, size(10, 1), key(Right)))
  assert_eq(press(w, 3, size(10, 1), key(Right)), [
    @widget.Scrolled(id=3, x=2, y=0),
    @widget.Repaint(id=3),
  ])
  assert_eq(bar.is_vertical(), false)
  assert_eq(bar.content(), 10)
  assert_eq(bar.viewport(), 5)
}

///|
test "a scrollbar with nothing to scroll has no thumb" {
  let bar = @widget.Scrollbar::new(content=5, viewport=5)
  let w : &@widget.Widget = bar
  assert_eq(bar.is_needed(), false)
  assert_eq(bar.max(), 0)
  assert_eq(bar.thumb(5), (0, 5))
  assert_eq(press(w, 3, size(1, 5), key(Down)), [])
  assert_eq(rows(w, size(1, 3)), ["█", "█", "█"])
  let empty = @widget.Scrollbar::new()
  assert_eq(empty.thumb(5), (0, 0))
}
