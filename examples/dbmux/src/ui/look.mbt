// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The look, under the names this window calls it by. The palette, the key bar
// and the head of a panel are the library's house look; what is left here is
// the table's own furniture: a zebra stripe, the cell under the cursor, the band
// that carries this window's connection.

///|
pub let look : @design.Theme = @design.studio

///|
/// What is there but not meant to be read: a gutter, a NULL, a count.
pub let faint : @style.Colour = look.faint

///|
/// The ground of every other row of a table, one step off the terminal's own.
let stripe : @style.Colour = @style.Colour::rgb(0x12, 0x17, 0x22)

///|
pub let body : @style.Style = look.fg(@design.Text)

///|
pub let quiet : @style.Style = look.quiet()

///|
pub let dim : @style.Style = look.dim()

///|
/// The cell or the character the keys act on.
pub let cursor : @style.Style = @style.Style::new(
  fg=look.colour(@design.Surface),
  bg=look.colour(@design.Primary),
  bold=true,
)

///|
/// A row that is chosen in a list that does not have the keys.
pub let picked : @style.Style = look.cursor()

///|
/// The grid's styles in one place, so a rebuilt table looks like the last one.
/// The cursor is bright only in the pane that has the keys.
pub fn grid_table(active~ : Bool) -> @widget.DataTable {
  @widget.DataTable::new(
    zebra=true,
    header_style=@style.Style::new(fg=look.colour(@design.Muted), bold=true),
    cursor_style=if active { cursor } else { picked },
    hover_style=if active { cursor } else { picked },
    odd_style=body,
    even_style=@style.Style::new(fg=look.colour(@design.Text), bg=stripe),
    label_style=@style.Style::new(fg=look.colour(@design.Warning), bold=true),
    style=body,
  )
}

///|
/// The band along the top: the program, the connection and its engine, the
/// mark a dangerous connection wears, and where the reader is on the right.
pub fn band(state : @shell.State, width~ : Int32) -> @strip.Strip {
  let ground = @style.Style::new(
    fg=look.colour(@design.Text),
    bg=look.colour(@design.Surface),
  )
  let segs : Array[@strip.Seg] = [
    @strip.Seg::new(" dbmux ", look.mark().merge(look.fill(@design.Surface))),
    @strip.Seg::new(
      " " + state.connection,
      @style.Style::new(
        fg=look.colour(@design.Text),
        bg=look.colour(@design.Surface),
        bold=true,
      ),
    ),
    @strip.Seg::new(
      " · " + state.engine.name() + " ",
      @style.Style::new(
        fg=look.colour(@design.Muted),
        bg=look.colour(@design.Surface),
      ),
    ),
  ]
  let badge = state.badge()
  if badge != "" {
    let colour = if state.production {
      look.colour(@design.Error)
    } else {
      look.colour(@design.Warning)
    }
    segs.push(@strip.Seg::new(" ", ground))
    segs.push(
      @strip.Seg::new(
        " " + badge + " ",
        @style.Style::new(fg=look.colour(@design.Surface), bg=colour, bold=true),
      ),
    )
  }
  let tail = @strip.Strip::of(
    state.status() + " ",
    @style.Style::new(
      fg=look.colour(@design.Muted),
      bg=look.colour(@design.Surface),
    ),
  )
  let room = @cmp.maximum(0, width - @strip.str_cells(tail.text()))
  let lead = @strip.Strip::from_segs(segs).crop(0, room).pad_to(room, ground)
  @strip.Strip::join([lead, tail]).crop(0, width).pad_to(width, ground)
}

///|
/// The key bar at the foot: each key in its cap and its meaning beside it.
pub fn keys(pairs : Array[(String, String)], width~ : Int32) -> @strip.Strip {
  look.keys(pairs, width~)
}

///|
/// The head of a panel: its name, a hairline to the edge, and a count. The
/// panel with the keys says so in `tone`.
pub fn head(
  name : String,
  count~ : String = "",
  width~ : Int32,
  active~ : Bool = false,
  tone~ : @style.Colour? = None,
) -> @strip.Strip {
  look.panel_head(name, count~, width~, active~, tone~)
}

///|
/// One row drawn by a function of its width, read again on every frame.
pub fn line(draw : (Int32) -> @strip.Strip) -> &@widget.Widget {
  @widget.StripRow::new(draw)
}

///|
/// A hairline down the height, so two panels read as two.
pub fn divider() -> &@widget.Widget {
  @widget.Rule::vertical(style=look.edge())
}
