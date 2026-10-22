// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Collapsible {
  mut title : String
  mut collapsed : Bool
  collapsed_symbol : String
  expanded_symbol : String
  contents : &Widget
  mut focused : Bool
  mut hover : Bool
  bar_style : @style.Style
  title_style : @style.Style
  hover_style : @style.Style
  focus_style : @style.Style
  style : @style.Style
}

///|
pub fn Collapsible::new(
  title~ : String,
  contents~ : &Widget,
  collapsed~ : Bool = true,
  collapsed_symbol~ : String = "▶",
  expanded_symbol~ : String = "▼",
  bar_style~ : @style.Style = @style.Style::new(dim=true),
  title_style~ : @style.Style = @style.Style::new(),
  hover_style~ : @style.Style = @style.Style::new(reverse=true),
  focus_style~ : @style.Style = @style.Style::new(reverse=true),
  style~ : @style.Style = @style.Style::new(dim=true),
) -> Collapsible {
  {
    title,
    collapsed,
    collapsed_symbol,
    expanded_symbol,
    contents,
    focused: false,
    hover: false,
    bar_style,
    title_style,
    hover_style,
    focus_style,
    style,
  }
}

///|
pub fn Collapsible::title(self : Collapsible) -> String {
  self.title
}

///|
pub fn Collapsible::set_title(self : Collapsible, title : String) -> Unit {
  self.title = title
}

///|
pub fn Collapsible::is_collapsed(self : Collapsible) -> Bool {
  self.collapsed
}

///|
pub fn Collapsible::set_collapsed(self : Collapsible, collapsed : Bool) -> Unit {
  self.collapsed = collapsed
}

///|
pub impl Widget for Collapsible with fn render_line(self, row, size) {
  if row == 0 {
    return @strip.Strip::of(hkey(size.width), self.bar_style)
  }
  if row == 1 {
    let symbol = if self.collapsed {
      self.collapsed_symbol
    } else {
      self.expanded_symbol
    }
    let style = if self.focused {
      self.focus_style
    } else if self.hover {
      self.hover_style
    } else {
      self.title_style
    }
    let segs : Array[@strip.Seg] = []
    segs.push(@strip.Seg::new(" ", self.title_style))
    segs.push(@strip.Seg::new(symbol, style))
    segs.push(@strip.Seg::new(" ", self.title_style))
    segs.push(
      @strip.Seg::new(
        clip_to(self.title, if size.width > 4 { size.width - 4 } else { 0 }),
        style,
      ),
    )
    return @strip.Strip::from_segs(segs).pad_to(size.width, self.style)
  }
  if self.collapsed {
    return @strip.Strip::blank(size.width, self.style)
  }
  if row == 2 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let inner_width = if size.width > 3 { size.width - 3 } else { 0 }
  let inner = self.contents.render_line(row - 3, collapsible_inner_size(size))
  let segs : Array[@strip.Seg] = [@strip.Seg::new("   ", self.style)]
  for seg in inner.crop(0, inner_width).segs {
    segs.push(seg)
  }
  @strip.Strip::from_segs(segs).pad_to(size.width, self.style)
}

///|
pub impl Widget for Collapsible with fn hint(self, size) {
  if self.collapsed {
    return @geom.Size::new(size.width, 3)
  }
  let inner = self.contents.hint(collapsible_inner_size(size))
  @geom.Size::new(size.width, inner.height + 4)
}

///|
pub impl Widget for Collapsible with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => {
      if key.code == Enter && key.mods.is_none() {
        self.toggle(ctx)
        return true
      }
      if self.collapsed {
        return false
      }
      self.contents.handle(ctx, msg)
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          if mouse.y == 1 {
            ctx.emit(TakeFocus(id=ctx.id))
            self.toggle(ctx)
            return true
          }
          if !self.collapsed && mouse.y >= 3 {
            return self.contents.handle(ctx, Mouse(collapsible_shift(mouse)))
          }
          false
        }
        Move => {
          let over = mouse.y == 1
          if over != self.hover {
            self.hover = over
            ctx.repaint()
          }
          if !self.collapsed && mouse.y >= 3 {
            return self.contents.handle(ctx, Mouse(collapsible_shift(mouse)))
          }
          true
        }
        ScrollUp | ScrollDown => {
          if !self.collapsed && mouse.y >= 3 {
            return self.contents.handle(ctx, Mouse(collapsible_shift(mouse)))
          }
          false
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Collapsible with fn focusable(_self) {
  true
}

///|
fn Collapsible::toggle(self : Collapsible, ctx : Ctx) -> Unit {
  self.collapsed = !self.collapsed
  ctx.emit(Toggled(id=ctx.id, on=!self.collapsed))
  ctx.repaint()
}

///|
fn collapsible_inner_size(size : @geom.Size) -> @geom.Size {
  let width = if size.width > 3 { size.width - 3 } else { 0 }
  let height = if size.height > 4 { size.height - 4 } else { 0 }
  @geom.Size::new(width, height)
}

///|
fn collapsible_shift(mouse : @event.Mouse) -> @event.Mouse {
  { ..mouse, x: mouse.x - 3, y: mouse.y - 3, }
}

///|
fn hkey(width : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<width {
    out.write_string("─")
  }
  out.to_string()
}

///|
pub extend Collapsible with Widget::{focusable, handle, hint, render_line}
