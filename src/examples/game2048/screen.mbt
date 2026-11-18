// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
/// The board as a widget: four by four tiles, each seven columns and three rows,
/// one cell apart on a ground of their own.
pub struct Board {
  grid : Grid
}

///|
/// Columns and rows of one tile.
const TILE_W : Int32 = 7

///|
const TILE_H : Int32 = 3

///|
/// The board's width and height: four tiles and the gaps around them.
pub const BOARD_W : Int32 = 4 * TILE_W + 5

///|
pub const BOARD_H : Int32 = 4 * TILE_H + 5

///|
let board_ground : @style.Style = @style.Style::new(bg=@theme.surface)

///|
/// The block a tile sits on, warming as the number doubles: a raised slot when
/// empty, then the accent, the second accent, green, amber and rose.
fn block_style(value : Int32) -> @style.Style {
  let dark = @style.Rgb(0x10, 0x14, 0x1f)
  if value == 0 {
    return @style.Style::new(fg=@theme.faint, bg=@style.Rgb(0x22, 0x29, 0x3a))
  }
  if value <= 4 {
    return @style.Style::new(
      fg=@theme.ink,
      bg=@style.Rgb(0x34, 0x3d, 0x55),
      bold=true,
    )
  }
  if value <= 16 {
    return @style.Style::new(fg=dark, bg=@theme.accent, bold=true)
  }
  if value <= 64 {
    return @style.Style::new(fg=dark, bg=@theme.accent_alt, bold=true)
  }
  if value <= 256 {
    return @style.Style::new(fg=dark, bg=@theme.good, bold=true)
  }
  if value <= 1024 {
    return @style.Style::new(fg=dark, bg=@theme.warn, bold=true)
  }
  @style.Style::new(fg=dark, bg=@theme.bad, bold=true)
}

///|
/// One row of a tile: the number on the middle row, centred, the rest of the
/// block plain. A tile that just took a merge is lit, which is the animation.
fn tile_row(value : Int32, line : Int32, flashing : Bool) -> @strip.Strip {
  let style = if flashing && value > 0 {
    @style.Style::new(fg=@theme.surface, bg=@theme.cool, bold=true)
  } else {
    block_style(value)
  }
  let text = if line == TILE_H / 2 && value > 0 {
    value.to_string()
  } else {
    ""
  }
  let used = text.length()
  let left = (TILE_W - used) / 2
  @strip.Strip::of(
    @theme.repeat(" ", left) + text + @theme.repeat(" ", TILE_W - used - left),
    style,
  )
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  let top = if size.height > BOARD_H { (size.height - BOARD_H) / 2 } else { 0 }
  let at = row - top
  if at < 0 || at >= BOARD_H {
    return @strip.Strip::blank(width, @style.default)
  }
  let left = if width > BOARD_W { (width - BOARD_W) / 2 } else { 0 }
  // Every fourth row from the top edge is a gap; the rows between are tiles.
  let band = (at - 1) / (TILE_H + 1)
  let line = (at - 1) % (TILE_H + 1)
  let body = if at == 0 || line == TILE_H || band >= 4 {
    @strip.Strip::blank(BOARD_W, board_ground)
  } else {
    let parts = [@strip.Strip::blank(1, board_ground)]
    for x in 0..<4 {
      parts.push(
        tile_row(self.grid.cell(x, band), line, self.grid.flashing(x, band)),
      )
      parts.push(@strip.Strip::blank(1, board_ground))
    }
    @strip.Strip::join(parts)
  }
  @strip.Strip::join([@strip.Strip::blank(left, @style.default), body]).pad_to(
    width, @style.default,
  )
}

///|
impl @widget.Widget for Board with fn hint(_self, _size) {
  @geom.Size::new(BOARD_W, BOARD_H)
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
  let band = @theme.line(width => {
    let note = if grid.over() {
      "game over · score \{grid.score()}"
    } else if grid.won() {
      "2048 · score \{grid.score()}"
    } else {
      "score \{grid.score()} · best \{grid.best()}"
    }
    @theme.band("moonetui", subject="2048", note~, width~)
  })
  let keys = @theme.line(width => {
    @theme.keys([("arrows", "slide"), ("r", "restart"), ("q", "quit")], width~)
  })
  let root = @app.column(0, [
    @app.leaf(1, band, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, board, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, keys, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, grid, }
}
