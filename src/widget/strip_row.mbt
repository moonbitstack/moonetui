// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A row drawn by a function of its width and read again on every frame: how a
/// screen mounts a band, a key bar or a rule as a node of its own, so the row
/// follows the size it is given instead of the size it was built at.
pub struct StripRow {
  draw : (Int32) -> @strip.Strip
}

///|
pub fn StripRow::new(draw : (Int32) -> @strip.Strip) -> StripRow {
  { draw, }
}

///|
pub impl Widget for StripRow with fn render_line(self, _row, size) {
  (self.draw)(size.width)
}

///|
pub impl Widget for StripRow with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for StripRow with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for StripRow with fn focusable(_self) {
  false
}

///|
pub extend StripRow with Widget::{focusable, handle, hint, render_line}
