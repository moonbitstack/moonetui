// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The switch: a four-wide strip, half thumb and half track, the thumb on
/// the left when off and on the right when on.
pub struct Switch {
  mut value : Bool
  on_style : @style.Style
  off_style : @style.Style
  track : @style.Style
} derive(Eq, Debug)

///|
pub fn Switch::new(
  value~ : Bool = false,
  on_style~ : @style.Style = @style.Style::new(
    fg=@style.green,
    bg=@style.Colour::rgb(85, 85, 85),
    reverse=true,
  ),
  off_style~ : @style.Style = @style.Style::new(
    fg=@style.bright_black,
    bg=@style.Colour::rgb(85, 85, 85),
    reverse=true,
  ),
  track~ : @style.Style = @style.Style::new(bg=@style.Colour::rgb(85, 85, 85)),
) -> Switch {
  { value, on_style, off_style, track, }
}

///|
pub fn Switch::value(self : Switch) -> Bool {
  self.value
}

///|
/// Set the value without reporting it, for programmatic changes.
pub fn Switch::set_value(self : Switch, value : Bool) -> Unit {
  self.value = value
}

///|
pub fn Switch::toggle(self : Switch) -> Unit {
  self.value = !self.value
}

///|
pub impl Widget for Switch with fn render_line(self, _row, size) {
  let thumb_style = if self.value { self.on_style } else { self.off_style }
  let thumb = @strip.Strip::blank(2, thumb_style)
  let rail = @strip.Strip::blank(2, self.track)
  let bar = if self.value {
    @strip.Strip::join([rail, thumb])
  } else {
    @strip.Strip::join([thumb, rail])
  }
  bar.pad_to(size.width, @style.default)
}

///|
pub impl Widget for Switch with fn hint(self, _size) {
  ignore(self)
  @geom.Size::new(4, 1)
}

///|
pub impl Widget for Switch with fn handle(self, ctx, msg) {
  match msg {
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
pub impl Widget for Switch with fn focusable(_self) {
  true
}

///|
pub extend Switch with Debug::{to_repr}

///|
pub extend Switch with Eq::{not_equal, equal}

///|
pub extend Switch with Widget::{focusable, handle, hint, render_line}
