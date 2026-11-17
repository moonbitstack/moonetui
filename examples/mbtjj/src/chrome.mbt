// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The palette and the four strips a screen is framed with. A tool carries its
// own look: the same colours as the library's examples, so a screenshot belongs
// with the rest, but nothing here is imported from them.

///|
/// The wordmark, the marker of the row under the cursor, the branch a change is
/// on.
pub let accent : @style.Colour = @style.Rgb(0x7a, 0xa2, 0xf7)

///|
/// The second emphasis: a bookmark, a change's own name.
pub let accent_alt : @style.Colour = @style.Rgb(0xbb, 0x9a, 0xf7)

///|
/// A working copy: the thing a reader is in the middle of.
pub let cool : @style.Colour = @style.Rgb(0x7d, 0xdf, 0xff)

///|
/// Body text.
pub let ink : @style.Colour = @style.Rgb(0xdc, 0xe3, 0xf1)

///|
/// Notes and keys.
pub let muted : @style.Colour = @style.Rgb(0x8b, 0x96, 0xab)

///|
/// What is there but not meant to be read: lanes, folded text, separators.
pub let faint : @style.Colour = @style.Rgb(0x5c, 0x67, 0x78)

///|
/// The ground of the title band and the key bar.
pub let surface : @style.Colour = @style.Rgb(0x16, 0x1b, 0x27)

///|
/// The row under the cursor.
pub let picked : @style.Colour = @style.Rgb(0x1e, 0x27, 0x3b)

///|
/// An added line, a bookmark that is fine.
pub let good : @style.Colour = @style.Rgb(0x9e, 0xce, 0x6a)

///|
/// A warning, a change that is empty.
pub let warn : @style.Colour = @style.Rgb(0xe0, 0xaf, 0x68)

///|
/// A removed line, a conflict.
pub let bad : @style.Colour = @style.Rgb(0xf7, 0x76, 0x8e)

///|
/// The hairline between two panes.
pub let edge : @style.Style = @style.Style::new(fg=@style.Rgb(0x2c, 0x35, 0x48))

///|
/// Body text as a style, for a screen that builds a strip by hand.
pub let body : @style.Style = @style.Style::new(fg=ink)

///|
/// A title in the body colour.
pub let title : @style.Style = @style.Style::new(fg=ink, bold=true)

///|
/// A wordmark: bold in the accent.
pub let mark : @style.Style = @style.Style::new(fg=accent, bold=true)

///|
/// An identifier: a name without the weight.
pub let identifier : @style.Style = @style.Style::new(fg=accent)

///|
/// A panel that has the keyboard writes its name in the accent.
pub let live : @style.Style = @style.Style::new(fg=accent, bold=true)

///|
/// A panel that does not, in the quieter note colour.
pub let quiet : @style.Style = @style.Style::new(fg=muted)

///|
/// A mark that is there but carries nothing yet.
pub let faint_style : @style.Style = @style.Style::new(fg=faint)

///|
/// The row under the cursor: a lifted ground, not a block of colour.
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
/// The sheet the window wears.
pub fn sheet() -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=ink)),
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
/// on the right, on a surface one step above the terminal's own.
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
/// The key bar at the foot: each key in its cap, its meaning beside it.
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
/// The head of a panel: its name, what it holds, and a hairline that runs to
/// the panel's edge.
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
/// A full-width rule.
pub fn rule(width~ : Int32) -> @strip.Strip {
  @strip.Strip::of(repeat("─", width), edge)
}

///|
/// The column between two panes: a hairline and a space.
pub fn gap() -> @strip.Strip {
  @strip.Strip::join([
    @strip.Strip::of("│", edge),
    @strip.Strip::blank(1, @style.Style::new()),
  ])
}
