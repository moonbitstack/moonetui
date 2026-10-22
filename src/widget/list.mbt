// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct ListView {
  mut items : Array[String]
  mut index : Int32
  mut offset : Int32
  mut focused : Bool
  style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
}

///|
pub fn ListView::new(
  items : Array[String],
  style~ : @style.Style = @style.Style::new(),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
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
pub fn ListView::items(self : ListView) -> Array[String] {
  self.items
}

///|
pub fn ListView::set(self : ListView, items : Array[String]) -> Unit {
  self.items = items
  self.index = clamp(self.index, 0, items.length() - 1)
  self.offset = clamp(self.offset, 0, items.length() - 1)
}

///|
pub fn ListView::index(self : ListView) -> Int32 {
  if self.items.length() == 0 {
    -1
  } else {
    self.index
  }
}

///|
pub fn ListView::select(self : ListView, index : Int32) -> Unit {
  self.index = clamp(index, 0, self.items.length() - 1)
}

///|
pub fn ListView::offset(self : ListView) -> Int32 {
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
fn page(ctx : Ctx) -> Int32 {
  if ctx.size.height > 1 {
    ctx.size.height - 1
  } else {
    1
  }
}

///|
fn ListView::move_by(self : ListView, delta : Int32, ctx : Ctx) -> Unit {
  self.move_to(self.index + delta, ctx)
}

///|
fn ListView::move_to(self : ListView, index : Int32, ctx : Ctx) -> Unit {
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
fn ListView::scroll_to_fit(self : ListView, height : Int32) -> Unit {
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
fn clamp(value : Int32, low : Int32, high : Int32) -> Int32 {
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
