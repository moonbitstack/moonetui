// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Several widgets in one place, one showing at a time: what a screen puts
/// where the same space holds different content.
///
/// The one showing is drawn, measured, given the input and asked whether it
/// takes focus, so the switcher is invisible to everything around it.
pub struct ContentSwitcher {
  children : Array[&Widget]
  mut current : Int32
  mut focused : Bool
}

///|
pub fn ContentSwitcher::new(
  children~ : Array[&Widget] = [],
  current~ : Int32 = 0,
) -> ContentSwitcher {
  let switcher : ContentSwitcher = { children, current: 0, focused: false, }
  switcher.switch_to(current)
  switcher
}

///|
pub fn ContentSwitcher::add(self : ContentSwitcher, child : &Widget) -> Unit {
  self.children.push(child)
  if self.current < 0 {
    self.current = 0
  }
}

///|
/// Which one is showing.
pub fn ContentSwitcher::current(self : ContentSwitcher) -> Int32 {
  if self.children.length() == 0 {
    -1
  } else {
    self.current
  }
}

///|
/// Put another one in its place, held to the ones there are.
pub fn ContentSwitcher::switch_to(
  self : ContentSwitcher,
  index : Int32,
) -> Unit {
  if self.children.length() == 0 {
    self.current = 0
    return
  }
  let next = constrain(index, 0, self.children.length() - 1)
  if next == self.current {
    return
  }
  self.current = next
}

///|
pub fn ContentSwitcher::count(self : ContentSwitcher) -> Int32 {
  self.children.length()
}

///|
fn ContentSwitcher::showing(self : ContentSwitcher) -> &Widget? {
  if self.current < 0 || self.current >= self.children.length() {
    None
  } else {
    Some(self.children[self.current])
  }
}

///|
pub impl Widget for ContentSwitcher with fn render_line(self, row, size) {
  match self.showing() {
    None => @strip.Strip::blank(size.width, @style.default)
    Some(child) => child.render_line(row, size)
  }
}

///|
pub impl Widget for ContentSwitcher with fn hint(self, size) {
  match self.showing() {
    None => @geom.Size::new(size.width, 0)
    Some(child) => child.hint(size)
  }
}

///|
pub impl Widget for ContentSwitcher with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      match self.showing() {
        None => ()
        Some(child) => forward(child, ctx, ctx.size, msg) |> ignore
      }
      ctx.repaint()
      true
    }
    _ =>
      match self.showing() {
        None => false
        Some(child) => forward(child, ctx, ctx.size, msg)
      }
  }
}

///|
pub impl Widget for ContentSwitcher with fn focusable(self) {
  match self.showing() {
    None => false
    Some(child) => child.focusable()
  }
}

///|
pub extend ContentSwitcher with Widget::{focusable, handle, hint, render_line}
