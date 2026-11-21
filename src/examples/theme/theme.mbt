// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The look every example wears, under the names the examples call it by. The
// colours, the styles and the four strips a screen is framed with are the
// library's house look; this module only says what each role is called here.

///|
/// The house look, as a theme.
pub let look : @design.Theme = @design.studio

///|
/// The examples' blue: the wordmark, a panel that has the keyboard, the bar
/// that marks the row under the cursor.
pub let accent : @style.Colour = look.colour(@design.Primary)

///|
/// The second emphasis, for the thing the reader is about to do.
pub let accent_alt : @style.Colour = look.colour(@design.Secondary)

///|
/// Cooler than the accent, for a value that is live: a rate, a clock, a bar
/// that is still filling.
pub let cool : @style.Colour = look.colour(@design.Accent)

///|
/// Body text: near-white, never pure white, which glares on a dark terminal.
pub let ink : @style.Colour = look.colour(@design.Text)

///|
/// Notes, keys, and anything the eye should reach last.
pub let muted : @style.Colour = look.colour(@design.Muted)

///|
/// What is there but not meant to be read: separators, folded text, a pane
/// that has no keyboard.
pub let faint : @style.Colour = look.faint

///|
/// The ground of a title band or a bar: one step up from the terminal's black,
/// so the band reads as a surface rather than as a row of text.
pub let surface : @style.Colour = look.colour(@design.Surface)

///|
/// A row of a table or a list under the cursor.
pub let picked : @style.Colour = look.colour(@design.Panel)

///|
/// A thing going well: the snake's body, a finished bar.
pub let good : @style.Colour = look.colour(@design.Success)

///|
/// A thing to notice: a warning, a paused clock.
pub let warn : @style.Colour = look.colour(@design.Warning)

///|
/// A thing gone wrong, or the apple.
pub let bad : @style.Colour = look.colour(@design.Error)

///|
/// The hairline between two panes, drawn in the terminal's own cells.
pub let edge : @style.Style = look.edge()

///|
/// A wordmark: bold in the accent.
pub let mark : @style.Style = look.mark()

///|
/// Body text in its own style, for a screen that builds a strip by hand.
pub let body : @style.Style = look.fg(@design.Text)

///|
/// An identifier: an accent that names a thing without shouting it.
pub let identifier : @style.Style = look.fg(@design.Primary)

///|
/// A title in the body colour.
pub let title : @style.Style = look.title()

///|
/// A panel that has the keyboard writes its name in the accent.
pub let live : @style.Style = look.live()

///|
/// A panel that does not, in the quieter note colour.
pub let quiet : @style.Style = look.quiet()

///|
/// A mark that is there but carries nothing yet: an unfilled dot, an empty
/// checkbox.
pub let faint_style : @style.Style = look.dim()

///|
/// The row under the cursor: a lifted ground, not a block of colour, so the
/// text in it stays as readable as the text around it.
pub let cursor : @style.Style = look.cursor()

///|
/// The bar in front of the row under the cursor.
pub let marker : @style.Style = look.marker()

///|
/// A key on the key bar: dark on the note colour, the way a keycap reads.
pub let cap : @style.Style = look.cap()

///|
/// The sheet every example shares, plus the three classes its screens hang on
/// their nodes: a framed box, a bar docked to the foot, and the header strip.
/// The renderer quantises a true colour to what the terminal can draw, so these
/// stay right on an 8-colour console.
pub fn sheet() -> @design.Stylesheet {
  let sheet = look.sheet()
  sheet.add(@design.Sel::new(), @design.Styles::new(text=body))
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
  sheet
}

///|
/// `text` repeated `count` times.
pub fn repeat(text : String, count : Int32) -> String {
  text.repeat(count)
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
/// on the right.
pub fn band(
  name : String,
  subject~ : String = "",
  note~ : String = "",
  width~ : Int32,
) -> @strip.Strip {
  look.band(name, subject~, note~, width~)
}

///|
/// The key bar at the foot: each key in its cap, its meaning beside it.
pub fn keys(pairs : Array[(String, String)], width~ : Int32) -> @strip.Strip {
  look.keys(pairs, width~)
}

///|
/// The head of a panel: its name, what it holds, and a hairline rule that runs
/// to the panel's edge.
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
/// A full-width rule, for a screen that has more than one band of content.
pub fn rule(width~ : Int32) -> @strip.Strip {
  look.rule(width~)
}

///|
/// One column of a row of panes: a hairline down the height.
pub fn divider(height~ : Int32) -> @strip.Strip {
  look.divider(height~)
}

///|
/// The strip at the top: a title on the left, a note on the right, in the
/// sheet's header role.
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
/// One row drawn by a function of its width: how a screen mounts the band or
/// the key bar as a node of its own.
pub fn line(draw : (Int32) -> @strip.Strip) -> &@widget.Widget {
  @widget.StripRow::new(draw)
}
