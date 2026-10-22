// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Button {
  mut text : String
  style : @style.Style
  focus_style : @style.Style
  mut disabled : Bool
  mut focused : Bool
}

///|
pub fn Button::new(
  text : String,
  style~ : @style.Style = @style.Style::new(),
  focus_style~ : @style.Style = @style.Style::new(reverse=true),
) -> Button {
  { text, style, focus_style, disabled: false, focused: false, }
}

///|
pub fn Button::set(self : Button, text : String) -> Unit {
  self.text = text
}

///|
pub fn Button::text(self : Button) -> String {
  self.text
}

///|
pub fn Button::disable(self : Button, disabled : Bool) -> Unit {
  self.disabled = disabled
}

///|
pub fn Button::is_disabled(self : Button) -> Bool {
  self.disabled
}

///|
pub impl Widget for Button with fn render_line(self, row, size) {
  let style = if self.focused { self.focus_style } else { self.style }
  if row != 0 {
    return @strip.Strip::blank(size.width, style)
  }
  align_line(self.text, size.width, Centre, style)
}

///|
pub impl Widget for Button with fn hint(self, _size) {
  @geom.Size::new(@strip.str_cells(self.text) + 4, 1)
}

///|
pub impl Widget for Button with fn handle(self, ctx, msg) {
  if self.disabled {
    return false
  }
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if pressing(key) {
        ctx.emit(Pressed(id=ctx.id))
        true
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          ctx.emit(Pressed(id=ctx.id))
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Button with fn focusable(self) {
  !self.disabled
}

///|
fn pressing(key : @event.Key) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  match key.code {
    Enter => true
    Char(32) => true
    _ => false
  }
}

///|
pub fn Button::has_focus(self : Button) -> Bool {
  self.focused
}

///|
pub extend Button with Widget::{focusable, handle, hint, render_line}
