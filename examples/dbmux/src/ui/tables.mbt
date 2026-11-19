// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The table list, drawn from the state: one line per table, the one under the
/// cursor raised, and bright while the list has the keys. The pane takes every
/// key, so a list widget that waits for focus of its own would never light up.
priv struct Tables {
  state : @shell.State
  mut offset : Int32
}

///|
fn tables(state : @shell.State) -> &@widget.Widget {
  Tables::{ state, offset: 0, }
}

///|
impl @widget.Widget for Tables with fn render_line(self, row, size) {
  let state = self.state
  if state.tree_at < self.offset {
    self.offset = state.tree_at
  }
  if state.tree_at >= self.offset + size.height {
    self.offset = state.tree_at - size.height + 1
  }
  let at = self.offset + row
  if at < 0 || at >= state.tables.length() {
    return @strip.Strip::blank(size.width, body)
  }
  let info = state.tables[at]
  let name = match info.schema {
    Some(schema) => schema + "." + info.name
    None => info.name
  }
  let chosen = at == state.tree_at
  let style = if !chosen {
    body
  } else if state.focus is @shell.Focus::Tree {
    cursor
  } else {
    picked
  }
  let segs = [@strip.Seg::new(" " + name, style)]
  if info.is_view {
    segs.push(@strip.Seg::new("  view", if chosen { style } else { dim }))
  }
  @strip.Strip::from_segs(segs).crop(0, size.width).pad_to(size.width, style)
}

///|
impl @widget.Widget for Tables with fn hint(self, size) {
  @geom.Size::new(size.width, self.state.tables.length())
}

///|
impl @widget.Widget for Tables with fn handle(_self, _ctx, _msg) {
  false
}

///|
impl @widget.Widget for Tables with fn focusable(_self) {
  false
}
