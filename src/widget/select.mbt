// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Select {
  options : Array[(String, String)]
  prompt : String
  allow_blank : Bool
  mut chosen : Int32
  mut expanded : Bool
  mut highlighted : Int32
  mut offset : Int32
  mut seen : Int32
  mut follow : Bool
  mut query : String
  mut focused : Bool
  style : @style.Style
  dim_style : @style.Style
  arrow_style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
} derive(Eq, Debug)

///|
pub fn Select::new(
  options~ : Array[(String, String)] = [],
  prompt~ : String = "Select",
  allow_blank~ : Bool = true,
  value? : String,
  style~ : @style.Style = @style.Style::new(),
  dim_style~ : @style.Style = @style.Style::new(dim=true),
  arrow_style~ : @style.Style = @style.Style::new(dim=true),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
) -> Select {
  let select : Select = {
    options,
    prompt,
    allow_blank,
    chosen: -1,
    expanded: false,
    highlighted: -1,
    offset: 0,
    seen: 0,
    follow: true,
    query: "",
    focused: false,
    style,
    dim_style,
    arrow_style,
    highlight,
    blurred_highlight,
  }
  match value {
    Some(v) => select.set_value(v)
    None => if !allow_blank && options.length() > 0 { select.chosen = 0 }
  }
  select
}

///|
pub fn Select::value(self : Select) -> String? {
  if self.chosen >= 0 && self.chosen < self.options.length() {
    Some(self.options[self.chosen].1)
  } else {
    None
  }
}

///|
pub fn Select::set_value(self : Select, value : String) -> Unit {
  for i in 0..<self.options.length() {
    if self.options[i].1 == value {
      self.chosen = i
      return
    }
  }
}

///|
pub fn Select::is_blank(self : Select) -> Bool {
  self.chosen < 0
}

///|
pub fn Select::clear(self : Select) -> Unit {
  if self.allow_blank {
    self.chosen = -1
  }
}

///|
pub fn Select::expanded(self : Select) -> Bool {
  self.expanded
}

///|
pub impl Widget for Select with fn render_line(self, row, size) {
  if size.width <= 0 {
    return @strip.Strip::empty()
  }
  if row == 0 {
    let shown = if self.chosen >= 0 && self.chosen < self.options.length() {
      self.options[self.chosen].0
    } else {
      self.prompt
    }
    let label_style = if self.chosen >= 0 || !self.allow_blank {
      self.style
    } else {
      self.dim_style
    }
    let body_width = size.width - 2
    let arrow = if self.expanded { "▲" } else { "▼" }
    let body = if body_width <= 0 {
      @strip.Strip::empty()
    } else {
      @strip.Strip::of(clip_to(shown, body_width), label_style).pad_to(
        body_width, label_style,
      )
    }
    return @strip.Strip::join([
      @strip.Strip::of(" ", self.style),
      body,
      @strip.Strip::of(arrow, self.arrow_style),
    ])
  }
  if !self.expanded {
    return @strip.Strip::blank(size.width, self.style)
  }
  self.scroll_to_fit(size.height - 1)
  let index = self.offset + row - 1
  if index < 0 || index >= self.options.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let (text, _) = self.options[index]
  let label_style = if index == self.highlighted {
    if self.focused {
      self.highlight
    } else {
      self.blurred_highlight
    }
  } else if index == self.chosen {
    self.style
  } else {
    self.dim_style
  }
  let line = align_line(
    clip_to(text, size.width - 2),
    size.width - 2,
    Left,
    label_style,
  )
  @strip.Strip::join([@strip.Strip::of(" ", self.style), line]).pad_to(
    size.width,
    self.style,
  )
}

///|
pub impl Widget for Select with fn hint(self, size) {
  if !self.expanded {
    return @geom.Size::new(size.width, 1)
  }
  let rows = if self.options.length() < 12 { self.options.length() } else { 12 }
  @geom.Size::new(size.width, 1 + rows)
}

///|
pub impl Widget for Select with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      if !gained {
        self.expanded = false
        self.query = ""
      }
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        match key.code {
          Enter | Down | Up => {
            if !self.expanded {
              self.open(ctx)
              return true
            }
            if key.code == Up {
              self.move_highlight(self.highlighted - 1, ctx)
              return true
            }
            if key.code == Down {
              self.move_highlight(self.highlighted + 1, ctx)
              return true
            }
            self.choose(self.highlighted, ctx)
            return true
          }
          Escape =>
            if self.expanded {
              self.close(ctx)
              true
            } else {
              false
            }
          Char(32) => {
            if !self.expanded {
              self.open(ctx)
            }
            true
          }
          Char(code) =>
            if self.expanded {
              self.search(ctx, code)
              true
            } else {
              false
            }
          Home => {
            if self.expanded && self.options.length() > 0 {
              self.move_highlight(0, ctx)
            }
            true
          }
          End => {
            if self.expanded && self.options.length() > 0 {
              self.move_highlight(self.options.length() - 1, ctx)
            }
            true
          }
          PageUp => {
            if self.expanded {
              self.move_highlight(self.highlighted - self.page_step(), ctx)
            }
            true
          }
          PageDown => {
            if self.expanded {
              self.move_highlight(self.highlighted + self.page_step(), ctx)
            }
            true
          }
          _ => false
        }
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          if !self.expanded {
            self.open(ctx)
          } else if mouse.y == 0 {
            self.close(ctx)
          } else {
            let index = self.offset + mouse.y - 1
            if index >= 0 && index < self.options.length() {
              self.choose(index, ctx)
            }
          }
          true
        }
        ScrollUp =>
          if self.expanded {
            self.offset = self.offset - 1
            self.follow = false
            ctx.repaint()
            true
          } else {
            false
          }
        ScrollDown =>
          if self.expanded {
            self.offset = self.offset + 1
            self.follow = false
            ctx.repaint()
            true
          } else {
            false
          }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Select with fn focusable(_self) {
  true
}

///|
fn Select::page_step(self : Select) -> Int32 {
  if self.seen > 1 {
    self.seen - 1
  } else {
    1
  }
}

///|
fn Select::open(self : Select, ctx : Ctx) -> Unit {
  self.expanded = true
  self.query = ""
  self.highlighted = if self.chosen >= 0 { self.chosen } else { 0 }
  if self.options.length() > 0 && self.highlighted >= self.options.length() {
    self.highlighted = 0
  }
  self.follow = true
  ctx.repaint()
}

///|
fn Select::close(self : Select, ctx : Ctx) -> Unit {
  self.expanded = false
  self.query = ""
  ctx.repaint()
}

///|
fn Select::choose(self : Select, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 || index >= self.options.length() {
    self.close(ctx)
    return
  }
  if !self.allow_blank && index == self.chosen {
    self.close(ctx)
    return
  }
  self.chosen = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.emit(Changed(id=ctx.id, value=self.options[index].1))
  self.close(ctx)
}

///|
fn Select::move_highlight(self : Select, index : Int32, ctx : Ctx) -> Unit {
  if self.options.length() == 0 {
    return
  }
  let next = clamp(index, 0, self.options.length() - 1)
  if next == self.highlighted {
    return
  }
  self.highlighted = next
  self.follow = true
  ctx.repaint()
}

///|
fn Select::search(self : Select, ctx : Ctx, code : Int32) -> Unit {
  let mut text = self.query
  match code.to_char() {
    Some(c) => text = text + c.to_string()
    None => ()
  }
  self.query = text
  let needle = text.to_lower()
  let mut best = -1
  let mut best_at = -1
  for i in 0..<self.options.length() {
    let at = self.options[i].0.to_lower().find(needle)
    match at {
      Some(found) =>
        if best_at < 0 || found < best_at {
          best = i
          best_at = found
        }
      None => ()
    }
  }
  if best >= 0 {
    self.move_highlight(best, ctx)
  }
}

///|
/// Bring the highlight into view after it moves; otherwise leave the view
/// where the wheel put it, only kept within the options.
fn Select::scroll_to_fit(self : Select, height : Int32) -> Unit {
  self.seen = height
  if self.follow && self.highlighted >= 0 {
    if self.highlighted < self.offset {
      self.offset = self.highlighted
    } else if height > 0 && self.highlighted >= self.offset + height {
      self.offset = self.highlighted - height + 1
    }
    self.follow = false
  }
  let max = self.options.length() - height
  self.offset = clamp(self.offset, 0, if max < 0 { 0 } else { max })
}

///|
pub extend Select with Debug::{to_repr}

///|
pub extend Select with Eq::{not_equal, equal}

///|
pub extend Select with Widget::{focusable, handle, hint, render_line}
