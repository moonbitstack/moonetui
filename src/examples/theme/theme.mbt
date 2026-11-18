// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The look every example wears: one palette, one sheet, and the four strips a
// screen is framed with — a title band, a rule under it, a panel head and the
// key bar at the foot. The palette is the one on the project's pages, so a
// screenshot and the page beside it are the same picture.

///|
/// The examples' blue: the wordmark, a panel that has the keyboard, the bar
/// that marks the row under the cursor.
pub let accent : @style.Colour = @style.Rgb(0x7a, 0xa2, 0xf7)

///|
/// The second emphasis, for the thing the reader is about to do.
pub let accent_alt : @style.Colour = @style.Rgb(0xbb, 0x9a, 0xf7)

///|
/// Cooler than the accent, for a value that is live: a rate, a clock, a bar
/// that is still filling.
pub let cool : @style.Colour = @style.Rgb(0x7d, 0xdf, 0xff)

///|
/// Body text: near-white, never pure white, which glares on a dark terminal.
pub let ink : @style.Colour = @style.Rgb(0xdc, 0xe3, 0xf1)

///|
/// Notes, keys, and anything the eye should reach last.
pub let muted : @style.Colour = @style.Rgb(0x8b, 0x96, 0xab)

///|
/// What is there but not meant to be read: separators, folded text, a pane
/// that has no keyboard.
pub let faint : @style.Colour = @style.Rgb(0x5c, 0x67, 0x78)

///|
/// The ground of a title band or a bar: one step up from the terminal's black,
/// so the band reads as a surface rather than as a row of text.
pub let surface : @style.Colour = @style.Rgb(0x16, 0x1b, 0x27)

///|
/// A row of a table or a list under the cursor.
pub let picked : @style.Colour = @style.Rgb(0x1e, 0x27, 0x3b)

///|
/// A thing going well: the snake's body, a finished bar.
pub let good : @style.Colour = @style.Rgb(0x9e, 0xce, 0x6a)

///|
/// A thing to notice: a warning, a paused clock.
pub let warn : @style.Colour = @style.Rgb(0xe0, 0xaf, 0x68)

///|
/// A thing gone wrong, or the apple.
pub let bad : @style.Colour = @style.Rgb(0xf7, 0x76, 0x8e)

///|
/// The hairline between two panes, drawn in the terminal's own cells.
pub let edge : @style.Style = @style.Style::new(fg=@style.Rgb(0x2c, 0x35, 0x48))

///|
/// A wordmark: bold in the accent.
pub let mark : @style.Style = @style.Style::new(fg=accent, bold=true)

///|
/// Body text in its own style, for a screen that builds a strip by hand.
pub let body : @style.Style = @style.Style::new(fg=ink)

///|
/// An identifier: an accent that names a thing without shouting it.
pub let identifier : @style.Style = @style.Style::new(fg=accent)

///|
/// A title in the body colour.
pub let title : @style.Style = @style.Style::new(fg=ink, bold=true)

///|
/// A panel that has the keyboard writes its name in the accent.
pub let live : @style.Style = @style.Style::new(fg=accent, bold=true)

///|
/// A panel that does not, in the quieter note colour.
pub let quiet : @style.Style = @style.Style::new(fg=muted)

///|
/// A mark that is there but carries nothing yet: an unfilled dot, an empty
/// checkbox.
pub let faint_style : @style.Style = @style.Style::new(fg=faint)

///|
/// The row under the cursor: a lifted ground, not a block of colour, so the
/// text in it stays as readable as the text around it.
pub let cursor : @style.Style = @style.Style::new(fg=ink, bg=picked, bold=true)

///|
/// The bar in front of the row under the cursor.
pub let marker : @style.Style = @style.Style::new(
  fg=accent,
  bg=picked,
  bold=true,
)

///|
/// A key on the key bar: dark on the note colour, the way a keycap reads.
pub let cap : @style.Style = @style.Style::new(fg=surface, bg=muted)

///|
/// The sheet every example shares. The renderer quantises a true colour to
/// what the terminal can draw, so these stay right on an 8-colour console.
pub fn sheet() -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=ink)),
  )
  sheet.add(@design.Sel::new(name="Header"), @design.Styles::new(text=mark))
  sheet.add(
    @design.Sel::new(classes=["framed"]),
    @design.Styles::new(
      border=@design.Round,
      padding=@geom.Spacing::horizontal(1),
    ),
  )
  sheet.add(
    @design.Sel::new(classes=["bar"]),
    @design.Styles::new(dock=@design.Bottom),
  )
  sheet.add(
    @design.Sel::new(classes=["muted"]),
    @design.Styles::new(text=@style.Style::new(fg=muted)),
  )
  sheet.add(
    @design.Sel::new(classes=["accent"]),
    @design.Styles::new(text=@style.Style::new(bold=true, fg=accent_alt)),
  )
  sheet
}

///|
/// `text` repeated `count` times.
pub fn repeat(text : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(text)
  }
  out.to_string()
}

///|
/// `text` padded with spaces to `width` columns, and left alone if it is wider:
/// a caller that overflows a column crops it, so nothing is measured twice.
pub fn fit(text : String, width : Int32) -> String {
  let cells = @strip.str_cells(text)
  if cells >= width {
    return text
  }
  text + repeat(" ", width - cells)
}

///|
/// The band along the top: the program's name, what it is showing, and a note
/// on the right, on a surface one step above the terminal's own.
///
/// The band is drawn as a background, so a screen with a band and a key bar at
/// the foot reads as a framed panel rather than as loose text.
pub fn band(
  name : String,
  subject~ : String = "",
  note~ : String = "",
  width~ : Int32,
) -> @strip.Strip {
  let ground : @style.Style = @style.Style::new(fg=ink, bg=surface)
  let head : @style.Style = @style.Style::new(fg=accent, bg=surface, bold=true)
  let body : @style.Style = @style.Style::new(fg=muted, bg=surface)
  let tail : @style.Style = @style.Style::new(fg=ink, bg=surface)
  let left : Array[@strip.Seg] = []
  left.push(@strip.Seg::new(" " + name + " ", head))
  if subject != "" {
    left.push(@strip.Seg::new(" " + subject, body))
  }
  let lead = @strip.Strip::from_segs(left)
  let room = if width - @strip.str_cells(note) - 2 > 0 {
    width - @strip.str_cells(note) - 2
  } else {
    0
  }
  let first = lead.pad_to(room, ground)
  let right = @strip.Strip::of(note + " ", tail)
  @strip.Strip::join([first, right]).crop(0, width).pad_to(width, ground)
}

///|
/// The key bar at the foot: each key in its cap, its meaning beside it, and the
/// whole row on the surface the band is on.
pub fn keys(pairs : Array[(String, String)], width~ : Int32) -> @strip.Strip {
  let ground : @style.Style = @style.Style::new(fg=muted, bg=surface)
  let segs : Array[@strip.Seg] = []
  segs.push(@strip.Seg::new(" ", ground))
  for pair in pairs {
    let (key, meaning) = pair
    segs.push(@strip.Seg::new(" " + key + " ", cap))
    segs.push(@strip.Seg::new(" " + meaning + "  ", ground))
  }
  @strip.Strip::from_segs(segs).crop(0, width).pad_to(width, ground)
}

///|
/// The head of a panel: its name, what it holds, and a hairline rule that runs
/// to the panel's edge. A panel with the keyboard says so in the accent.
pub fn head(
  name : String,
  count~ : String = "",
  width~ : Int32,
  active~ : Bool = false,
) -> @strip.Strip {
  let style = if active { live } else { quiet }
  let label = @strip.Strip::of(" " + name.to_upper(), style)
  let tally = @strip.Strip::of(
    " " + count + " ",
    if active {
      live
    } else {
      faint_style
    },
  )
  let room = @strip.str_cells(label.text()) + @strip.str_cells(tally.text())
  let rule = repeat("─", if width - room > 0 { width - room } else { 0 })
  @strip.Strip::join([label, @strip.Strip::of(rule, edge), tally])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
}

///|
/// A full-width rule, for a screen that has more than one band of content.
pub fn rule(width~ : Int32) -> @strip.Strip {
  @strip.Strip::of(repeat("─", width), edge)
}

///|
/// One column of a row of panes: a hairline down the height, so two panes read
/// as two panes and not as one wide table.
pub fn divider(height~ : Int32) -> @strip.Strip {
  @strip.Strip::of(repeat("│", height), edge)
}

///|
/// The strip at the top: a title on the left, a note on the right, in the
/// sheet's header role. A screen that wants the example palette's band draws
/// `band` itself; this is the library widget in the sheet's colours.
pub fn header(title : String, note~ : String = "") -> @widget.Header {
  @widget.Header::new(title, note~)
}

///|
/// The strip at the bottom: the keys a reader can press, in the sheet's bar
/// role.
pub fn footer(keys : Array[(String, String)]) -> @widget.Footer {
  @widget.Footer::new(keys)
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
/// One row drawn by a function of its width: how a screen mounts the band or
/// the key bar as a node of its own.
pub fn line(draw : (Int32) -> @strip.Strip) -> &@widget.Widget {
  Line::{ draw, }
}
