// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The three rows a screen is framed with: the band along the top, the key bar at
// the foot and the head of a panel. They are built from a theme rather than
// from a fixed palette, so a programme that changes its look changes these with
// it and nothing is drawn twice.

///|
/// The band along the top: the programme's name, what it is showing, and a note
/// on the right, on a ground one step above the terminal's own.
///
/// The band is drawn as a background, so a screen with a band and a key bar at
/// the foot reads as a framed panel rather than as loose words.
pub fn Theme::band(
  self : Theme,
  name : String,
  subject~ : String = "",
  note~ : String = "",
  width~ : Int32,
) -> @strip.Strip {
  let ground = @style.Style::new(fg=self.text, bg=self.surface)
  let head = @style.Style::new(fg=self.primary, bg=self.surface, bold=true)
  let body = @style.Style::new(fg=self.muted, bg=self.surface)
  let tail = @style.Style::new(fg=self.text, bg=self.surface)
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
/// The key bar at the foot: each key in its cap, what it does beside it, and the
/// whole row on the ground the band is on.
pub fn Theme::keys(
  self : Theme,
  pairs : Array[(String, String)],
  width~ : Int32,
) -> @strip.Strip {
  let ground = @style.Style::new(fg=self.muted, bg=self.surface)
  let cap = self.cap()
  let segs : Array[@strip.Seg] = [@strip.Seg::new(" ", ground)]
  for pair in pairs {
    let (key, meaning) = pair
    segs.push(@strip.Seg::new(" " + key + " ", cap))
    segs.push(@strip.Seg::new(" " + meaning + "  ", ground))
  }
  @strip.Strip::from_segs(segs).crop(0, width).pad_to(width, ground)
}

///|
/// The head of a panel: its name, what it holds, and a hairline that runs to the
/// panel's edge. A panel that has the keyboard says so in the primary colour, or
/// in `tone` when the caller has something more urgent to say — a confirmation,
/// a failure.
pub fn Theme::panel_head(
  self : Theme,
  name : String,
  count~ : String = "",
  width~ : Int32,
  active~ : Bool = false,
  tone~ : @style.Colour? = None,
) -> @strip.Strip {
  let loud = match tone {
    Some(colour) => @style.Style::new(fg=colour, bold=true)
    None => self.live()
  }
  let label = @strip.Strip::of(
    " " + name.to_upper(),
    if active {
      loud
    } else {
      self.quiet()
    },
  )
  let tally = @strip.Strip::of(
    " " + count + " ",
    if active {
      loud
    } else {
      self.dim()
    },
  )
  let room = @strip.str_cells(label.text()) + @strip.str_cells(tally.text())
  let rule = "─".repeat(if width - room > 0 { width - room } else { 0 })
  @strip.Strip::join([label, @strip.Strip::of(rule, self.edge()), tally])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
}

///|
/// A rule across the width, for a screen with more than one band of content.
pub fn Theme::rule(self : Theme, width~ : Int32) -> @strip.Strip {
  @strip.Strip::of("─".repeat(width), self.edge())
}

///|
/// One column of a row of panes: a hairline down the height, so two panes read
/// as two panes and not as one wide table.
pub fn Theme::divider(self : Theme, height~ : Int32) -> @strip.Strip {
  @strip.Strip::of("│".repeat(height), self.edge())
}
