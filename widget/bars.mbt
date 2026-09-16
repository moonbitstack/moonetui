// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The bar across the top: a title, and an optional note on the right.
pub struct Header {
  mut title : String
  mut note : String
  style : @style.Style
}

///|
/// A header with this title.
pub fn Header::new(
  title : String,
  note? : String = "",
  style? : @style.Style = @style.Style::new(reverse=true),
) -> Header {
  { title, note, style, }
}

///|
/// Change the title.
pub fn Header::set(self : Header, title : String) -> Unit {
  self.title = title
}

///|
/// Change the note on the right.
pub fn Header::set_note(self : Header, note : String) -> Unit {
  self.note = note
}

///|
pub impl Widget for Header with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let note_cells = @strip.str_cells(self.note)
  if note_cells == 0 || note_cells + 2 >= size.width {
    return align_line(self.title, size.width, Center, self.style)
  }
  let left = align_line(self.title, size.width - note_cells, Center, self.style)
  @strip.Strip::join([left, @strip.Strip::of(self.note, self.style)])
}

///|
pub impl Widget for Header with fn hint(self, size) {
  ignore(self)
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Header with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Header with fn focusable(_self) {
  false
}

///|
/// The bar across the bottom: the keys that do something here.
///
/// Each binding is a key and what it does. They are drawn left to right and cut
/// off where the width runs out, which keeps the most important ones — the ones
/// listed first — visible on a narrow terminal.
pub struct Footer {
  mut bindings : Array[(String, String)]
  style : @style.Style
  key_style : @style.Style
}

///|
/// A footer showing these bindings.
pub fn Footer::new(
  bindings : Array[(String, String)],
  style? : @style.Style = @style.Style::new(dim=true),
  key_style? : @style.Style = @style.Style::new(bold=true),
) -> Footer {
  { bindings, style, key_style, }
}

///|
/// Replace the bindings.
pub fn Footer::set(self : Footer, bindings : Array[(String, String)]) -> Unit {
  self.bindings = bindings
}

///|
pub impl Widget for Footer with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let parts : Array[@strip.Strip] = []
  let mut used = 0
  for binding in self.bindings {
    let (key, what) = binding
    let entry = " " + key + " " + what + " "
    let cells = @strip.str_cells(entry)
    if used + cells > size.width {
      break
    }
    parts.push(@strip.Strip::of(" " + key + " ", self.key_style))
    parts.push(@strip.Strip::of(what + " ", self.style))
    used = used + cells
  }
  @strip.Strip::join(parts).pad_to(size.width, self.style)
}

///|
pub impl Widget for Footer with fn hint(self, size) {
  ignore(self)
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Footer with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Footer with fn focusable(_self) {
  false
}
