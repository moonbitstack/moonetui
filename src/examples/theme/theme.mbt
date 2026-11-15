// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The examples' blue, the one on the badge and the site: headers, titles and
/// the frame around a playfield.
pub let accent : @style.Colour = @style.Rgb(0x7a, 0xa2, 0xf7)

///|
/// The second emphasis, for the thing the reader is about to do.
pub let accent_alt : @style.Colour = @style.Rgb(0xbb, 0x9a, 0xf7)

///|
/// Body text: near-white, never pure white, which glares on a dark terminal.
pub let ink : @style.Colour = @style.Rgb(0xc0, 0xca, 0xf5)

///|
/// Notes, keys, and anything the eye should reach last.
pub let muted : @style.Colour = @style.Rgb(0x56, 0x5f, 0x89)

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
/// The sheet every example shares. The renderer quantises a true colour to
/// what the terminal can draw, so these stay right on an 8-colour console.
pub fn sheet() -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=ink)),
  )
  sheet.add(
    @design.Sel::new(name="Header"),
    @design.Styles::new(text=@style.Style::new(bold=true, fg=accent)),
  )
  sheet.add(
    @design.Sel::new(classes=["framed"]),
    @design.Styles::new(
      border=@design.Round,
      padding=@geom.Spacing::horizontal(1),
    ),
  )
  sheet.add(
    @design.Sel::new(focus=true),
    @design.Styles::new(border=@design.Heavy),
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
