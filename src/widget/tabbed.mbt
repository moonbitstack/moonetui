// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct TabbedContent {
  tabs : Tabs
  panes : Array[&Widget]
}

///|
pub fn TabbedContent::new(
  labels~ : Array[String] = [],
  panes~ : Array[&Widget] = [],
  active~ : Int32 = 0,
) -> TabbedContent {
  { tabs: Tabs::new(labels~, active~), panes, }
}

///|
pub fn TabbedContent::active(self : TabbedContent) -> Int32 {
  self.tabs.active()
}

///|
pub fn TabbedContent::activate(self : TabbedContent, index : Int32) -> Unit {
  self.tabs.activate(index)
}

///|
pub fn TabbedContent::set_disabled(
  self : TabbedContent,
  index : Int32,
  disabled : Bool,
) -> Unit {
  self.tabs.set_disabled(index, disabled)
}

///|
pub impl Widget for TabbedContent with fn render_line(self, row, size) {
  if row < 2 {
    return self.tabs.render_line(row, size)
  }
  match self.pane() {
    Some(pane) => pane.render_line(row - 2, pane_size(size))
    None => @strip.Strip::blank(size.width, self.tabs.style)
  }
}

///|
pub impl Widget for TabbedContent with fn hint(self, size) {
  let below = match self.pane() {
    Some(pane) => pane.hint(pane_size(size)).height
    None => 0
  }
  @geom.Size::new(size.width, below + 2)
}

///|
/// Keys go to the pane first and switch tabs only when it passes them on; the
/// pointer goes to whichever of the two it is over.
pub impl Widget for TabbedContent with fn handle(self, ctx, msg) {
  match msg {
    Focus(_) => {
      self.tabs.handle(ctx, msg) |> ignore
      self.to_pane(ctx, msg) |> ignore
      true
    }
    Mouse(mouse) if mouse.y >= 2 =>
      self.to_pane(ctx, Mouse({ ..mouse, y: mouse.y - 2, }))
    Key(_) | Paste(_) => self.to_pane(ctx, msg) || self.to_tabs(ctx, msg)
    _ => self.to_tabs(ctx, msg)
  }
}

///|
pub impl Widget for TabbedContent with fn focusable(_self) {
  true
}

///|
fn TabbedContent::pane(self : TabbedContent) -> &Widget? {
  let at = self.tabs.active()
  if at >= 0 && at < self.panes.length() {
    Some(self.panes[at])
  } else {
    None
  }
}

///|
fn TabbedContent::to_pane(self : TabbedContent, ctx : Ctx, msg : Msg) -> Bool {
  match self.pane() {
    Some(pane) => forward(pane, ctx, pane_size(ctx.size), msg)
    None => false
  }
}

///|
/// Let the tab bar handle `msg`; if that switched tabs while focused, the
/// focus moves from the old pane to the new one.
fn TabbedContent::to_tabs(self : TabbedContent, ctx : Ctx, msg : Msg) -> Bool {
  let before = self.pane()
  let was = self.tabs.active()
  let handled = self.tabs.handle(ctx, msg)
  if self.tabs.focused && self.tabs.active() != was {
    if before is Some(old) {
      forward(old, ctx, pane_size(ctx.size), Focus(false)) |> ignore
    }
    if self.pane() is Some(new) {
      forward(new, ctx, pane_size(ctx.size), Focus(true)) |> ignore
    }
  }
  handled
}

///|
fn pane_size(size : @geom.Size) -> @geom.Size {
  @geom.Size::new(size.width, size.height - 2)
}

///|
pub extend TabbedContent with Widget::{focusable, handle, hint, render_line}
