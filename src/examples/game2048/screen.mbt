// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
/// The board as a widget: four rows of tiles, each six columns wide, and a line
/// under them that says the score.
pub struct Board {
  grid : Grid
}

///|
fn tile_style(value : Int32) -> @style.Style {
  if value == 0 {
    return @style.Style::new(fg=@theme.muted)
  }
  if value <= 4 {
    return @style.Style::new(fg=@theme.ink)
  }
  if value <= 16 {
    return @style.Style::new(fg=@theme.accent, bold=true)
  }
  if value <= 64 {
    return @style.Style::new(fg=@theme.good, bold=true)
  }
  if value <= 256 {
    return @style.Style::new(fg=@theme.warn, bold=true)
  }
  @style.Style::new(fg=@theme.bad, bold=true)
}

///|
/// A number in a cell six columns wide, with the digits in the middle.
fn tile(value : Int32) -> @strip.Strip {
  if value == 0 {
    return @strip.Strip::of("  ·   ", tile_style(0))
  }
  let text = value.to_string()
  let left = (6 - text.length()) / 2
  let right = 6 - text.length() - left
  let out = StringBuilder()
  for _ in 0..<left {
    out.write_string(" ")
  }
  out.write_string(text)
  for _ in 0..<right {
    out.write_string(" ")
  }
  @strip.Strip::of(out.to_string(), tile_style(value))
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  if row == 4 {
    let word = if self.grid.over() {
      "over — r"
    } else if self.grid.won() {
      "2048 — r"
    } else {
      "arrows · r"
    }
    return @strip.Strip::of(
      "score " + self.grid.score().to_string() + " · " + word,
      @style.Style::new(fg=@theme.muted),
    )
  }
  if row < 0 || row > 3 {
    return @strip.Strip::blank(size.width, @style.default)
  }
  let parts : Array[@strip.Strip] = []
  for x in 0..<4 {
    parts.push(tile(self.grid.cell(x, row)))
  }
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Board with fn hint(_self, _size) {
  @geom.Size::new(24, 5)
}

///|
impl @widget.Widget for Board with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Board with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Up => {
          self.grid.slide(0)
          ctx.repaint()
          true
        }
        Right => {
          self.grid.slide(1)
          ctx.repaint()
          true
        }
        Down => {
          self.grid.slide(2)
          ctx.repaint()
          true
        }
        Left => {
          self.grid.slide(3)
          ctx.repaint()
          true
        }
        Char(114) => {
          self.grid.restart()
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub struct Screen {
  root : @app.Node
  grid : Grid
}

///|
pub fn Screen::new() -> Screen {
  let grid = Grid::new()
  let board : Board = { grid, }
  let head = @theme.header("2048", note="arrows slide · r restarts")
  let foot = @theme.footer([
    ("arrows", "slide"),
    ("r", "restart"),
    ("esc", "quit"),
  ])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.leaf(2, board, box=@layout.Box::new(extent=Cells(5)), classes=[
      "framed",
    ]),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, grid, }
}
