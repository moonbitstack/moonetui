// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a place in a mask takes: a digit, a letter, either, or any character
/// at all. Every other character in the mask is a literal, shown as it is
/// written and stepped over.
pub(all) enum Slot {
  Digit
  Letter
  Either
  Any
} derive(Eq, Debug)

///|
pub fn Slot::of(glyph : String) -> Slot? {
  if glyph.length() == 0 {
    None
  } else if glyph == "#" {
    Some(Digit)
  } else if glyph == "A" {
    Some(Letter)
  } else if glyph == "?" {
    Some(Either)
  } else if glyph == "*" {
    Some(Any)
  } else {
    None
  }
}

///|
pub fn Slot::takes(self : Slot, text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let code = text[0].to_int()
  let letter = (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)
  let digit = code >= 0x30 && code <= 0x39
  match self {
    Digit => digit
    Letter => letter
    Either => letter || digit
    Any => true
  }
}

///|
pub fn Slot::glyph(self : Slot) -> String {
  match self {
    Digit => "#"
    Letter => "A"
    Either => "?"
    Any => "*"
  }
}

///|
/// A field ruled by a template: a phone number, a date, a licence key.
///
/// Letters and digits go into the places the mask opens for them and the
/// literals between them are written for the user; the arrows move over the
/// places, Backspace empties one and Enter submits.
pub struct MaskedInput {
  mask : String
  filled : Array[String]
  mut at : Int32
  mut focused : Bool
  placeholder : String
  style : @style.Style
  literal_style : @style.Style
  cursor_style : @style.Style
}

///|
pub fn MaskedInput::new(
  mask : String,
  placeholder~ : String = "_",
  style~ : @style.Style = @style.default,
  literal_style~ : @style.Style = @style.Style::new(dim=true),
  cursor_style~ : @style.Style = @style.Style::new(reverse=true),
) -> MaskedInput {
  let slots = slots_of(mask)
  let filled : Array[String] = []
  for _ in slots {
    filled.push("")
  }
  let field : MaskedInput = {
    mask,
    filled,
    at: -1,
    focused: false,
    placeholder,
    style,
    literal_style,
    cursor_style,
  }
  field.at = if slots.length() > 0 { 0 } else { -1 }
  field
}

///|
/// The value as it reads: what was typed, with the literals in place.
pub fn MaskedInput::text(self : MaskedInput) -> String {
  let out = StringBuilder()
  let slots = slots_of(self.mask)
  let mut used = 0
  for i in 0..<self.mask.length() {
    let glyph = self.mask[i:i + 1].to_owned()
    match Slot::of(glyph) {
      Some(_) => {
        if used < self.filled.length() {
          if self.filled[used].length() > 0 {
            out.write_string(self.filled[used])
          } else {
            out.write_string(self.placeholder)
          }
        }
        used = used + 1
      }
      None => out.write_string(glyph)
    }
  }
  ignore(slots)
  out.to_string()
}

///|
/// What was typed in the places the mask opens, in order.
pub fn MaskedInput::values(self : MaskedInput) -> Array[String] {
  self.filled
}

///|
/// Whether every place has something in it.
pub fn MaskedInput::is_complete(self : MaskedInput) -> Bool {
  if self.filled.length() == 0 {
    return false
  }
  for value in self.filled {
    if value.length() == 0 {
      return false
    }
  }
  true
}

///|
/// The place the caret is on.
pub fn MaskedInput::cursor(self : MaskedInput) -> Int32 {
  self.at
}

///|
/// Fill the places from a whole value, reading past the literals.
pub fn MaskedInput::set(self : MaskedInput, text : String) -> Unit {
  let slots = slots_of(self.mask)
  let mut used = 0
  let mut at = 0
  while used < self.filled.length() && at < text.length() {
    let glyph = text[at:at + 1].to_owned()
    if slots[used].takes(glyph) {
      self.filled[used] = glyph
      used = used + 1
    }
    at = at + 1
  }
  self.at = if self.filled.length() > 0 { used } else { -1 }
  if self.at >= self.filled.length() {
    self.at = self.filled.length() - 1
  }
}

///|
pub fn MaskedInput::clear(self : MaskedInput) -> Unit {
  for i in 0..<self.filled.length() {
    self.filled[i] = ""
  }
  self.at = if self.filled.length() > 0 { 0 } else { -1 }
}

///|
pub impl Widget for MaskedInput with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let slots = slots_of(self.mask)
  let segs : Array[@strip.Strip] = []
  let mut used = 0
  for i in 0..<self.mask.length() {
    let glyph = self.mask[i:i + 1].to_owned()
    match Slot::of(glyph) {
      Some(_) => {
        let here = used
        used = used + 1
        let shown = if here < self.filled.length() &&
          self.filled[here].length() > 0 {
          self.filled[here]
        } else {
          self.placeholder
        }
        let ink = if self.focused && here == self.at {
          self.cursor_style
        } else {
          self.style
        }
        segs.push(@strip.Strip::of(shown, ink))
      }
      None => segs.push(@strip.Strip::of(glyph, self.literal_style))
    }
  }
  ignore(slots)
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
pub impl Widget for MaskedInput with fn hint(self, size) {
  let cells = @strip.str_cells(self.mask)
  @geom.Size::new(if cells < size.width { cells } else { size.width }, 1)
}

///|
pub impl Widget for MaskedInput with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key)
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let place = self.place_at(mouse.x)
          if place >= 0 && place != self.at {
            self.at = place
            ctx.repaint()
          }
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for MaskedInput with fn focusable(_self) {
  true
}

///|
fn MaskedInput::key(self : MaskedInput, ctx : Ctx, key : @event.Key) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  let slots = slots_of(self.mask)
  match key.code {
    Left => self.step(-1, ctx)
    Right => self.step(1, ctx)
    Home => self.go_to(0, ctx)
    End => self.go_to(self.filled.length() - 1, ctx)
    Backspace => {
      if self.at < 0 {
        return false
      }
      if self.filled[self.at].length() > 0 {
        self.filled[self.at] = ""
      } else if self.at > 0 {
        self.at = self.at - 1
        self.filled[self.at] = ""
      }
      ctx.emit(Changed(id=ctx.id, value=self.text()))
      ctx.repaint()
      true
    }
    Delete => {
      if self.at < 0 {
        return false
      }
      self.filled[self.at] = ""
      ctx.emit(Changed(id=ctx.id, value=self.text()))
      ctx.repaint()
      true
    }
    Enter => {
      ctx.emit(Changed(id=ctx.id, value=self.text()))
      ctx.emit(Submitted(id=ctx.id, value=self.text()))
      true
    }
    Char(code) =>
      match code.to_char() {
        Some(letter) => {
          let text = letter.to_string()
          if self.at < 0 || self.at >= slots.length() {
            return false
          }
          if !slots[self.at].takes(text) {
            // A character the place will not take: try the next one that will,
            // which is how a mask pasted into is filled.
            let mut probe = self.at + 1
            while probe < slots.length() && !slots[probe].takes(text) {
              probe = probe + 1
            }
            if probe >= slots.length() {
              return false
            }
            self.at = probe
          }
          self.filled[self.at] = text
          if self.at + 1 < self.filled.length() {
            self.at = self.at + 1
          }
          ctx.emit(Changed(id=ctx.id, value=self.text()))
          ctx.repaint()
          true
        }
        None => false
      }
    _ => false
  }
}

///|
fn MaskedInput::step(self : MaskedInput, by : Int32, ctx : Ctx) -> Bool {
  self.go_to(self.at + by, ctx)
}

///|
fn MaskedInput::go_to(self : MaskedInput, place : Int32, ctx : Ctx) -> Bool {
  if self.filled.length() == 0 {
    return false
  }
  let next = constrain(place, 0, self.filled.length() - 1)
  if next == self.at {
    return true
  }
  self.at = next
  ctx.repaint()
  true
}

///|
/// The place at `x`, counting in the cells the mask is drawn in.
fn MaskedInput::place_at(self : MaskedInput, x : Int32) -> Int32 {
  let mut at = 0
  let mut used = 0
  for i in 0..<self.mask.length() {
    let glyph = self.mask[i:i + 1].to_owned()
    let span = @strip.str_cells(glyph)
    match Slot::of(glyph) {
      Some(_) => {
        if x < at + span {
          return used
        }
        used = used + 1
      }
      None => ()
    }
    at = at + span
  }
  -1
}

///|
/// The places a mask opens, in the order they come.
fn slots_of(mask : String) -> Array[Slot] {
  let out : Array[Slot] = []
  for i in 0..<mask.length() {
    match Slot::of(mask[i:i + 1].to_owned()) {
      Some(slot) => out.push(slot)
      None => ()
    }
  }
  out
}

///|
pub extend Slot with Debug::{to_repr}

///|
pub extend Slot with Eq::{not_equal, equal}

///|
pub extend MaskedInput with Widget::{focusable, handle, hint, render_line}
