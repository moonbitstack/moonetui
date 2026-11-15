// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
pub struct Screen {
  root : @app.Node
  field : Field
}

///|
pub fn Screen::new() -> Screen {
  let field = Field::new()
  let head = @theme.header("life", note="space pauses · r reseeds · . steps")
  let foot = @theme.footer([
    ("space", "pause"),
    ("r", "reseed"),
    (".", "step"),
    ("esc", "quit"),
  ])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.leaf(2, field, box=@layout.Box::new(extent=Cells(field.rows + 1)), classes=[
      "framed",
    ]),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, field, }
}
