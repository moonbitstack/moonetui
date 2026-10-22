// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Selection {
  prompt : String
  value : String
  initial : Bool
  disabled : Bool
} derive(Eq, Debug)

///|
pub fn Selection::new(
  prompt : String,
  value : String,
  initial_state~ : Bool = false,
  disabled~ : Bool = false,
) -> Selection {
  { prompt, value, initial: initial_state, disabled, }
}

///|
pub struct SelectionList {
  mut options : Array[Selection]
  mut states : Array[Bool]
  mut highlighted : Int32
  mut hover : Int32
  mut offset : Int32
  mut seen : Int32
  mut focused : Bool
  style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
  disabled_style : @style.Style
  selected_style : @style.Style
  unselected_style : @style.Style
} derive(Eq, Debug)

///|
pub fn SelectionList::new(
  options~ : Array[Selection] = [],
  style~ : @style.Style = @style.Style::new(),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
  disabled_style~ : @style.Style = @style.Style::new(dim=true),
  selected_style~ : @style.Style = @style.Style::new(fg=@style.green),
  unselected_style~ : @style.Style = @style.Style::new(dim=true),
) -> SelectionList {
  let list : SelectionList = {
    options: [],
    states: [],
    highlighted: -1,
    hover: -1,
    offset: 0,
    seen: 0,
    focused: false,
    style,
    highlight,
    blurred_highlight,
    disabled_style,
    selected_style,
    unselected_style,
  }
  list.set_options(options)
  list
}

///|
pub fn SelectionList::options(self : SelectionList) -> Array[Selection] {
  self.options
}

///|
pub fn SelectionList::highlighted(self : SelectionList) -> Int32 {
  if self.highlighted >= 0 && self.highlighted < self.options.length() {
    self.highlighted
  } else {
    -1
  }
}

///|
pub fn SelectionList::set_options(
  self : SelectionList,
  options : Array[Selection],
) -> Unit {
  self.options = options
  let states : Array[Bool] = []
  for option in options {
    states.push(option.initial)
  }
  self.states = states
  self.highlighted = -1
  self.hover = -1
  self.offset = 0
  self.first()
}

///|
pub fn SelectionList::selected(self : SelectionList) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<self.options.length() {
    if self.states[i] {
      out.push(self.options[i].value)
    }
  }
  out
}

///|
pub fn SelectionList::is_selected(self : SelectionList, index : Int32) -> Bool {
  if index < 0 || index >= self.states.length() {
    return false
  }
  self.states[index]
}

///|
pub fn SelectionList::set_selected(
  self : SelectionList,
  index : Int32,
  selected : Bool,
) -> Unit {
  if index < 0 || index >= self.states.length() {
    return
  }
  if self.states[index] != selected {
    self.states[index] = selected
  }
}

///|
pub fn SelectionList::toggle(self : SelectionList, index : Int32) -> Unit {
  if index < 0 || index >= self.states.length() {
    return
  }
  self.states[index] = !self.states[index]
}

///|
pub fn SelectionList::toggle_all(self : SelectionList) -> Unit {
  for i in 0..<self.states.length() {
    self.states[i] = !self.states[i]
  }
}

///|
pub fn SelectionList::select_all(self : SelectionList) -> Unit {
  for i in 0..<self.states.length() {
    self.states[i] = true
  }
}

///|
pub fn SelectionList::deselect_all(self : SelectionList) -> Unit {
  for i in 0..<self.states.length() {
    self.states[i] = false
  }
}

///|
pub impl Widget for SelectionList with fn render_line(self, row, size) {
  self.scroll_to_fit(size.height)
  let index = self.offset + row
  if size.width <= 0 || index < 0 || index >= self.options.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let option = self.options[index]
  let button = if option.disabled {
    self.disabled_style
  } else if self.states[index] {
    self.selected_style
  } else {
    self.unselected_style
  }
  let prompt_width = size.width - 4
  let prompt_style = if option.disabled {
    self.disabled_style
  } else if index == self.highlighted {
    if self.focused {
      self.highlight
    } else {
      self.blurred_highlight
    }
  } else if index == self.hover && self.hover != self.highlighted {
    self.unselected_style
  } else {
    self.style
  }
  let prompt = if prompt_width <= 0 {
    @strip.Strip::empty()
  } else {
    align_line(
      clip_to(option.prompt, prompt_width),
      prompt_width,
      Left,
      prompt_style,
    )
  }
  @strip.Strip::join([
    @strip.Strip::of("▐", self.style),
    @strip.Strip::of("X", button),
    @strip.Strip::of("▌", self.style),
    @strip.Strip::of(" ", self.style),
    prompt,
  ])
}

///|
pub impl Widget for SelectionList with fn hint(self, _size) {
  let mut widest = 4
  for option in self.options {
    let cells = @strip.str_cells(option.prompt) + 4
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(widest, self.options.length())
}

///|
pub impl Widget for SelectionList with fn handle(self, ctx, msg) {
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
        Up => {
          self.move_highlight(
            find_selection(self.options, self.highlighted, -1),
            ctx,
          )
          true
        }
        Down => {
          self.move_highlight(
            find_selection(self.options, self.highlighted, 1),
            ctx,
          )
          true
        }
        Home => {
          self.move_highlight(find_selection(self.options, -1, 1), ctx)
          true
        }
        End => {
          self.move_highlight(
            find_selection(self.options, self.options.length(), -1),
            ctx,
          )
          true
        }
        PageUp => {
          let step = if self.seen > 1 { self.seen - 1 } else { 1 }
          self.move_highlight(
            find_selection(self.options, self.highlighted - step, 1),
            ctx,
          )
          true
        }
        PageDown => {
          let step = if self.seen > 1 { self.seen - 1 } else { 1 }
          self.move_highlight(
            find_selection(self.options, self.highlighted + step, -1),
            ctx,
          )
          true
        }
        Enter | Char(32) => {
          self.toggle_highlighted(ctx)
          true
        }
        _ => false
      }
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let index = self.offset + mouse.y
          if index >= 0 && index < self.options.length() {
            self.hover = index
            if !self.options[index].disabled {
              self.move_highlight(index, ctx)
              self.toggle_at(index, ctx)
            }
          }
          true
        }
        Move => {
          let index = self.offset + mouse.y
          if index >= 0 && index < self.options.length() && index != self.hover {
            self.hover = index
            ctx.repaint()
          }
          true
        }
        ScrollUp => {
          self.offset = self.offset - 1
          ctx.repaint()
          true
        }
        ScrollDown => {
          self.offset = self.offset + 1
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for SelectionList with fn focusable(_self) {
  true
}

///|
fn SelectionList::first(self : SelectionList) -> Unit {
  self.highlighted = find_selection(self.options, -1, 1)
}

///|
fn SelectionList::move_highlight(
  self : SelectionList,
  index : Int32,
  ctx : Ctx,
) -> Unit {
  if index < 0 || index >= self.options.length() || index == self.highlighted {
    return
  }
  self.highlighted = index
  ctx.emit(Highlighted(id=ctx.id, index~))
  ctx.repaint()
}

///|
fn SelectionList::toggle_highlighted(self : SelectionList, ctx : Ctx) -> Unit {
  let at = self.highlighted()
  if at < 0 || self.options[at].disabled {
    return
  }
  self.toggle_at(at, ctx)
}

///|
fn SelectionList::toggle_at(
  self : SelectionList,
  index : Int32,
  ctx : Ctx,
) -> Unit {
  self.states[index] = !self.states[index]
  ctx.emit(ToggledAt(id=ctx.id, index~, on=self.states[index]))
  ctx.emit(Changed(id=ctx.id, value=self.selected().join(",")))
  ctx.repaint()
}

///|
fn SelectionList::scroll_to_fit(self : SelectionList, height : Int32) -> Unit {
  self.seen = height
  let count = self.options.length()
  let max = count - height
  self.offset = clamp(self.offset, 0, if max < 0 { 0 } else { max })
  if self.highlighted < 0 {
    return
  }
  if self.highlighted < self.offset {
    self.offset = self.highlighted
  } else if height > 0 && self.highlighted >= self.offset + height {
    self.offset = self.highlighted - height + 1
  }
  self.offset = clamp(self.offset, 0, if max < 0 { 0 } else { max })
}

///|
fn find_selection(
  options : Array[Selection],
  anchor : Int32,
  direction : Int32,
) -> Int32 {
  let count = options.length()
  if count == 0 {
    return -1
  }
  let mut probe = anchor + direction
  let mut steps = 0
  while steps < count {
    if probe < 0 {
      probe = count - 1
    } else if probe >= count {
      probe = 0
    }
    if !options[probe].disabled {
      return probe
    }
    probe = probe + direction
    steps = steps + 1
  }
  -1
}

///|
pub extend Selection with Debug::{to_repr}

///|
pub extend Selection with Eq::{not_equal, equal}

///|
pub extend SelectionList with Debug::{to_repr}

///|
pub extend SelectionList with Eq::{not_equal, equal}

///|
pub extend SelectionList with Widget::{focusable, handle, hint, render_line}
