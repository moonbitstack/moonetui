// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The demo wears the examples' sheet: the same header, the same frame, the
/// same bar as every other screen in this directory.
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
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
/// The demo, with the widgets a handler reaches for kept beside the tree they
/// sit in. `main` and the frame tests build the same screen from this one
/// function, so what the tests drive is what a reader runs.
pub struct Demo {
  root : @app.Node
  list : @widget.ListView
  field : @widget.Input
  bar : @widget.Progress
}

///|
pub fn Demo::new() -> Demo {
  let head = @theme.header("moonetui", note="esc · q to quit")
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon", "中文也对齐",
  ])
  let field = @widget.Input::new(placeholder="type here")
  let bar = @widget.Progress::new(total=100)
  let foot = @theme.footer([
    ("tab", "next"),
    ("up down", "move"),
    ("enter", "choose"),
    ("wheel", "scroll"),
  ])
  bar.set(35)
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.scroll(6, pane(list), box=@layout.Box::new(extent=Frac(1)), classes=[
      "framed",
    ]),
    dial(bar, field),
    @app.leaf(5, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, list, field, bar, }
}

///|
/// What the demo does with what a widget reports: a chosen row becomes the
/// field's text and moves the bar on, exactly as `main` answers it.
pub fn Demo::answer(self : Demo, reports : Array[@widget.Out]) -> Unit {
  for report in reports {
    match report {
      Selected(index~, ..) => {
        self.field.set(self.list.items()[index])
        self.bar.advance(10)
      }
      _ => ()
    }
  }
}
