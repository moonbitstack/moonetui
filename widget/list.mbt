// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A vertical list with one highlighted row.
///
/// The view scrolls to keep the highlight visible, and the highlight is a row
/// index rather than a value, so a list that changes under the cursor does not
/// silently point at something else.
pub struct ListView {
  mut items : Array[String]
  mut index : Int
  mut offset : Int
  mut focused : Bool
  style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
}

///|
/// A list of these rows, with the first one highlighted.
pub fn ListView::new(
  items : Array[String],
  style? : @style.Style = @style.Style::new(),
  highlight? : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight? : @style.Style = @style.Style::new(dim=true, reverse=true),
) -> ListView {
  {
    items,
    index: 0,
    offset: 0,
    focused: false,
    style,
    highlight,
    blurred_highlight,
  }
}

///|
/// The rows as they stand.
pub fn ListView::items(self : ListView) -> Array[String] {
  self.items
}

///|
/// Replace the rows, keeping the highlight inside the new list.
pub fn ListView::set(self : ListView, items : Array[String]) -> Unit {
  self.items = items
  self.index = clamp(self.index, 0, items.length() - 1)
  self.offset = clamp(self.offset, 0, items.length() - 1)
}

///|
/// Which row is highlighted, or -1 when the list is empty.
pub fn ListView::index(self : ListView) -> Int {
  if self.items.length() == 0 {
    -1
  } else {
    self.index
  }
}

///|
/// Highlight a row.
pub fn ListView::select(self : ListView, index : Int) -> Unit {
  self.index = clamp(index, 0, self.items.length() - 1)
}

///|
/// The first visible row.
pub fn ListView::offset(self : ListView) -> Int {
  self.offset
}

///|
pub impl Widget for ListView with fn render_line(self, row, size) {
  self.scroll_to_fit(size.height)
  let item = self.offset + row
  if item < 0 || item >= self.items.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let style = if item != self.index {
    self.style
  } else if self.focused {
    self.highlight
  } else {
    // An unfocused list still shows where the cursor is, more quietly: losing
    // focus should not lose the reader's place.
    self.blurred_highlight
  }
  align_line(self.items[item], size.width, Left, style)
}

///|
pub impl Widget for ListView with fn hint(self, size) {
  let mut widest = 0
  for item in self.items {
    let cells = @strip.str_cells(item)
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(
    if widest > size.width {
      size.width
    } else {
      widest
    },
    self.items.length(),
  )
}

///|
pub impl Widget for ListView with fn handle(self, ctx, msg) {
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
          self.move_by(-1, ctx)
          true
        }
        Down => {
          self.move_by(1, ctx)
          true
        }
        PageUp => {
          self.move_by(-page(ctx), ctx)
          true
        }
        PageDown => {
          self.move_by(page(ctx), ctx)
          true
        }
        Home => {
          self.move_to(0, ctx)
          true
        }
        End => {
          self.move_to(self.items.length() - 1, ctx)
          true
        }
        Enter => {
          if self.items.length() > 0 {
            ctx.emit(Selected(id=ctx.id, index=self.index))
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
          self.move_to(self.offset + mouse.y, ctx)
          true
        }
        ScrollUp => {
          self.move_by(-1, ctx)
          true
        }
        ScrollDown => {
          self.move_by(1, ctx)
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for ListView with fn focusable(_self) {
  true
}

///|
fn page(ctx : Ctx) -> Int {
  if ctx.size.height > 1 {
    ctx.size.height - 1
  } else {
    1
  }
}

///|
fn ListView::move_by(self : ListView, delta : Int, ctx : Ctx) -> Unit {
  self.move_to(self.index + delta, ctx)
}

///|
fn ListView::move_to(self : ListView, index : Int, ctx : Ctx) -> Unit {
  if self.items.length() == 0 {
    return
  }
  let next = clamp(index, 0, self.items.length() - 1)
  if next == self.index {
    return
  }
  self.index = next
  self.scroll_to_fit(ctx.size.height)
  ctx.repaint()
}

///|
/// Scroll so the highlighted row is inside a view of this height.
fn ListView::scroll_to_fit(self : ListView, height : Int) -> Unit {
  if height <= 0 || self.items.length() == 0 {
    self.offset = 0
    return
  }
  if self.index < self.offset {
    self.offset = self.index
  } else if self.index >= self.offset + height {
    self.offset = self.index - height + 1
  }
  let last = self.items.length() - height
  self.offset = clamp(self.offset, 0, if last < 0 { 0 } else { last })
}

///|
fn clamp(value : Int, low : Int, high : Int) -> Int {
  if high < low {
    return low
  }
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
pub extend ListView with Widget::{focusable, handle, hint, render_line}
