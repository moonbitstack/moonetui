// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a colour in a theme is for. A widget asks for a role and the theme
/// answers with the colour that role holds, so a whole look changes by
/// swapping one value.
pub(all) enum Role {
  Primary
  Secondary
  Accent
  Surface
  Panel
  Text
  Muted
  Success
  Warning
  Error
  Border
} derive(Eq, Debug)

///|
pub fn roles() -> Array[Role] {
  [
    Primary,
    Secondary,
    Accent,
    Surface,
    Panel,
    Text,
    Muted,
    Success,
    Warning,
    Error,
    Border,
  ]
}

///|
/// The class a rule carries for this role: the name a stylesheet is written
/// against, so a theme can be applied without naming its colours.
pub fn Role::name(self : Role) -> String {
  match self {
    Primary => "primary"
    Secondary => "secondary"
    Accent => "accent"
    Surface => "surface"
    Panel => "panel"
    Text => "text"
    Muted => "muted"
    Success => "success"
    Warning => "warning"
    Error => "error"
    Border => "border"
  }
}

///|
/// What the role is for, as one line.
pub fn Role::note(self : Role) -> String {
  match self {
    Primary => "the colour that draws the eye"
    Secondary => "the colour beside it"
    Accent => "the highlight on what is chosen"
    Surface => "the ground everything sits on"
    Panel => "the ground of a raised box"
    Text => "the colour of words"
    Muted => "the colour of words that matter less"
    Success => "the colour of a thing that worked"
    Warning => "the colour of a thing to mind"
    Error => "the colour of a thing that failed"
    Border => "the colour of frames and rules"
  }
}

///|
/// A set of semantic colours as one value: everything a look is made of,
/// switched as a whole.
pub(all) struct Theme {
  name : String
  primary : @style.Colour
  secondary : @style.Colour
  accent : @style.Colour
  surface : @style.Colour
  panel : @style.Colour
  text : @style.Colour
  muted : @style.Colour
  success : @style.Colour
  warning : @style.Colour
  error : @style.Colour
  border : @style.Colour
} derive(Eq, Debug)

///|
/// A theme of the default look, with any role left out taken from `dark`.
pub fn Theme::new(
  name~ : String = "custom",
  primary~ : @style.Colour = @style.cyan,
  secondary~ : @style.Colour = @style.blue,
  accent~ : @style.Colour = @style.magenta,
  surface~ : @style.Colour = @style.Colour::rgb(10, 14, 22),
  panel~ : @style.Colour = @style.Colour::rgb(24, 30, 42),
  text~ : @style.Colour = @style.Colour::rgb(201, 212, 232),
  muted~ : @style.Colour = @style.Colour::rgb(110, 122, 144),
  success~ : @style.Colour = @style.green,
  warning~ : @style.Colour = @style.yellow,
  error~ : @style.Colour = @style.red,
  border~ : @style.Colour = @style.Colour::rgb(70, 84, 110),
) -> Theme {
  {
    name,
    primary,
    secondary,
    accent,
    surface,
    panel,
    text,
    muted,
    success,
    warning,
    error,
    border,
  }
}

///|
/// The dark look: light words on a near-black ground, the site's own colours.
pub let dark : Theme = Theme::new(name="dark")

///|
/// The light look: the same roles on a paper-white ground.
pub let light : Theme = Theme::new(
  name="light",
  primary=@style.Colour::rgb(0, 102, 153),
  secondary=@style.Colour::rgb(0, 82, 204),
  accent=@style.Colour::rgb(153, 0, 153),
  surface=@style.Colour::rgb(250, 250, 252),
  panel=@style.Colour::rgb(232, 235, 242),
  text=@style.Colour::rgb(28, 32, 40),
  muted=@style.Colour::rgb(110, 118, 134),
  success=@style.Colour::rgb(0, 112, 60),
  warning=@style.Colour::rgb(166, 102, 0),
  error=@style.Colour::rgb(178, 24, 24),
  border=@style.Colour::rgb(176, 184, 200),
)

///|
/// The Nord look: the Polar Night ground, Snow Storm words and the Frost and
/// Aurora colours.
pub let nord : Theme = Theme::new(
  name="nord",
  primary=@style.Colour::rgb(136, 192, 208),
  secondary=@style.Colour::rgb(129, 161, 193),
  accent=@style.Colour::rgb(180, 142, 173),
  surface=@style.Colour::rgb(46, 52, 64),
  panel=@style.Colour::rgb(59, 66, 82),
  text=@style.Colour::rgb(236, 239, 244),
  muted=@style.Colour::rgb(76, 86, 106),
  success=@style.Colour::rgb(163, 190, 140),
  warning=@style.Colour::rgb(235, 203, 139),
  error=@style.Colour::rgb(191, 97, 106),
  border=@style.Colour::rgb(67, 76, 94),
)

///|
/// Every theme this library carries.
pub fn themes() -> Array[Theme] {
  [dark, light, nord]
}

///|
/// The theme of that name, if there is one.
pub fn Theme::of(name : String) -> Theme? {
  themes().iter().find_first(theme => theme.name == name)
}

///|
/// The colour this role holds.
pub fn Theme::colour(self : Theme, role : Role) -> @style.Colour {
  match role {
    Primary => self.primary
    Secondary => self.secondary
    Accent => self.accent
    Surface => self.surface
    Panel => self.panel
    Text => self.text
    Muted => self.muted
    Success => self.success
    Warning => self.warning
    Error => self.error
    Border => self.border
  }
}

///|
/// This theme with one role's colour changed; every other role is kept.
pub fn Theme::set(self : Theme, role : Role, colour : @style.Colour) -> Theme {
  match role {
    Primary => { ..self, primary: colour, }
    Secondary => { ..self, secondary: colour, }
    Accent => { ..self, accent: colour, }
    Surface => { ..self, surface: colour, }
    Panel => { ..self, panel: colour, }
    Text => { ..self, text: colour, }
    Muted => { ..self, muted: colour, }
    Success => { ..self, success: colour, }
    Warning => { ..self, warning: colour, }
    Error => { ..self, error: colour, }
    Border => { ..self, border: colour, }
  }
}

///|
/// Words in this role's colour.
pub fn Theme::fg(self : Theme, role : Role) -> @style.Style {
  @style.Style::new(fg=self.colour(role))
}

///|
/// A ground in this role's colour.
pub fn Theme::fill(self : Theme, role : Role) -> @style.Style {
  @style.Style::new(bg=self.colour(role))
}

///|
/// What the tree inherits: the text colour on the surface.
pub fn Theme::base(self : Theme) -> @style.Style {
  @style.Style::new(fg=self.text, bg=self.surface)
}

///|
/// The theme as rules: one class per role for words in its colour, and one
/// class per role for a ground in it, so `set_sheet` with this switches
/// everything styled by role at once.
pub fn Theme::sheet(self : Theme) -> Stylesheet {
  let sheet = Stylesheet::new()
  for role in roles() {
    let colour = self.colour(role)
    sheet.add(
      Sel::new(classes=[role.name()]),
      Styles::new(text=@style.Style::new(fg=colour)),
    )
    sheet.add(
      Sel::new(classes=[role.name() + "-fill"]),
      Styles::new(text=@style.Style::new(bg=colour)),
    )
  }
  sheet
}

///|
pub extend Role with Debug::{to_repr}

///|
pub extend Role with Eq::{not_equal, equal}

///|
pub extend Theme with Debug::{to_repr}

///|
pub extend Theme with Eq::{not_equal, equal}
