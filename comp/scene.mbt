// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Where one widget sits on the screen. `clip` is the region it is allowed to
/// draw in — usually its container's — so a widget that scrolls out of its
/// parent simply stops being asked for lines.
pub(all) struct Placement {
  node : Int
  rect : @geom.Region
  clip : @geom.Region
} derive(Eq, Debug)

///|
/// The visible area of that placement: what it covers after clipping.
pub fn Placement::visible(self : Placement) -> @geom.Region {
  self.rect.intersection(self.clip)
}

///|
/// Everything on the screen, front to back. The first placement that covers a
/// column wins it, which is how one widget hides another without anything being
/// drawn twice.
pub(all) struct Scene {
  size : @geom.Size
  items : Array[Placement]
} derive(Eq, Debug)

///|
/// A screen with nothing on it.
pub fn Scene::new(size : @geom.Size) -> Scene {
  { size, items: [], }
}

///|
/// Add a placement behind everything already added.
pub fn Scene::place(
  self : Scene,
  node : Int,
  rect : @geom.Region,
  clip : @geom.Region,
) -> Unit {
  self.items.push({ node, rect, clip, })
}

///|
/// The column boundaries on one row: zero, the screen width, and every visible
/// edge in between, sorted and deduplicated. Composing a row means filling the
/// pieces between consecutive boundaries, and cutting at every edge means no
/// piece ever straddles two widgets.
pub fn Scene::cuts(self : Scene, y : Int) -> Array[Int] {
  let marks : Array[Int] = [0, self.size.width]
  for item in self.items {
    let area = item.visible()
    if area.is_empty() || y < area.y || y >= area.bottom() {
      continue
    }
    marks.push(clamp(area.x, 0, self.size.width))
    marks.push(clamp(area.right(), 0, self.size.width))
  }
  marks.sort()
  let out : Array[Int] = []
  for mark in marks {
    if out.length() == 0 || out[out.length() - 1] != mark {
      out.push(mark)
    }
  }
  out
}

///|
/// Compose one row.
///
/// `render(node, line)` gives the widget's own line, in its own coordinates and
/// its full width; the compositor crops it to the piece the widget actually
/// owns. Uncovered pieces become blanks in `base`.
pub fn Scene::compose_line(
  self : Scene,
  y : Int,
  render : (Int, Int) -> @strip.Strip,
  base : @style.Style,
) -> @strip.Strip {
  let marks = self.cuts(y)
  let parts : Array[@strip.Strip] = []
  let rendered : Map[Int, @strip.Strip] = Map([])
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
        // The widget drew in its own coordinates, so the piece it owns starts
        // at the offset of this cut inside the widget.
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
/// Compose every row of the screen.
pub fn Scene::compose(
  self : Scene,
  render : (Int, Int) -> @strip.Strip,
  base : @style.Style,
) -> Array[@strip.Strip] {
  let rows : Array[@strip.Strip] = []
  for y in 0..<self.size.height {
    rows.push(self.compose_line(y, render, base))
  }
  rows
}

///|
/// The front-most placement covering this column, if any.
fn Scene::owner(self : Scene, y : Int, x : Int) -> Placement? {
  for item in self.items {
    let area = item.visible()
    if area.contains(x, y) {
      return Some(item)
    }
  }
  None
}

///|
fn clamp(value : Int, low : Int, high : Int) -> Int {
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
