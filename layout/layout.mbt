// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// How much of the main axis a box asks for.
pub(all) enum Extent {
  /// As much as the content needs.
  Auto
  /// Exactly this many cells.
  Cells(Int)
  /// This many shares of whatever is left after the fixed boxes have taken
  /// theirs.
  Frac(Int)
  /// This percentage of the container, rounded down.
  Pct(Int)
} derive(Eq, Debug)

///|
/// What a box asks for. `max` of -1 means unbounded, which is the only value
/// that cannot be confused with a real limit of zero.
pub(all) struct Box {
  extent : Extent
  min : Int
  max : Int
  pad : @geom.Spacing
} derive(Eq, Debug)

///|
/// A box with the defaults: automatic size, no limits, no padding.
pub fn Box::new(
  extent? : Extent = Auto,
  min? : Int = 0,
  max? : Int = -1,
  pad? : @geom.Spacing = { top: 0, right: 0, bottom: 0, left: 0, },
) -> Box {
  { extent, min, max, pad, }
}

///|
/// Which way boxes are stacked.
pub(all) enum Dir {
  Vertical
  Horizontal
} derive(Eq, Debug)

///|
/// Place boxes along the main axis of `area`.
///
/// `content[i]` is what box `i` would like along that axis, which only matters
/// for an automatic extent. Each box fills the cross axis. The returned regions
/// are in the same order as the boxes, already shrunk by their padding, and
/// clipped to `area` — a box pushed off the end comes back empty rather than
/// out of bounds.
pub fn arrange(
  area : @geom.Region,
  dir : Dir,
  boxes : Array[Box],
  content : Array[Int],
  gap? : Int = 0,
) -> Array[@geom.Region] {
  let count = boxes.length()
  let out : Array[@geom.Region] = []
  if count == 0 {
    return out
  }
  let main_total = main_of(area.size(), dir)
  let cross_total = cross_of(area.size(), dir)
  let gaps = gap * (count - 1)
  let space = at_least_zero(main_total - gaps)
  let sizes = solve(boxes, content, space)
  let mut offset = 0
  for i in 0..<count {
    let size = sizes[i]
    let rect = match dir {
      Vertical => @geom.Region::new(area.x, area.y + offset, cross_total, size)
      Horizontal =>
        @geom.Region::new(area.x + offset, area.y, size, cross_total)
    }
    out.push(boxes[i].pad.shrink_region(rect).intersection(area))
    offset = offset + size + gap
  }
  out
}

///|
/// Split the available space between the boxes.
///
/// Fixed sizes are taken first; what is left is shared out by the fractional
/// boxes. A box whose share would break its own limits is pinned there and the
/// division runs again without it, because pinning it changes what the others
/// are entitled to.
fn solve(boxes : Array[Box], content : Array[Int], space : Int) -> Array[Int] {
  let count = boxes.length()
  let sizes : Array[Int] = []
  let flexible : Array[Bool] = []
  let shares : Array[Int] = []
  let mut fixed_total = 0
  let mut share_total = 0
  for i in 0..<count {
    let box = boxes[i]
    match box.extent {
      Frac(share) => {
        let weight = if share < 0 { 0 } else { share }
        sizes.push(0)
        flexible.push(true)
        shares.push(weight)
        share_total = share_total + weight
      }
      _ => {
        let asked = match box.extent {
          Cells(n) => n
          Pct(p) => space * p / 100
          _ => if i < content.length() { content[i] } else { 0 }
        }
        let size = clamp_box(box, asked)
        sizes.push(size)
        flexible.push(false)
        shares.push(0)
        fixed_total = fixed_total + size
      }
    }
  }
  let mut pool = at_least_zero(space - fixed_total)
  let mut weight = share_total
  let mut again = true
  while again {
    again = false
    if weight <= 0 {
      break
    }
    // Largest remainder: hand out the whole part of every share, then give the
    // leftover cells to the boxes with the largest fractions, so the parts add
    // up to the pool exactly.
    let want : Array[Int] = []
    let remainders : Array[Int] = []
    let mut handed = 0
    for i in 0..<count {
      if flexible[i] {
        let exact = pool * shares[i]
        let whole = exact / weight
        want.push(whole)
        remainders.push(exact % weight)
        handed = handed + whole
      } else {
        want.push(0)
        remainders.push(-1)
      }
    }
    let mut left = pool - handed
    while left > 0 {
      let mut best = -1
      for i in 0..<count {
        if remainders[i] >= 0 && (best < 0 || remainders[i] > remainders[best]) {
          best = i
        }
      }
      if best < 0 {
        break
      }
      want[best] = want[best] + 1
      remainders[best] = -1
      left = left - 1
    }
    for i in 0..<count {
      if !flexible[i] {
        continue
      }
      let pinned = clamp_box(boxes[i], want[i])
      if pinned != want[i] {
        sizes[i] = pinned
        flexible[i] = false
        pool = at_least_zero(pool - pinned)
        weight = weight - shares[i]
        again = true
        break
      }
      sizes[i] = want[i]
    }
  }
  sizes
}

///|
fn clamp_box(box : Box, value : Int) -> Int {
  let low = at_least_zero(box.min)
  let mut size = if value < low { low } else { value }
  if box.max >= 0 && size > box.max {
    size = box.max
  }
  at_least_zero(size)
}

///|
/// The extent along the stacking axis.
pub fn main_of(size : @geom.Size, dir : Dir) -> Int {
  match dir {
    Vertical => size.height
    Horizontal => size.width
  }
}

///|
/// The extent across the stacking axis.
pub fn cross_of(size : @geom.Size, dir : Dir) -> Int {
  match dir {
    Vertical => size.width
    Horizontal => size.height
  }
}

///|
fn at_least_zero(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}
