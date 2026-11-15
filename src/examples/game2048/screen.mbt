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
/// The block a tile sits on: dark blue at four, hot rose past two hundred and
/// fifty-six, so the board reads as a board even through a squint.
fn block_style(value : Int32) -> @style.Style {
  if value <= 4 {
    return @style.Style::new(fg=@theme.ink, bg=@style.Rgb(0x2a, 0x2e, 0x44))
  }
  if value <= 16 {
    return @style.Style::new(fg=@style.black, bg=@theme.accent, bold=true)
  }
  if value <= 64 {
    return @style.Style::new(fg=@style.black, bg=@theme.good, bold=true)
  }
  if value <= 256 {
    return @style.Style::new(fg=@style.black, bg=@theme.warn, bold=true)
  }
  @style.Style::new(fg=@style.black, bg=@theme.bad, bold=true)
}

///|
/// A number in a cell `width` columns wide, on a block of its own colour: the
/// bigger the number, the hotter the block. A cell that just took a merge is
/// lit, which is the whole animation.
fn tile(value : Int32, width : Int32, flashing : Bool) -> @strip.Strip {
  let style = if flashing {
    @style.Style::new(fg=@style.black, bg=@theme.accent_alt, bold=true)
  } else {
    block_style(value)
  }
  if value == 0 {
    return @strip.Strip::blank(width, @style.Style::new(fg=@theme.muted))
  }
  let text = value.to_string()
  let left = (width - text.length()) / 2
  let right = width - text.length() - left
  let out = StringBuilder()
  for _ in 0..<left {
    out.write_string(" ")
  }
  out.write_string(text)
  for _ in 0..<right {
    out.write_string(" ")
  }
  @strip.Strip::of(out.to_string(), style)
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
  // The board takes the width it is given, four tiles across.
  let across = if size.width >= 4 { size.width / 4 } else { 4 }
  let parts : Array[@strip.Strip] = []
  for x in 0..<4 {
    parts.push(tile(self.grid.cell(x, row), across, self.grid.flashing(x, row)))
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
