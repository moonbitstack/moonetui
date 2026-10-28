// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Words that go somewhere: underlined, taken by Enter or by a click, and
/// drawn differently once they have been.
pub struct Link {
  mut text : String
  mut target : String
  mut visited : Bool
  mut focused : Bool
  style : @style.Style
  visited_style : @style.Style
  focus_style : @style.Style
}

///|
/// A link to `target`, or to what it says when no target is given.
pub fn Link::new(
  text : String,
  target~ : String = "",
  style~ : @style.Style = @style.Style::new(underline=true),
  visited_style~ : @style.Style = @style.Style::new(underline=true, dim=true),
  focus_style~ : @style.Style = @style.Style::new(underline=true, reverse=true),
) -> Link {
  {
    text,
    target: if target.length() > 0 {
      target
    } else {
      text
    },
    visited: false,
    focused: false,
    style,
    visited_style,
    focus_style,
  }
}

///|
pub fn Link::text(self : Link) -> String {
  self.text
}

///|
pub fn Link::set(self : Link, text : String) -> Unit {
  self.text = text
}

///|
/// Where the link goes.
pub fn Link::target(self : Link) -> String {
  self.target
}

///|
pub fn Link::set_target(self : Link, target : String) -> Unit {
  self.target = target
}

///|
pub fn Link::is_visited(self : Link) -> Bool {
  self.visited
}

///|
/// Mark the link as gone to, or forget that it was.
pub fn Link::visit(self : Link, visited~ : Bool = true) -> Unit {
  self.visited = visited
}

///|
pub impl Widget for Link with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let ink = if self.focused {
    self.focus_style
  } else if self.visited {
    self.visited_style
  } else {
    self.style
  }
  @strip.Strip::of(clip_to(self.text, size.width), ink).pad_to(size.width, ink)
}

///|
pub impl Widget for Link with fn hint(self, size) {
  let cells = @strip.str_cells(self.text)
  @geom.Size::new(if cells < size.width { cells } else { size.width }, 1)
}

///|
pub impl Widget for Link with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() && key.code == Enter {
        self.go(ctx)
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          self.go(ctx)
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Link with fn focusable(_self) {
  true
}

///|
/// Go there: the link is marked as gone to and the id is reported both as a
/// press and as a choice, so a caller can answer either.
fn Link::go(self : Link, ctx : Ctx) -> Bool {
  self.visited = true
  ctx.emit(Pressed(id=ctx.id))
  ctx.emit(Selected(id=ctx.id, index=0))
  ctx.repaint()
  true
}

///|
pub extend Link with Widget::{focusable, handle, hint, render_line}
