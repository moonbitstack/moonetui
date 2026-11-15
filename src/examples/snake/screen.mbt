// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The game wears the examples' sheet, so its title and its key bar sit where
/// every other example puts them.
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
/// The screen: a title, the board, and the keys at the bottom. `main` and the
/// frame test build it from this one function, so what the test drives is what
/// a reader plays.
pub struct Screen {
  root : @app.Node
  board : Board
}

///|
pub fn Screen::new() -> Screen {
  let board = Board::new()
  let head = @theme.header(
    "snake",
    note="space starts · arrows turn · esc quits",
  )
  let foot = @theme.footer([
    ("arrows", "turn"),
    ("space", "pause"),
    ("r", "again"),
    ("esc", "quit"),
  ])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.leaf(2, board, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, board, }
}
