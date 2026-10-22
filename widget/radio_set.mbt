// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Radio buttons grouped into a set: turning one on turns the others off, the
/// arrows move a cursor that is separate from which button is pressed, and
/// pressing the pressed button again changes nothing. A click on a row moves
/// the cursor there and presses it, the way Textual's `RadioSet` does.
pub struct RadioSet {
  buttons : Array[RadioButton]
  mut selected : Int32
  mut pressed : Int32
  mut offset : Int32
  mut focused : Bool
  cursor : @style.Style
  blurred_cursor : @style.Style
} derive(Eq, Debug)

///|
pub fn RadioSet::new(
  buttons : Array[RadioButton],
  cursor~ : @style.Style = @style.Style::new(reverse=true),
  blurred_cursor~ : @style.Style = @style.Style::new(dim=true, reverse=true),
) -> RadioSet {
  let mut pressed = -1
  let mut seen = false
  for i in 0..<buttons.length() {
    if buttons[i].value {
      if seen {
        // More than one arrived on; keep the first, turn the rest off.
        buttons[i].set_value(false)
      } else {
        seen = true
        pressed = i
      }
    }
  }
  {
    buttons,
    selected: if buttons.length() > 0 {
      0
    } else {
      -1
    },
    pressed,
    offset: 0,
    focused: false,
    cursor,
    blurred_cursor,
  }
}

///|
pub fn RadioSet::buttons(self : RadioSet) -> Array[RadioButton] {
  self.buttons
}

///|
/// The index of the pressed button, or -1 when none is pressed.
pub fn RadioSet::pressed_index(self : RadioSet) -> Int32 {
  self.pressed
}

///|
/// Press a button without reporting it; any other pressed button goes off.
pub fn RadioSet::set_pressed(self : RadioSet, index : Int32) -> Unit {
  if index < 0 || index >= self.buttons.length() {
    return
  }
  if self.pressed >= 0 && self.pressed < self.buttons.length() {
    self.buttons[self.pressed].set_value(false)
  }
  self.pressed = index
  self.buttons[index].set_value(true)
}

///|
/// The index the cursor rests on, or -1 when the set is empty.
pub fn RadioSet::selected_index(self : RadioSet) -> Int32 {
  self.selected
}

///|
pub fn RadioSet::set_selected(self : RadioSet, index : Int32) -> Unit {
  if index < 0 || index >= self.buttons.length() {
    return
  }
  self.selected = index
}

///|
pub impl Widget for RadioSet with fn render_line(self, row, size) {
  self.scroll_to_fit(size.height)
  let at = self.offset + row
  if at < 0 || at >= self.buttons.length() {
    return @strip.Strip::blank(size.width, @style.default)
  }
  let button = self.buttons[at]
  let mark = if at == self.selected {
    if self.focused {
      self.cursor
    } else {
      self.blurred_cursor
    }
  } else {
    @style.default
  }
  let label = if button.label.length() == 0 {
    @strip.Strip::empty()
  } else {
    @strip.Strip::of(" " + button.label + " ", mark)
  }
  let knob = @strip.Strip::of(
    "▐●▌",
    if button.value {
      button.on_style
    } else {
      button.off_style
    },
  )
  @strip.Strip::join([knob, label]).pad_to(size.width, @style.default)
}

///|
pub impl Widget for RadioSet with fn hint(self, size) {
  let mut widest = 0
  for button in self.buttons {
    let want = toggle_width(button.label) + 2
    if want > widest {
      widest = want
    }
  }
  @geom.Size::new(
    if widest > size.width {
      size.width
    } else {
      widest
    },
    self.buttons.length(),
  )
}

///|
pub impl Widget for RadioSet with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => {
      if !key.mods.is_none() {
        return false
      }
      match key.code {
        Up | Left => {
          self.move_cursor(-1, ctx)
          true
        }
        Down | Right => {
          self.move_cursor(1, ctx)
          true
        }
        Enter | Char(32) => {
          self.press(self.selected, ctx)
          true
        }
        _ => false
      }
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          self.selected = self.offset + mouse.y
          self.press(self.selected, ctx)
          true
        }
        ScrollUp => {
          self.move_cursor(-1, ctx)
          true
        }
        ScrollDown => {
          self.move_cursor(1, ctx)
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for RadioSet with fn focusable(_self) {
  true
}

///|
/// Moving the cursor wraps around at both ends, as Textual's set does.
fn RadioSet::move_cursor(self : RadioSet, step : Int32, ctx : Ctx) -> Unit {
  let count = self.buttons.length()
  if count == 0 {
    return
  }
  let at = if self.selected < 0 { 0 } else { self.selected }
  self.selected = ((at + step) % count + count) % count
  ctx.repaint()
}

///|
/// Pressing the pressed button again changes nothing and reports nothing;
/// pressing any other moves the press to it and reports the move.
fn RadioSet::press(self : RadioSet, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 || index >= self.buttons.length() || index == self.pressed {
    return
  }
  self.set_pressed(index)
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.repaint()
}

///|
fn RadioSet::scroll_to_fit(self : RadioSet, height : Int32) -> Unit {
  if height <= 0 || self.buttons.length() == 0 {
    self.offset = 0
    return
  }
  if self.selected < self.offset {
    self.offset = self.selected
  } else if self.selected >= self.offset + height {
    self.offset = self.selected - height + 1
  }
  let last = self.buttons.length() - height
  self.offset = clamp(self.offset, 0, if last < 0 { 0 } else { last })
}

///|
pub extend RadioSet with Debug::{to_repr}

///|
pub extend RadioSet with Eq::{not_equal, equal}

///|
pub extend RadioSet with Widget::{focusable, handle, hint, render_line}
