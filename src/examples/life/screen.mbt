// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn sheet() -> @design.Stylesheet {
  // The field is the page: no frame around it, and a header that stays quiet.
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=@theme.ink)),
  )
  sheet.add(
    @design.Sel::new(name="Header"),
    @design.Styles::new(text=@style.Style::new(fg=@theme.muted)),
  )
  sheet.add(
    @design.Sel::new(classes=["bar"]),
    @design.Styles::new(dock=@design.Bottom),
  )
  sheet
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
    @app.leaf(2, field, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, field, }
}
