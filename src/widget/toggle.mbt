// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The three-glyph button — a side, the state mark, the other side — with the
/// label beside it, one space on each side, in either order. State is shown
/// by the mark's style.
fn toggle_line(
  mark : String,
  label : String,
  on : Bool,
  button_first : Bool,
  on_style : @style.Style,
  off_style : @style.Style,
  label_style : @style.Style,
  fill : @style.Style,
  width : Int32,
) -> @strip.Strip {
  let style = if on { on_style } else { off_style }
  let button = @strip.Strip::of("▐" + mark + "▌", style)
  let padded = if label.length() == 0 {
    @strip.Strip::empty()
  } else {
    @strip.Strip::of(" " + label + " ", label_style)
  }
  let body = if button_first {
    @strip.Strip::join([button, padded])
  } else {
    @strip.Strip::join([padded, button])
  }
  body.pad_to(width, fill)
}

///|
/// The cells the toggle asks for: the button, plus the label and a space on
/// each side of it, only when there is a label.
fn toggle_width(label : String) -> Int32 {
  if label.length() == 0 {
    3
  } else {
    3 + 2 + @strip.str_cells(label)
  }
}

///|
pub struct Checkbox {
  mut label : String
  mut value : Bool
  button_first : Bool
  on_style : @style.Style
  off_style : @style.Style
  label_style : @style.Style
  focus_style : @style.Style
  mut focused : Bool
} derive(Eq, Debug)

///|
pub fn Checkbox::new(
  label : String,
  value~ : Bool = false,
  button_first~ : Bool = true,
  on_style~ : @style.Style = @style.Style::new(fg=@style.green),
  off_style~ : @style.Style = @style.Style::new(fg=@style.bright_black),
  label_style~ : @style.Style = @style.default,
  focus_style~ : @style.Style = @style.Style::new(reverse=true),
) -> Checkbox {
  {
    label,
    value,
    button_first,
    on_style,
    off_style,
    label_style,
    focus_style,
    focused: false,
  }
}

///|
pub fn Checkbox::label(self : Checkbox) -> String {
  self.label
}

///|
pub fn Checkbox::set_label(self : Checkbox, label : String) -> Unit {
  self.label = label
}

///|
pub fn Checkbox::value(self : Checkbox) -> Bool {
  self.value
}

///|
/// Set the value without reporting it, for programmatic changes.
pub fn Checkbox::set_value(self : Checkbox, value : Bool) -> Unit {
  self.value = value
}

///|
pub fn Checkbox::toggle(self : Checkbox) -> Unit {
  self.value = !self.value
}

///|
fn Checkbox::line(self : Checkbox, width : Int32) -> @strip.Strip {
  let label = self.label_style
  let label = if self.focused { label.merge(self.focus_style) } else { label }
  toggle_line(
    "X",
    self.label,
    self.value,
    self.button_first,
    self.on_style,
    self.off_style,
    label,
    self.label_style,
    width,
  )
}

///|
pub impl Widget for Checkbox with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.label_style)
  }
  self.line(size.width)
}

///|
pub impl Widget for Checkbox with fn hint(self, _size) {
  @geom.Size::new(toggle_width(self.label), 1)
}

///|
pub impl Widget for Checkbox with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() && (key.code == Char(32) || key.code == Enter) {
        self.toggle()
        ctx.emit(Toggled(id=ctx.id, on=self.value))
        ctx.repaint()
        true
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          self.toggle()
          ctx.emit(Toggled(id=ctx.id, on=self.value))
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Checkbox with fn focusable(_self) {
  true
}

///|
pub struct RadioButton {
  mut label : String
  mut value : Bool
  button_first : Bool
  on_style : @style.Style
  off_style : @style.Style
  label_style : @style.Style
  focus_style : @style.Style
  mut focused : Bool
} derive(Eq, Debug)

///|
pub fn RadioButton::new(
  label : String,
  value~ : Bool = false,
  button_first~ : Bool = true,
  on_style~ : @style.Style = @style.Style::new(fg=@style.green),
  off_style~ : @style.Style = @style.Style::new(fg=@style.bright_black),
  label_style~ : @style.Style = @style.default,
  focus_style~ : @style.Style = @style.Style::new(reverse=true),
) -> RadioButton {
  {
    label,
    value,
    button_first,
    on_style,
    off_style,
    label_style,
    focus_style,
    focused: false,
  }
}

///|
pub fn RadioButton::label(self : RadioButton) -> String {
  self.label
}

///|
pub fn RadioButton::set_label(self : RadioButton, label : String) -> Unit {
  self.label = label
}

///|
pub fn RadioButton::value(self : RadioButton) -> Bool {
  self.value
}

///|
/// Set the value without reporting it; a `RadioSet` uses this to turn the
/// others off.
pub fn RadioButton::set_value(self : RadioButton, value : Bool) -> Unit {
  self.value = value
}

///|
fn RadioButton::line(self : RadioButton, width : Int32) -> @strip.Strip {
  let label = self.label_style
  let label = if self.focused { label.merge(self.focus_style) } else { label }
  toggle_line(
    "●",
    self.label,
    self.value,
    self.button_first,
    self.on_style,
    self.off_style,
    label,
    self.label_style,
    width,
  )
}

///|
pub impl Widget for RadioButton with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.label_style)
  }
  self.line(size.width)
}

///|
pub impl Widget for RadioButton with fn hint(self, _size) {
  @geom.Size::new(toggle_width(self.label), 1)
}

///|
pub impl Widget for RadioButton with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() && (key.code == Char(32) || key.code == Enter) {
        self.toggle(ctx)
        true
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          self.toggle(ctx)
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for RadioButton with fn focusable(_self) {
  true
}

///|
/// A radio button turns on and stays on; the set around it — or the caller —
/// turns the others off.
fn RadioButton::toggle(self : RadioButton, ctx : Ctx) -> Unit {
  if !self.value {
    self.value = true
    ctx.emit(Toggled(id=ctx.id, on=true))
  }
  ctx.repaint()
}

///|
pub extend Checkbox with Debug::{to_repr}

///|
pub extend Checkbox with Eq::{not_equal, equal}

///|
pub extend Checkbox with Widget::{focusable, handle, hint, render_line}

///|
pub extend RadioButton with Debug::{to_repr}

///|
pub extend RadioButton with Eq::{not_equal, equal}

///|
pub extend RadioButton with Widget::{focusable, handle, hint, render_line}
