// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum RuleDir {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
pub(all) enum RuleKind {
  Ascii
  Blank
  Dashed
  Double
  Heavy
  Hidden
  None
  Solid
  Thick
} derive(Eq, Debug)

///|
pub struct Rule {
  dir : RuleDir
  mut kind : RuleKind
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Rule::horizontal(
  kind~ : RuleKind = Solid,
  style~ : @style.Style = @style.Style::new(),
) -> Rule {
  { dir: Horizontal, kind, style, }
}

///|
pub fn Rule::vertical(
  kind~ : RuleKind = Solid,
  style~ : @style.Style = @style.Style::new(),
) -> Rule {
  { dir: Vertical, kind, style, }
}

///|
pub fn Rule::set_kind(self : Rule, kind : RuleKind) -> Unit {
  self.kind = kind
}

///|
pub impl Widget for Rule with fn render_line(self, row, size) {
  let glyph = rule_char(self.dir, self.kind)
  if self.dir == Vertical {
    if size.width <= 0 {
      return @strip.Strip::empty()
    }
    return @strip.Strip::join([
      @strip.Strip::of(glyph, self.style),
      @strip.Strip::blank(size.width - 1, self.style),
    ])
  }
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let out = StringBuilder()
  for _ in 0..<size.width {
    out.write_string(glyph)
  }
  @strip.Strip::of(out.to_string(), self.style)
}

///|
pub impl Widget for Rule with fn hint(self, size) {
  if self.dir == Horizontal {
    @geom.Size::new(size.width, 1)
  } else {
    @geom.Size::new(1, size.height)
  }
}

///|
pub impl Widget for Rule with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Rule with fn focusable(_self) {
  false
}

///|
fn rule_char(dir : RuleDir, kind : RuleKind) -> String {
  match (dir, kind) {
    (Horizontal, Ascii) => "-"
    (Horizontal, Blank) => " "
    (Horizontal, Dashed) => "╍"
    (Horizontal, Double) => "═"
    (Horizontal, Heavy) => "━"
    (Horizontal, Hidden) => " "
    (Horizontal, None) => " "
    (Horizontal, Solid) => "─"
    (Horizontal, Thick) => "█"
    (Vertical, Ascii) => "|"
    (Vertical, Blank) => " "
    (Vertical, Dashed) => "╏"
    (Vertical, Double) => "║"
    (Vertical, Heavy) => "┃"
    (Vertical, Hidden) => " "
    (Vertical, None) => " "
    (Vertical, Solid) => "│"
    (Vertical, Thick) => "█"
  }
}

///|
pub extend RuleDir with Debug::{to_repr}

///|
pub extend RuleDir with Eq::{not_equal, equal}

///|
pub extend RuleKind with Debug::{to_repr}

///|
pub extend RuleKind with Eq::{not_equal, equal}

///|
pub extend Rule with Debug::{to_repr}

///|
pub extend Rule with Eq::{not_equal, equal}

///|
pub extend Rule with Widget::{focusable, handle, hint, render_line}
