// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A service monitor: tabs over a table, a tree and a feed, a sparkline, a load
// bar and a clock that a timer keeps moving, and a command line under them.

///|
/// The monitors wear the examples' sheet: the same frame, the same bar, the
/// same blue as the rest of the directory.
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
/// The latencies the services start from, in milliseconds.
let latencies : Array[Double] = [12.0, 34.0, 210.0, 56.0]

///|
/// The services table the timer keeps ticking.
fn services() -> @widget.DataTable {
  let table = @widget.DataTable::new(
    zebra=true,
    header_style=@theme.mark,
    cursor_style=@theme.cursor,
    even_style=@style.Style::new(bg=@theme.surface),
  )
  ignore(table.add_column("service", width=12))
  ignore(table.add_column("state", width=8))
  ignore(table.add_column("latency", width=7, align=@widget.Align::Right))
  ignore(table.add_row(["gateway", "ok", "12"]))
  ignore(table.add_row(["auth", "ok", "34"]))
  ignore(table.add_row(["billing", "degraded", "210"]))
  ignore(table.add_row(["search", "ok", "56"]))
  table
}

///|
/// The region tree on the second pane.
fn regions() -> @widget.Tree {
  let tree = @widget.Tree::new(root_label="fleet")
  tree.expand(tree.root_id())
  let eu = tree.add(tree.root_id(), "eu-west", expand=true)
  let ap = tree.add(tree.root_id(), "ap-east", expand=true)
  ignore(tree.add_leaf(eu, "gateway-1"))
  ignore(tree.add_leaf(eu, "auth-1"))
  ignore(tree.add_leaf(ap, "gateway-2"))
  tree
}

///|
/// The screen, with the widgets the timer and the command line reach for kept
/// beside the tree they sit in. `main` and the frame tests build it from this
/// one function, so what the tests drive is what a reader runs.
pub struct Monitor {
  root : @app.Node
  tabs : @widget.TabbedContent
  table : @widget.DataTable
  feed : @widget.RichLog
  spark : @widget.Sparkline
  load : @widget.Progress
  clock : @widget.Digits
  cmd : @widget.Input
  series : Array[Double]
  mut tick : Int32
}

///|
pub fn Monitor::new() -> Monitor {
  let table = services()
  let tree = regions()
  let feed = @widget.RichLog::new(max_lines=200)
  feed.write("monitor started", style=@style.Style::new(fg=@theme.cool))
  let panes : Array[&@widget.Widget] = [table, tree, feed]
  let bar = @widget.Tabs::new(
    labels=["services", "regions", "feed"],
    style=@theme.quiet,
    active_style=@theme.title,
    bar_style=@theme.edge,
    bar_highlight=@theme.live,
  )
  let tabs = @widget.TabbedContent::from_tabs(bar, panes)
  let series = latencies.copy()
  let spark = @widget.Sparkline::new(
    data=series.copy(),
    summary=@widget.Maximum,
    min_colour=@theme.good,
    max_colour=@theme.bad,
  )
  let load = @widget.Progress::new(
    total=100,
    style=@theme.faint_style,
    bar_style=@style.Style::new(fg=@theme.accent),
  )
  let clock = @widget.Digits::new(value="00:00", style=@theme.body)
  let cmd = @widget.Input::new(
    placeholder="sort, alert or quit, then enter",
    caret=Underline(blink=true),
  )
  let head = @theme.line(width => {
    @theme.band(
      "moonetui",
      subject="monitor",
      note="4 services · 3 hosts",
      width~,
    )
  })
  let foot = @theme.line(width => {
    @theme.keys([("tab", "panes"), ("enter", "send"), ("esc", "quit")], width~)
  })
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.row(
      2,
      [
        @app.leaf(3, tabs, box=@layout.Box::new(extent=Frac(2)), classes=[
          "framed",
        ]),
        @app.column(
          4,
          [
            @app.leaf(5, spark, box=@layout.Box::new(extent=Cells(1))),
            @app.leaf(6, load, box=@layout.Box::new(extent=Cells(1))),
            @app.leaf(7, clock, box=@layout.Box::new(extent=Cells(3))),
          ],
          box=@layout.Box::new(extent=Frac(1)),
          gap=1,
          classes=["framed"],
        ),
      ],
      box=@layout.Box::new(extent=Frac(1)),
      gap=1,
    ),
    @app.leaf(8, cmd, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(9, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, tabs, table, feed, spark, load, clock, cmd, series, tick: 0, }
}

///|
/// Answers a line from the command line; true when the line asks to quit.
pub fn Monitor::answer(self : Monitor, value : String) -> Bool {
  let line = value.to_lower()
  self.cmd.set("")
  if line == "quit" {
    return true
  }
  if line == "sort" {
    self.table.sort(2, reverse=true)
    self.feed.write(
      "sorted by latency",
      style=@style.Style::new(fg=@theme.good),
    )
  } else if line == "alert" {
    self.feed.write(
      "manual alert raised",
      style=@style.Style::new(fg=@theme.bad, bold=true),
    )
  } else {
    self.feed.write("> " + value)
  }
  false
}

///|
/// One second of the clock: a latency moves, the load bar with it, and a spike
/// over 180 ms every fifth second goes to the feed.
pub fn Monitor::step(self : Monitor) -> Unit {
  self.tick = self.tick + 1
  let tick = self.tick
  let two = fn(n : Int32) {
    if n < 10 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }
  self.clock.update(two(tick / 60 % 100) + ":" + two(tick % 60))
  let jitter = 40 + tick * 7 % 160
  let row = tick * 3 % 4
  self.table.set_cell(row, 2, jitter.to_string())
  self.series[row] = jitter.to_double()
  self.spark.set(self.series.copy())
  self.load.set(tick * 4 % 101)
  if jitter > 180 && tick % 5 == 0 {
    self.feed.write(
      "latency spike: " + jitter.to_string() + "ms",
      style=@style.Style::new(fg=@theme.warn),
    )
  }
}
