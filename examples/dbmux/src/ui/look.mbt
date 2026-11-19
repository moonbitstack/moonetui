// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The look: the colours of moonetui's examples, held as the library's own
// `Theme` so each role says what it is for. A tool carries its look with it, so
// nothing here is imported from the examples.

///|
pub let look : @design.Theme = @design.Theme::new(
  name="dbmux",
  primary=@style.Colour::rgb(0x7a, 0xa2, 0xf7),
  secondary=@style.Colour::rgb(0xbb, 0x9a, 0xf7),
  accent=@style.Colour::rgb(0x7d, 0xdf, 0xff),
  surface=@style.Colour::rgb(0x16, 0x1b, 0x27),
  panel=@style.Colour::rgb(0x1e, 0x27, 0x3b),
  text=@style.Colour::rgb(0xdc, 0xe3, 0xf1),
  muted=@style.Colour::rgb(0x8b, 0x96, 0xab),
  success=@style.Colour::rgb(0x9e, 0xce, 0x6a),
  warning=@style.Colour::rgb(0xe0, 0xaf, 0x68),
  error=@style.Colour::rgb(0xf7, 0x76, 0x8e),
  border=@style.Colour::rgb(0x2c, 0x35, 0x48),
)

///|
/// What is there but not meant to be read: a gutter, a NULL, a count.
pub let faint : @style.Colour = @style.Colour::rgb(0x5c, 0x67, 0x78)

///|
/// The ground of every other row of a table, one step off the terminal's own.
let stripe : @style.Colour = @style.Colour::rgb(0x12, 0x17, 0x22)

///|
pub let body : @style.Style = @style.Style::new(fg=look.text)

///|
pub let quiet : @style.Style = @style.Style::new(fg=look.muted)

///|
pub let dim : @style.Style = @style.Style::new(fg=faint)

///|
/// The cell or the character the keys act on.
pub let cursor : @style.Style = @style.Style::new(
  fg=look.surface,
  bg=look.primary,
  bold=true,
)

///|
/// A row that is chosen in a list that does not have the keys.
pub let picked : @style.Style = @style.Style::new(
  fg=look.text,
  bg=look.panel,
  bold=true,
)

///|
/// The grid's styles in one place, so a rebuilt table looks like the last one.
/// The cursor is bright only in the pane that has the keys.
pub fn grid_table(active~ : Bool) -> @widget.DataTable {
  @widget.DataTable::new(
    zebra=true,
    header_style=@style.Style::new(fg=look.muted, bold=true),
    cursor_style=if active { cursor } else { picked },
    hover_style=if active { cursor } else { picked },
    odd_style=body,
    even_style=@style.Style::new(fg=look.text, bg=stripe),
    label_style=@style.Style::new(fg=look.warning, bold=true),
    style=body,
  )
}

///|
/// The band along the top: the program, the connection and its engine, the
/// mark a dangerous connection wears, and where the reader is on the right.
pub fn band(state : @shell.State, width~ : Int32) -> @strip.Strip {
  let ground = @style.Style::new(fg=look.text, bg=look.surface)
  let segs : Array[@strip.Seg] = [
    @strip.Seg::new(
      " dbmux ",
      @style.Style::new(fg=look.primary, bg=look.surface, bold=true),
    ),
    @strip.Seg::new(
      " " + state.connection,
      @style.Style::new(fg=look.text, bg=look.surface, bold=true),
    ),
    @strip.Seg::new(
      " · " + state.engine.name() + " ",
      @style.Style::new(fg=look.muted, bg=look.surface),
    ),
  ]
  let badge = state.badge()
  if badge != "" {
    let colour = if state.production { look.error } else { look.warning }
    segs.push(@strip.Seg::new(" ", ground))
    segs.push(
      @strip.Seg::new(
        " " + badge + " ",
        @style.Style::new(fg=look.surface, bg=colour, bold=true),
      ),
    )
  }
  let tail = @strip.Strip::of(
    state.status() + " ",
    @style.Style::new(fg=look.muted, bg=look.surface),
  )
  let room = @cmp.maximum(0, width - @strip.str_cells(tail.text()))
  let lead = @strip.Strip::from_segs(segs).crop(0, room).pad_to(room, ground)
  @strip.Strip::join([lead, tail]).crop(0, width).pad_to(width, ground)
}

///|
/// The key bar at the foot: each key in its cap and its meaning beside it.
pub fn keys(pairs : Array[(String, String)], width~ : Int32) -> @strip.Strip {
  let ground = @style.Style::new(fg=look.muted, bg=look.surface)
  let cap = @style.Style::new(fg=look.surface, bg=look.muted)
  let segs : Array[@strip.Seg] = [@strip.Seg::new(" ", ground)]
  for pair in pairs {
    let (key, meaning) = pair
    segs.push(@strip.Seg::new(" " + key + " ", cap))
    segs.push(@strip.Seg::new(" " + meaning + "  ", ground))
  }
  @strip.Strip::from_segs(segs).crop(0, width).pad_to(width, ground)
}

///|
/// The head of a panel: its name, a hairline to the edge, and a count. The
/// panel with the keys says so in `tone`.
pub fn head(
  name : String,
  count~ : String = "",
  width~ : Int32,
  active~ : Bool = false,
  tone~ : @style.Colour = look.primary,
) -> @strip.Strip {
  let label = @strip.Strip::of(
    name.to_upper() + " ",
    @style.Style::new(fg=if active { tone } else { look.muted }, bold=true),
  )
  let tally = @strip.Strip::of(
    if count == "" {
      ""
    } else {
      " " + count
    },
    @style.Style::new(fg=if active { tone } else { faint }),
  )
  let room = width -
    @strip.str_cells(label.text()) -
    @strip.str_cells(tally.text())
  @strip.Strip::join([
    label,
    @strip.Strip::of("─".repeat(@cmp.maximum(0, room)), look.fg(Border)),
    tally,
  ])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
}

///|
priv struct Line {
  draw : (Int32) -> @strip.Strip
}

///|
impl @widget.Widget for Line with fn render_line(self, _row, size) {
  (self.draw)(size.width)
}

///|
impl @widget.Widget for Line with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
impl @widget.Widget for Line with fn handle(_self, _ctx, _msg) {
  false
}

///|
impl @widget.Widget for Line with fn focusable(_self) {
  false
}

///|
/// One row drawn by a function of its width, read again on every frame.
pub fn line(draw : (Int32) -> @strip.Strip) -> &@widget.Widget {
  Line::{ draw, }
}

///|
priv struct Divider {}

///|
impl @widget.Widget for Divider with fn render_line(_self, _row, size) {
  @strip.Strip::of("│", look.fg(Border)).pad_to(
    size.width,
    @style.Style::new(),
  )
}

///|
impl @widget.Widget for Divider with fn hint(_self, size) {
  @geom.Size::new(1, size.height)
}

///|
impl @widget.Widget for Divider with fn handle(_self, _ctx, _msg) {
  false
}

///|
impl @widget.Widget for Divider with fn focusable(_self) {
  false
}

///|
/// A hairline down the height, so two panels read as two.
pub fn divider() -> &@widget.Widget {
  Divider::{ }
}
