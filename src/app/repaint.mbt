// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// What the next frame has to draw. A widget that changed its own state asks
// for the rows it sits on; anything the host changes itself, or anything that
// moves the tree, wipes the frame and places it again.

///|
/// Draw the next frame whole. A host calls this after changing a widget behind
/// its back; a widget that answers a key asks for its own rows instead.
pub fn[D] App::refresh(self : App[D]) -> Unit {
  self.wipe()
}

///|
/// The next frame places the tree again and composes every row.
fn[D] App::wipe(self : App[D]) -> Unit {
  self.wiped = true
  self.layout = true
  self.dirty = true
}

///|
/// Compose again the rows the node sits on, on the placements the last frame
/// left behind. This is the cheap frame: a list that moved its cursor redraws
/// its own rows and leaves the rest of the screen as it stands.
pub fn[D] App::repaint(self : App[D], id : Int32) -> Unit {
  self.damage_node(id)
  self.dirty = true
}

///|
/// Compose again the rows a part of the screen covers, for a host that has no
/// node to name.
pub fn[D] App::repaint_region(self : App[D], region : @geom.Region) -> Unit {
  self.damage_region(region)
  self.dirty = true
}

///|
/// A node changed its look, so the tree is styled and placed again, and the
/// rows it was on and the rows it lands on are composed. Focus and hover take
/// this path: a rule may change a border, and a border moves its children.
fn[D] App::touch(self : App[D], id : Int32) -> Unit {
  self.layout = true
  self.damage_node(id)
  self.dirty = true
}

///|
fn[D] App::damage_node(self : App[D], id : Int32) -> Unit {
  match self.rects.get(id) {
    Some(rect) => self.damage_region(rect)
    None => self.wiped = true
  }
  if id == self.focus {
    // A focused widget is drawn in its own focus colour down to the last row,
    // so the rows it sits on go even when its box did not move.
    match self.bare.get(id) {
      Some(rect) => self.damage_region(rect)
      None => ()
    }
  }
}

///|
fn[D] App::damage_region(self : App[D], region : @geom.Region) -> Unit {
  if region.is_empty() {
    return
  }
  let height = self.size.height
  let top = int_max(0, region.y)
  let bottom = if region.bottom() > height { height } else { region.bottom() }
  for y in top..<bottom {
    self.damage_line(y)
  }
}

///|
fn[D] App::damage_line(self : App[D], y : Int32) -> Unit {
  if y < 0 || y >= self.size.height {
    return
  }
  self.damage.push(y)
}

///|
/// The rows to compose, each once and in order. A wiped frame composes all of
/// them and does not ask.
fn[D] App::damaged_rows(self : App[D]) -> Array[Int32] {
  if self.wiped {
    return []
  }
  let marks : Array[Int32] = []
  for y in self.damage {
    if y >= 0 && y < self.size.height {
      marks.push(y)
    }
  }
  marks.sort()
  let rows : Array[Int32] = []
  for y in marks {
    if rows.length() == 0 || rows[rows.length() - 1] != y {
      rows.push(y)
    }
  }
  rows
}
