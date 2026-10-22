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
  let at = self.tabs.active()
  if at < 0 || at >= self.panes.length() {
    return @strip.Strip::blank(size.width, self.tabs.style)
  }
  self.panes[at].render_line(row - 2, size)
}

///|
pub impl Widget for TabbedContent with fn hint(self, size) {
  let at = self.tabs.active()
  let mut height = 2
  if at >= 0 && at < self.panes.length() {
    let inner = self.panes[at].hint(size)
    if inner.height + 2 > height {
      height = inner.height + 2
    }
  }
  @geom.Size::new(size.width, height)
}

///|
pub impl Widget for TabbedContent with fn handle(self, ctx, msg) {
  self.tabs.handle(ctx, msg)
}

///|
pub impl Widget for TabbedContent with fn focusable(_self) {
  true
}

///|
pub extend TabbedContent with Widget::{focusable, handle, hint, render_line}
