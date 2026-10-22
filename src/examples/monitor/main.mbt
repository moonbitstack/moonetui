// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The stylesheet: base text colour, a chrome bar, framed panes, and a
/// heavy border for whatever holds focus.
fn sheet() -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=@style.bright_white)),
  )
  sheet.add(
    @design.Sel::new(name="Header"),
    @design.Styles::new(text=@style.Style::new(bold=true, fg=@style.cyan)),
  )
  sheet.add(
    @design.Sel::new(classes=["framed"]),
    @design.Styles::new(
      border=@design.Round,
      padding=@geom.Spacing::horizontal(1),
    ),
  )
  sheet.add(
    @design.Sel::new(focus=true),
    @design.Styles::new(border=@design.Heavy),
  )
  sheet
}

///|
/// The services table the timer keeps ticking.
fn services() -> @widget.DataTable {
  let table = @widget.DataTable::new(zebra=true)
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
fn main raise {
  let head = @widget.Header::new("monitor", note="ctrl-c to quit")
  let table = services()
  let tree = regions()
  let feed = @widget.RichLog::new(max_lines=200)
  feed.write("monitor started", style=@style.Style::new(fg=@style.cyan))
  let panes : Array[&@widget.Widget] = [table, tree, feed]
  let tabs = @widget.TabbedContent::new(
    labels=["services", "regions", "feed"],
    panes~,
  )
  let spark = @widget.Sparkline::new(
    data=[12.0, 34.0, 210.0, 56.0],
    summary=@widget.Maximum,
  )
  let load = @widget.Progress::new(total=100)
  let clock = @widget.Digits::new(value="00:00")
  let cmd = @widget.Input::new(placeholder="type a command, enter to send")
  let foot = @widget.Footer::new([
    ("tab", "panes"),
    ("enter", "send"),
    ("sort", "table"),
    ("alert", "feed"),
  ])
  let tree_ui = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
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
        ),
      ],
      box=@layout.Box::new(extent=Frac(1)),
      gap=1,
    ),
    @app.leaf(8, cmd, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(9, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  let tty = @native.NativeTty::new()
  let ui = @app.App::new(tty, tree_ui, sheet=sheet())
  let mut tick = 0
  // The widgets answer through typed messages; the hook answers back.
  ui.on(report => {
    match report {
      Submitted(value~, ..) => {
        let line = value.to_lower()
        if line == "quit" {
          ui.quit()
        } else if line == "sort" {
          table.sort(2, reverse=true)
          feed.write(
            "sorted by latency",
            style=@style.Style::new(fg=@style.green),
          )
        } else if line == "alert" {
          feed.write(
            "manual alert raised",
            style=@style.Style::new(fg=@style.red, bold=true),
          )
        } else {
          feed.write("> " + value)
        }
        cmd.set("")
        ui.refresh()
        true
      }
      _ => false
    }
  })
  // A second of life: the clock turns, the latency jitters, the bars move.
  ui.every(1000, () => {
    tick = tick + 1
    clock.update(
      "0" +
      (tick / 60 % 10).to_string() +
      ":" +
      (if tick % 60 < 10 { "0" } else { "" }) +
      (tick % 60).to_string(),
    )
    let jitter = 40 + tick * 7 % 160
    table.set_cell(tick * 3 % 4, 2, jitter.to_string())
    let series = [12.0, 34.0, 210.0, 56.0]
    series[tick * 3 % 4] = jitter.to_double()
    spark.set(series)
    load.set(tick * 4 % 101)
    if jitter > 180 && tick % 5 == 0 {
      feed.write(
        "latency spike: " + jitter.to_string() + "ms",
        style=@style.Style::new(fg=@style.red),
      )
    }
    ui.refresh()
  })
  ui.run()
}
