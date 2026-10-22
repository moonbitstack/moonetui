// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Choice {
  prompt : String
  mut disabled : Bool
  divider : Bool
} derive(Eq, Debug)

///|
pub fn Choice::new(prompt : String, disabled~ : Bool = false) -> Choice {
  { prompt, disabled, divider: false, }
}

///|
pub struct OptionList {
  mut options : Array[Choice]
  mut highlighted : Int32
  mut hover : Int32
  mut offset : Int32
  mut seen : Int32
  mut follow : Bool
  mut focused : Bool
  style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
  disabled_style : @style.Style
  hover_style : @style.Style
  separator_style : @style.Style
} derive(Eq, Debug)

///|
pub fn OptionList::new(
  options~ : Array[Choice] = [],
  style~ : @style.Style = @style.Style::new(),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
  disabled_style~ : @style.Style = @style.Style::new(dim=true),
  hover_style~ : @style.Style = @style.Style::new(dim=true),
  separator_style~ : @style.Style = @style.Style::new(dim=true),
) -> OptionList {
  let list : OptionList = {
    options: [],
    highlighted: -1,
    hover: -1,
    offset: 0,
    seen: 0,
    follow: true,
    focused: false,
    style,
    highlight,
    blurred_highlight,
    disabled_style,
    hover_style,
    separator_style,
  }
  list.set_options(options)
  list
}

///|
pub fn OptionList::options(self : OptionList) -> Array[Choice] {
  self.options
}

///|
pub fn OptionList::option_count(self : OptionList) -> Int32 {
  self.options.length()
}

///|
pub fn OptionList::highlighted(self : OptionList) -> Int32 {
  if self.highlighted >= 0 && self.highlighted < self.options.length() {
    self.highlighted
  } else {
    -1
  }
}

///|
pub fn OptionList::set_options(
  self : OptionList,
  options : Array[Choice],
) -> Unit {
  self.options = options
  self.highlighted = -1
  self.hover = -1
  self.offset = 0
  self.follow = true
  self.first()
}

///|
pub fn OptionList::add_option(self : OptionList, option : Choice) -> Unit {
  self.options.push(option)
  if self.highlighted < 0 {
    self.highlighted = find_next_enabled(self.options, -1, 1)
  }
}

///|
pub fn OptionList::add_separator(self : OptionList) -> Unit {
  let last = self.options.length() - 1
  if last >= 0 {
    self.options[last] = { ..self.options[last], divider: true, }
  }
}

///|
pub fn OptionList::clear_options(self : OptionList) -> Unit {
  self.options = []
  self.highlighted = -1
  self.hover = -1
  self.offset = 0
}

///|
pub fn OptionList::set_disabled(
  self : OptionList,
  index : Int32,
  disabled : Bool,
) -> Unit {
  if index < 0 || index >= self.options.length() {
    return
  }
  self.options[index] = { ..self.options[index], disabled, }
  if disabled && index == self.highlighted {
    self.highlighted = find_next_enabled(self.options, index, 1)
  }
}

///|
pub impl Widget for OptionList with fn render_line(self, row, size) {
  self.scroll_to_fit(size.height)
  let y = self.offset + row
  let hit = self.row_map(y)
  match hit {
    None => @strip.Strip::blank(size.width, self.style)
    Some((index, line)) => {
      let option = self.options[index]
      if line == 1 {
        let out = StringBuilder()
        for _ in 0..<size.width {
          out.write_string("─")
        }
        return @strip.Strip::of(out.to_string(), self.separator_style)
      }
      let style = if option.disabled {
        self.disabled_style
      } else if index == self.highlighted {
        if self.focused {
          self.highlight
        } else {
          self.blurred_highlight
        }
      } else if index == self.hover && self.hover != self.highlighted {
        self.hover_style
      } else {
        self.style
      }
      align_line(clip_to(option.prompt, size.width), size.width, Left, style)
    }
  }
}

///|
pub impl Widget for OptionList with fn hint(self, _size) {
  let mut widest = 0
  for option in self.options {
    let cells = @strip.str_cells(option.prompt)
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(widest, self.total_rows())
}

///|
pub impl Widget for OptionList with fn handle(self, ctx, msg) {
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
            find_next_enabled(self.options, self.highlighted, -1),
            ctx,
          )
          true
        }
        Down => {
          self.move_highlight(
            find_next_enabled(self.options, self.highlighted, 1),
            ctx,
          )
          true
        }
        Home => {
          self.move_highlight(find_first_enabled(self.options), ctx)
          true
        }
        End => {
          self.move_highlight(find_last_enabled(self.options), ctx)
          true
        }
        PageUp => {
          self.move_highlight(self.page(-1), ctx)
          true
        }
        PageDown => {
          self.move_highlight(self.page(1), ctx)
          true
        }
        Enter => {
          let at = self.highlighted()
          if at >= 0 && !self.options[at].disabled {
            ctx.emit(Selected(id=ctx.id, index=at))
          }
          true
        }
        _ => false
      }
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let hit = self.row_map(self.offset + mouse.y)
          match hit {
            Some((index, 0)) => {
              self.hover = index
              if !self.options[index].disabled {
                self.move_highlight(index, ctx)
                ctx.emit(Selected(id=ctx.id, index~))
              }
            }
            _ => ()
          }
          true
        }
        Move => {
          let hit = self.row_map(self.offset + mouse.y)
          let index = match hit {
            Some((at, 0)) => at
            _ => -1
          }
          if index != self.hover {
            self.hover = index
            ctx.repaint()
          }
          true
        }
        ScrollUp => {
          self.offset = self.offset - 1
          self.follow = false
          ctx.repaint()
          true
        }
        ScrollDown => {
          self.offset = self.offset + 1
          self.follow = false
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for OptionList with fn focusable(_self) {
  true
}

///|
fn OptionList::move_highlight(
  self : OptionList,
  index : Int32,
  ctx : Ctx,
) -> Unit {
  if index < 0 || index >= self.options.length() {
    return
  }
  if index == self.highlighted {
    return
  }
  self.highlighted = index
  self.follow = true
  if !self.options[index].disabled {
    ctx.emit(Highlighted(id=ctx.id, index~))
  }
  ctx.repaint()
}

///|
fn OptionList::first(self : OptionList) -> Unit {
  self.highlighted = find_first_enabled(self.options)
}

///|
fn OptionList::page(self : OptionList, direction : Int32) -> Int32 {
  let count = self.options.length()
  if count == 0 {
    return -1
  }
  let step = if self.seen > 1 { self.seen - 1 } else { 1 }
  let target = self.highlighted() + direction * step
  let clamped = clamp(target, 0, count - 1)
  find_next_enabled_no_wrap(self.options, clamped, direction)
}

///|
fn OptionList::row_map(self : OptionList, row : Int32) -> (Int32, Int32)? {
  if row < 0 {
    return None
  }
  let count = self.options.length()
  let last = count - 1
  let mut y = 0
  for i in 0..<count {
    if y == row {
      return Some((i, 0))
    }
    y = y + 1
    if self.options[i].divider && i != last {
      if y == row {
        return Some((i, 1))
      }
      y = y + 1
    }
  }
  None
}

///|
fn OptionList::total_rows(self : OptionList) -> Int32 {
  let count = self.options.length()
  if count == 0 {
    return 0
  }
  let mut rows = 0
  for i in 0..<count {
    rows = rows + 1
    if self.options[i].divider && i != count - 1 {
      rows = rows + 1
    }
  }
  rows
}

///|
/// Bring the highlight into view after it moves; otherwise leave the view
/// where the wheel put it, only kept within the options.
fn OptionList::scroll_to_fit(self : OptionList, height : Int32) -> Unit {
  self.seen = height
  let count = self.options.length()
  if self.follow && self.highlighted >= 0 && count > 0 {
    let at = clamp(self.highlighted, 0, count - 1)
    let top = self.line_of(at)
    let bottom = top + self.height_of(at) - 1
    if top < self.offset {
      self.offset = top
    } else if height > 0 && bottom >= self.offset + height {
      self.offset = bottom - height + 1
    }
    self.follow = false
  }
  let max = self.total_rows() - height
  self.offset = clamp(self.offset, 0, if max < 0 { 0 } else { max })
}

///|
fn OptionList::line_of(self : OptionList, index : Int32) -> Int32 {
  let mut y = 0
  for i in 0..<index {
    y = y + 1
    if self.options[i].divider && i != self.options.length() - 1 {
      y = y + 1
    }
  }
  y
}

///|
fn OptionList::height_of(self : OptionList, index : Int32) -> Int32 {
  if self.options[index].divider && index != self.options.length() - 1 {
    2
  } else {
    1
  }
}

///|
fn find_next_enabled(
  options : Array[Choice],
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
fn find_next_enabled_no_wrap(
  options : Array[Choice],
  anchor : Int32,
  direction : Int32,
) -> Int32 {
  let count = options.length()
  let mut probe = anchor
  while probe >= 0 && probe < count {
    if !options[probe].disabled {
      return probe
    }
    probe = probe + direction
  }
  -1
}

///|
fn find_first_enabled(options : Array[Choice]) -> Int32 {
  find_next_enabled_no_wrap(options, 0, 1)
}

///|
fn find_last_enabled(options : Array[Choice]) -> Int32 {
  find_next_enabled_no_wrap(options, options.length() - 1, -1)
}

///|
pub extend Choice with Debug::{to_repr}

///|
pub extend Choice with Eq::{not_equal, equal}

///|
pub extend OptionList with Debug::{to_repr}

///|
pub extend OptionList with Eq::{not_equal, equal}

///|
pub extend OptionList with Widget::{focusable, handle, hint, render_line}
