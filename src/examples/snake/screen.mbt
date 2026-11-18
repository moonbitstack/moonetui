// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The game wears the examples' sheet, so its title and its key bar sit where
/// every other example puts them.
pub fn sheet() -> @design.Stylesheet {
  // A game covers the window: no frame around the field, no focus border, and
  // a header that stays out of the way.
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
  let head = @theme.line(width => {
    let note = match board.phase() {
      Title => "space starts"
      Playing => "eat, grow, keep off the walls"
      Paused => "paused"
      Over => "game over"
    }
    @theme.band("moonetui", subject="snake", note~, width~)
  })
  let foot = @theme.line(width => {
    @theme.keys(
      [("arrows", "turn"), ("space", "pause"), ("r", "again"), ("q", "quit")],
      width~,
    )
  })
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, board, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, board, }
}
