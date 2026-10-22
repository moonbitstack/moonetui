// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A starting point the way Textual's themes are: a base text style and a
/// stylesheet of sensible rules, both free to be added to or overridden.
pub(all) struct Preset {
  base : @style.Style
  sheet : Stylesheet
} derive(Eq, Debug)

///|
pub extend Preset with Debug::{to_repr}

///|
pub extend Preset with Eq::{not_equal, equal}

///|
fn base_sheet(base : @style.Style) -> Stylesheet {
  let sheet = Stylesheet::new()
  sheet.add(Sel::new(), Styles::new(text=Some(base)))
  sheet.add(
    Sel::new(name="Header"),
    Styles::new(text=Some(@style.Style::new(bold=true, fg=@style.cyan))),
  )
  sheet.add(
    Sel::new(classes=["framed"]),
    Styles::new(border=Some(Round), padding=Some(@geom.Spacing::horizontal(1))),
  )
  sheet.add(Sel::new(focus=true), Styles::new(border=Some(Heavy)))
  sheet.add(
    Sel::new(hover=true),
    Styles::new(text=Some(@style.Style::new(fg=@style.yellow))),
  )
  sheet
}

///|
/// Light letters on whatever the terminal draws behind them.
pub fn Preset::dark() -> Preset {
  let base = @style.Style::new(fg=@style.bright_white)
  { base, sheet: base_sheet(base), }
}

///|
/// Dark letters on a lit background, with scroll bars standing out from it.
pub fn Preset::light() -> Preset {
  let base = @style.Style::new(fg=@style.black, bg=@style.white)
  let sheet = base_sheet(base)
  sheet.add(
    Sel::new(),
    Styles::new(
      scrollbar=Some(@style.Style::new(fg=@style.white, bg=@style.black)),
    ),
  )
  { base, sheet, }
}
