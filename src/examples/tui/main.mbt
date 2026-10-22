// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
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
  sheet.add(
    @design.Sel::new(classes=["bar"]),
    @design.Styles::new(dock=@design.Bottom),
  )
  sheet
}

///|
fn pane(list : @widget.ListView) -> @app.Node {
  let kids : Array[@app.Node] = [
    @app.leaf(10, list, box=@layout.Box::new(extent=Cells(6))),
  ]
  for i in 0..<24 {
    kids.push(
      @app.leaf(11 + i, @widget.Static::new("log line " + (i + 1).to_string())),
    )
  }
  @app.column(7, kids, gap=1)
}

///|
fn dial(bar : @widget.Progress, field : @widget.Input) -> @app.Node {
  @app.grid(
    8,
    [
      @app.leaf(4, bar),
      @app.leaf(3, field, styles=@design.Styles::new(column_span=2)),
    ],
    cols=2,
    gutter=1,
  )
}

///|
fn main raise {
  let head = @widget.Header::new("moonetui", note="ctrl-c to quit")
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon", "中文也对齐",
  ])
  let field = @widget.Input::new(placeholder="type here")
  let bar = @widget.Progress::new(total=100)
  let foot = @widget.Footer::new([
    ("tab", "next"),
    ("up down", "move"),
    ("enter", "choose"),
    ("wheel", "scroll"),
  ])
  bar.set(35)
  let tree = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.scroll(6, pane(list), box=@layout.Box::new(extent=Frac(1)), classes=[
      "framed",
    ]),
    dial(bar, field),
    @app.leaf(5, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  let tty = @native.NativeTty::new()
  let ui = @app.App::new(tty, tree, sheet=sheet())
  ui.start()
  @native.run(() => {
    let alive = ui.step()
    for report in ui.drain() {
      match report {
        Selected(index~, ..) => {
          field.set(list.items()[index])
          bar.advance(10)
          ui.refresh()
        }
        _ => ()
      }
    }
    alive
  })
  ui.stop()
}
