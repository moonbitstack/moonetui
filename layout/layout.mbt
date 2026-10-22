// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum Extent {
  Auto
  Cells(Int32)
  Frac(Int32)
  Pct(Int32)
} derive(Eq, Debug)

///|
/// A `max` of -1 means unbounded, which no real limit can be confused with.
pub(all) struct Box {
  extent : Extent
  min : Int32
  max : Int32
  pad : @geom.Spacing
} derive(Eq, Debug)

///|
pub fn Box::new(
  extent~ : Extent = Auto,
  min~ : Int32 = 0,
  max~ : Int32 = -1,
  pad~ : @geom.Spacing = { top: 0, right: 0, bottom: 0, left: 0, },
) -> Box {
  { extent, min, max, pad, }
}

///|
pub(all) enum Dir {
  Vertical
  Horizontal
} derive(Eq, Debug)

///|
pub fn arrange(
  area : @geom.Region,
  dir : Dir,
  boxes : Array[Box],
  content : Array[Int32],
  gap~ : Int32 = 0,
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
fn solve(
  boxes : Array[Box],
  content : Array[Int32],
  space : Int32,
) -> Array[Int32] {
  let count = boxes.length()
  let sizes : Array[Int32] = []
  let flexible : Array[Bool] = []
  let shares : Array[Int32] = []
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
    let want : Array[Int32] = []
    let remainders : Array[Int32] = []
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
fn clamp_box(box : Box, value : Int32) -> Int32 {
  let low = at_least_zero(box.min)
  let mut size = if value < low { low } else { value }
  if box.max >= 0 && size > box.max {
    size = box.max
  }
  at_least_zero(size)
}

///|
pub fn main_of(size : @geom.Size, dir : Dir) -> Int32 {
  match dir {
    Vertical => size.height
    Horizontal => size.width
  }
}

///|
pub fn cross_of(size : @geom.Size, dir : Dir) -> Int32 {
  match dir {
    Vertical => size.width
    Horizontal => size.height
  }
}

///|
fn at_least_zero(value : Int32) -> Int32 {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
pub extend Box with Debug::{to_repr}

///|
pub extend Box with Eq::{not_equal, equal}

///|
pub extend Dir with Debug::{to_repr}

///|
pub extend Dir with Eq::{not_equal, equal}

///|
pub extend Extent with Debug::{to_repr}

///|
pub extend Extent with Eq::{not_equal, equal}
