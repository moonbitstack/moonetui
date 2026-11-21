// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The palette and the strips a screen is framed with, under the names this
// window calls them by. The look itself is the library's house look: a tool
// carries no palette of its own, so a screenshot of it belongs with the rest.

///|
/// The house look, as a theme.
pub let look : @design.Theme = @design.studio

///|
/// The wordmark, the marker of the row under the cursor, the branch a change is
/// on.
pub let accent : @style.Colour = look.colour(@design.Primary)

///|
/// The second emphasis: a bookmark, a change's own name.
pub let accent_alt : @style.Colour = look.colour(@design.Secondary)

///|
/// A working copy: the thing a reader is in the middle of.
pub let cool : @style.Colour = look.colour(@design.Accent)

///|
/// Body text.
pub let ink : @style.Colour = look.colour(@design.Text)

///|
/// Notes and keys.
pub let muted : @style.Colour = look.colour(@design.Muted)

///|
/// What is there but not meant to be read: lanes, folded text, separators.
pub let faint : @style.Colour = look.faint

///|
/// The ground of the title band and the key bar.
pub let surface : @style.Colour = look.colour(@design.Surface)

///|
/// The row under the cursor.
pub let picked : @style.Colour = look.colour(@design.Panel)

///|
/// An added line, a bookmark that is fine.
pub let good : @style.Colour = look.colour(@design.Success)

///|
/// A warning, a change that is empty.
pub let warn : @style.Colour = look.colour(@design.Warning)

///|
/// A removed line, a conflict.
pub let bad : @style.Colour = look.colour(@design.Error)

///|
/// The hairline between two panes.
pub let edge : @style.Style = look.edge()

///|
/// Body text as a style, for a screen that builds a strip by hand.
pub let body : @style.Style = look.fg(@design.Text)

///|
/// A title in the body colour.
pub let title : @style.Style = look.title()

///|
/// A wordmark: bold in the accent.
pub let mark : @style.Style = look.mark()

///|
/// An identifier: a name without the weight.
pub let identifier : @style.Style = look.fg(@design.Primary)

///|
/// A panel that has the keyboard writes its name in the accent.
pub let live : @style.Style = look.live()

///|
/// A panel that does not, in the quieter note colour.
pub let quiet : @style.Style = look.quiet()

///|
/// A mark that is there but carries nothing yet.
pub let faint_style : @style.Style = look.dim()

///|
/// The row under the cursor: a lifted ground, not a block of colour.
pub let cursor : @style.Style = look.cursor()

///|
/// The bar in front of the row under the cursor.
pub let marker : @style.Style = look.marker()

///|
/// A key on the key bar: dark on the note colour, the way a keycap reads.
pub let cap : @style.Style = look.cap()

///|
/// The sheet the window wears.
pub fn sheet() -> @design.Stylesheet {
  let sheet = look.sheet()
  sheet.add(@design.Sel::new(), @design.Styles::new(text=body))
  sheet
}

///|
/// `text` repeated `count` times.
pub fn repeat(text : String, count : Int32) -> String {
  text.repeat(count)
}

///|
/// `text` padded with spaces to `width` columns, and left alone if it is wider.
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
/// The head of a panel: its name, what it holds, and a hairline that runs to
/// the panel's edge.
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
/// A full-width rule.
pub fn rule(width~ : Int32) -> @strip.Strip {
  look.rule(width~)
}

///|
/// The column between two panes: a hairline and a space.
pub fn gap() -> @strip.Strip {
  @strip.Strip::join([
    @strip.Strip::of("│", look.edge()),
    @strip.Strip::blank(1, @style.Style::new()),
  ])
}
