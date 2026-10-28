// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn chart() -> Demo {
  let load = @widget.Chart::new(
    datasets=[
      @widget.Dataset::new(
        "cpu",
        [(0.0, 1.0), (1.0, 3.0), (2.0, 2.0), (3.0, 5.0), (4.0, 4.0), (5.0, 6.0)],
        style=@style.Style::new(fg=@style.cyan),
      ),
      @widget.Dataset::new(
        "mem",
        [(0.0, 2.0), (1.0, 2.0), (2.0, 4.0), (3.0, 3.0), (4.0, 5.0), (5.0, 5.0)],
        kind=Scatter,
        style=@style.Style::new(fg=@style.magenta),
      ),
    ],
    x=@widget.Axis::new(
      labels=["0s", "5s", "10s"],
      bounds=@widget.Bounds::new(low=0.0, high=5.0),
      title="time",
    ),
    y=@widget.Axis::new(bounds=@widget.Bounds::new(low=0.0, high=6.0)),
  )
  Demo::new(
    "Chart",
    @app.column(0, [@app.leaf(1, load)]),
    group=Chart,
    note="Series of points on two axes: one joined from point to point, one left as the points themselves.",
    rows=10,
  )
}

///|
pub fn bar_chart() -> Demo {
  let chart = @widget.BarChart::new(
    bars=[
      @widget.Bar::new(
        "mon",
        value=5.0,
        style=Some(@style.Style::new(fg=@style.cyan)),
      ),
      @widget.Bar::new("tue", value=8.0),
      @widget.Bar::new("wed", value=3.0),
      @widget.Bar::new("thu", value=6.0),
      @widget.Bar::new("fri", value=9.0),
    ],
    values=true,
  )
  Demo::new(
    "BarChart",
    @app.column(0, [@app.leaf(1, chart)]),
    group=Chart,
    note="A column per bar, named along the bottom, the tallest filling the plot unless a scale is given.",
    rows=8,
  )
}

///|
pub fn gauge() -> Demo {
  let cpu = @widget.Gauge::new(ratio=0.62, label="cpu")
  let memory = @widget.Gauge::new(
    ratio=0.35,
    label="memory",
    bar_style=@style.Style::new(fg=@style.green),
  )
  let disk = @widget.Gauge::new(
    ratio=0.91,
    label="disk",
    bar_style=@style.Style::new(fg=@style.red),
  )
  Demo::new(
    "Gauge",
    @app.column(0, [
      @app.leaf(1, cpu, box=line(1)),
      @app.leaf(2, memory, box=line(1)),
      @app.leaf(3, disk, box=line(1)),
    ]),
    group=Chart,
    note="How far round a meter is: a word on the left, a bar, and the percentage on the right.",
    rows=3,
  )
}

///|
pub fn scrollbar() -> Demo {
  let bar = @widget.Scrollbar::new(content=100, viewport=24)
  let across = @widget.Scrollbar::new(
    content=100,
    viewport=24,
    vertical=false,
    thumb_style=@style.Style::new(fg=@style.cyan, reverse=true),
  )
  let lines : Array[@app.Node] = []
  for i in 0..<6 {
    lines.push(
      @app.leaf(
        10 + i,
        @widget.Static::new("line " + i.to_string()),
        box=line(1),
      ),
    )
  }
  Demo::new(
    "Scrollbar",
    @app.column(0, [
      @app.row(
        1,
        [
          @app.column(2, lines),
          @app.leaf(3, bar, box=@layout.Box::new(extent=Cells(1))),
        ],
        box=line(6),
      ),
      @app.leaf(4, across, box=line(1)),
    ]),
    group=Chart,
    note="A thumb in a track, on either axis: a click goes to that part of the content, and the keys move once it has focus.",
    rows=7,
  )
}
