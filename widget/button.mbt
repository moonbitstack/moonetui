// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A press. The label is centred, the widget takes focus when clicked, and both
/// Enter and Space press it — a terminal application is driven from the keyboard
/// at least as often as from the mouse.
pub struct Button {
  mut text : String
  style : @style.Style
  focus_style : @style.Style
  mut disabled : Bool
  mut focused : Bool
}

///|
/// A button with this label.
pub fn Button::new(
  text : String,
  style? : @style.Style = @style.Style::new(),
  focus_style? : @style.Style = @style.Style::new(reverse=true),
) -> Button {
  { text, style, focus_style, disabled: false, focused: false, }
}

///|
/// Replace the label.
pub fn Button::set(self : Button, text : String) -> Unit {
  self.text = text
}

///|
/// The label as it stands.
pub fn Button::text(self : Button) -> String {
  self.text
}

///|
/// A disabled button still draws, but does not take focus and cannot be pressed.
pub fn Button::disable(self : Button, disabled : Bool) -> Unit {
  self.disabled = disabled
}

///|
/// Whether the button is disabled.
pub fn Button::is_disabled(self : Button) -> Bool {
  self.disabled
}

///|
pub impl Widget for Button with fn render_line(self, row, size) {
  let style = if self.focused { self.focus_style } else { self.style }
  if row != 0 {
    return @strip.Strip::blank(size.width, style)
  }
  align_line(self.text, size.width, Center, style)
}

///|
pub impl Widget for Button with fn hint(self, _size) {
  // Two columns of breathing room on each side, which is what makes a button
  // read as a button rather than as a word.
  @geom.Size::new(@strip.str_cells(self.text) + 4, 1)
}

///|
pub impl Widget for Button with fn handle(self, ctx, msg) {
  if self.disabled {
    return false
  }
  match msg {
    Focus(gained) => {
      // A widget learns it has focus the same way it learns anything else, so
      // rendering never has to ask the application about its own state.
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
/// Whether the button currently holds focus.
pub fn Button::has_focus(self : Button) -> Bool {
  self.focused
}

///|
pub extend Button with Widget::{focusable, handle, hint, render_line}
