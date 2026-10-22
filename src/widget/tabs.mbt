// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Tabs {
  mut labels : Array[String]
  mut disabled : Array[Bool]
  mut active : Int32
  mut focused : Bool
  style : @style.Style
  active_style : @style.Style
  bar_style : @style.Style
  bar_highlight : @style.Style
} derive(Eq, Debug)

///|
pub fn Tabs::new(
  labels~ : Array[String] = [],
  active~ : Int32 = 0,
  style~ : @style.Style = @style.Style::new(dim=true),
  active_style~ : @style.Style = @style.Style::new(),
  bar_style~ : @style.Style = @style.Style::new(dim=true),
  bar_highlight~ : @style.Style = @style.Style::new(reverse=true),
) -> Tabs {
  let tabs : Tabs = {
    labels: [],
    disabled: [],
    active: -1,
    focused: false,
    style,
    active_style,
    bar_style,
    bar_highlight,
  }
  tabs.set_labels(labels)
  tabs.activate(
    clamp(active, 0, if labels.length() == 0 { 0 } else { labels.length() - 1 }),
  )
  tabs
}

///|
pub fn Tabs::labels(self : Tabs) -> Array[String] {
  self.labels
}

///|
pub fn Tabs::set_labels(self : Tabs, labels : Array[String]) -> Unit {
  self.labels = labels
  let disabled : Array[Bool] = []
  for _ in labels {
    disabled.push(false)
  }
  self.disabled = disabled
  if self.active >= labels.length() {
    self.active = labels.length() - 1
  }
}

///|
pub fn Tabs::active(self : Tabs) -> Int32 {
  if self.active >= 0 && self.active < self.labels.length() {
    self.active
  } else {
    -1
  }
}

///|
pub fn Tabs::activate(self : Tabs, index : Int32) -> Unit {
  if index < 0 || index >= self.labels.length() {
    return
  }
  self.active = index
}

///|
pub fn Tabs::set_disabled(self : Tabs, index : Int32, disabled : Bool) -> Unit {
  if index < 0 || index >= self.disabled.length() {
    return
  }
  self.disabled[index] = disabled
  if disabled && index == self.active {
    self.active = self.next_enabled(index, 1)
  }
}

///|
pub impl Widget for Tabs with fn render_line(self, row, size) {
  if row == 0 {
    let segs : Array[@strip.Seg] = []
    for i in 0..<self.labels.length() {
      let style = if i == self.active {
        self.active_style
      } else if self.disabled[i] {
        @style.Style::new(dim=true)
      } else {
        self.style
      }
      segs.push(@strip.Seg::new(" ", self.style))
      segs.push(@strip.Seg::new(clip_to(self.labels[i], size.width), style))
      segs.push(@strip.Seg::new(" ", self.style))
    }
    return @strip.Strip::from_segs(segs).pad_to(size.width, self.style)
  }
  if row != 1 || size.width <= 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let (start, end) = self.active_range()
  let segs : Array[@strip.Seg] = []
  if start > 0 {
    segs.push(@strip.Seg::new(ruler(start), self.bar_style))
  }
  if end > start {
    segs.push(@strip.Seg::new(ruler(end - start), self.bar_highlight))
  }
  segs.push(@strip.Seg::new(ruler(size.width - end), self.bar_style))
  @strip.Strip::from_segs(segs)
}

///|
pub impl Widget for Tabs with fn hint(_self, size) {
  @geom.Size::new(size.width, 2)
}

///|
pub impl Widget for Tabs with fn handle(self, ctx, msg) {
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
        Left => {
          self.move_active(self.next_enabled(self.active, -1), ctx)
          true
        }
        Right => {
          self.move_active(self.next_enabled(self.active, 1), ctx)
          true
        }
        _ => false
      }
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let hit = self.tab_at(mouse.x)
          match hit {
            Some(index) =>
              if !self.disabled[index] {
                self.move_active(index, ctx)
              }
            None => ()
          }
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Tabs with fn focusable(_self) {
  true
}

///|
fn Tabs::move_active(self : Tabs, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 || index == self.active {
    return
  }
  self.active = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.repaint()
}

///|
fn Tabs::next_enabled(self : Tabs, from : Int32, direction : Int32) -> Int32 {
  let count = self.labels.length()
  if count == 0 {
    return -1
  }
  let mut probe = from + direction
  let mut steps = 0
  while steps < count {
    if probe < 0 {
      probe = count - 1
    } else if probe >= count {
      probe = 0
    }
    if !self.disabled[probe] {
      return probe
    }
    probe = probe + direction
    steps = steps + 1
  }
  -1
}

///|
fn Tabs::active_range(self : Tabs) -> (Int32, Int32) {
  let mut at = 0
  for i in 0..<self.labels.length() {
    let width = @strip.str_cells(self.labels[i]) + 2
    if i == self.active {
      return (at, at + width)
    }
    at = at + width
  }
  (0, 0)
}

///|
fn Tabs::tab_at(self : Tabs, x : Int32) -> Int32? {
  let mut at = 0
  for i in 0..<self.labels.length() {
    let width = @strip.str_cells(self.labels[i]) + 2
    if x < at + width {
      return Some(i)
    }
    at = at + width
  }
  None
}

///|
fn ruler(width : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<width {
    out.write_string("━")
  }
  out.to_string()
}

///|
pub extend Tabs with Debug::{to_repr}

///|
pub extend Tabs with Eq::{not_equal, equal}

///|
pub extend Tabs with Widget::{focusable, handle, hint, render_line}
