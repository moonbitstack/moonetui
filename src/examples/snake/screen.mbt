// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The stylesheet the game is drawn in: a cyan title, a docked bar of keys,
/// and a heavy border around the playfield.
pub fn sheet() -> @design.Stylesheet {
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
    @design.Sel::new(classes=["bar"]),
    @design.Styles::new(dock=@design.Bottom),
  )
  sheet
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
  let head = @widget.Header::new("snake", note="arrows turn · space pauses")
  let foot = @widget.Footer::new([
    ("arrows", "turn"),
    ("space", "pause"),
    ("r", "again"),
    ("esc", "quit"),
  ])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.leaf(2, board, box=@layout.Box::new(extent=Cells(board.rows() + 2))),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, board, }
}
