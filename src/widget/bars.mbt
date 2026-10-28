// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|

///|
/// The title bar: the title in the centre, a note at the right edge, and a
/// clock beside it when one is given.
pub struct Header {
  mut title : String
  mut note : String
  mut clock : Clock?
  style : @style.Style
}

///|
pub fn Header::new(
  title : String,
  note~ : String = "",
  clock~ : Clock? = None,
  style~ : @style.Style = @style.Style::new(reverse=true),
) -> Header {
  { title, note, clock, style, }
}

///|
pub fn Header::set(self : Header, title : String) -> Unit {
  self.title = title
}

///|
pub fn Header::set_note(self : Header, note : String) -> Unit {
  self.note = note
}

///|
/// Give the bar a clock to keep, or take it away with `None`.
pub fn Header::set_clock(self : Header, clock : Clock?) -> Unit {
  self.clock = clock
}

///|
/// What the clock reads, if the bar has one.
pub fn Header::time(self : Header) -> String? {
  match self.clock {
    Some(clock) => Some(clock.text())
    None => None
  }
}

///|
pub impl Widget for Header with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let right : Array[@strip.Strip] = []
  let mut used = 0
  match self.clock {
    Some(clock) => {
      let text = clock.text()
      used = used + @strip.str_cells(text) + 1
      right.push(@strip.Strip::of(text + " ", self.style))
    }
    None => ()
  }
  let note_cells = @strip.str_cells(self.note)
  if note_cells > 0 {
    used = used + note_cells
    right.push(@strip.Strip::of(self.note, self.style))
  }
  if used == 0 || used + 2 >= size.width {
    return align_line(self.title, size.width, Centre, self.style)
  }
  let left = align_line(
    self.title,
    at_least_zero(size.width - used),
    Centre,
    self.style,
  )
  @strip.Strip::join([left, @strip.Strip::join(right)])
}

///|
pub impl Widget for Header with fn hint(self, size) {
  ignore(self)
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Header with fn handle(self, ctx, msg) {
  match msg {
    Tick(ms) =>
      match self.clock {
        Some(clock) => {
          if clock.advance(ms) {
            ctx.repaint()
          }
          true
        }
        None => false
      }
    _ => false
  }
}

///|
pub impl Widget for Header with fn focusable(_self) {
  false
}

///|
pub struct Footer {
  mut bindings : Array[(String, String)]
  style : @style.Style
  key_style : @style.Style
}

///|
pub fn Footer::new(
  bindings : Array[(String, String)],
  style~ : @style.Style = @style.Style::new(dim=true),
  key_style~ : @style.Style = @style.Style::new(bold=true),
) -> Footer {
  { bindings, style, key_style, }
}

///|
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

///|
pub extend Footer with Widget::{focusable, handle, hint, render_line}

///|
pub extend Header with Widget::{focusable, handle, hint, render_line}
