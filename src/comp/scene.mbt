// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Placement {
  node : Int32
  rect : @geom.Region
  clip : @geom.Region
} derive(Eq, Debug)

///|
pub fn Placement::visible(self : Placement) -> @geom.Region {
  self.rect.intersection(self.clip)
}

///|
pub(all) struct Scene {
  size : @geom.Size
  items : Array[Placement]
} derive(Eq, Debug)

///|
pub fn Scene::new(size : @geom.Size) -> Scene {
  { size, items: [], }
}

///|
pub fn Scene::place(
  self : Scene,
  node : Int32,
  rect : @geom.Region,
  clip : @geom.Region,
) -> Unit {
  self.items.push({ node, rect, clip, })
}

///|
pub fn Scene::cuts(self : Scene, y : Int32) -> Array[Int32] {
  let marks : Array[Int32] = [0, self.size.width]
  for item in self.items {
    let area = item.visible()
    if area.is_empty() || y < area.y || y >= area.bottom() {
      continue
    }
    marks.push(clamp(area.x, 0, self.size.width))
    marks.push(clamp(area.right(), 0, self.size.width))
  }
  marks.sort()
  let out : Array[Int32] = []
  for mark in marks {
    if out.length() == 0 || out[out.length() - 1] != mark {
      out.push(mark)
    }
  }
  out
}

///|
/// One row of the screen: the first placement covering a column wins it, so
/// nothing is drawn twice and front items hide those behind them.
pub fn Scene::compose_line(
  self : Scene,
  y : Int32,
  render : (Int32, Int32) -> @strip.Strip,
  base : @style.Style,
) -> @strip.Strip {
  let marks = self.cuts(y)
  let parts : Array[@strip.Strip] = []
  let rendered : Map[Int32, @strip.Strip] = Map([])
  for i in 0..<(marks.length() - 1) {
    let from = marks[i]
    let to = marks[i + 1]
    if to <= from {
      continue
    }
    match self.owner(y, from) {
      None => parts.push(@strip.Strip::blank(to - from, base))
      Some(item) => {
        let line = match rendered.get(item.node) {
          Some(cached) => cached
          None => {
            let fresh = render(item.node, y - item.rect.y)
            rendered[item.node] = fresh
            fresh
          }
        }
        let piece = line
          .pad_to(item.rect.width, base)
          .crop(from - item.rect.x, to - item.rect.x)
        parts.push(piece.pad_to(to - from, base))
      }
    }
  }
  @strip.Strip::join(parts).simplify()
}

///|
pub fn Scene::compose(
  self : Scene,
  render : (Int32, Int32) -> @strip.Strip,
  base : @style.Style,
) -> Array[@strip.Strip] {
  let rows : Array[@strip.Strip] = []
  for y in 0..<self.size.height {
    rows.push(self.compose_line(y, render, base))
  }
  rows
}

///|
fn Scene::owner(self : Scene, y : Int32, x : Int32) -> Placement? {
  for item in self.items {
    let area = item.visible()
    if area.contains(x, y) {
      return Some(item)
    }
  }
  None
}

///|
fn clamp(value : Int32, low : Int32, high : Int32) -> Int32 {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
pub extend Placement with Debug::{to_repr}

///|
pub extend Placement with Eq::{not_equal, equal}

///|
pub extend Scene with Debug::{to_repr}

///|
pub extend Scene with Eq::{not_equal, equal}
