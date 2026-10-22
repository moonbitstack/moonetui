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
pub(all) struct GridChild {
  col_span : Int32
  row_span : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub extend GridChild with Debug::{to_repr}

///|
pub extend GridChild with Eq::{not_equal, equal}

///|
pub fn GridChild::new(
  col_span~ : Int32 = 1,
  row_span~ : Int32 = 1,
  height~ : Int32 = 0,
) -> GridChild {
  { col_span, row_span, height, }
}

///|
/// The cell each child lands in, row-major over the first free block that
/// fits its spans. A `rows` of zero or less grows rows until every child
/// fits, which is how a grid without a row count grows.
pub fn grid_slots(
  kids : Array[GridChild],
  cols~ : Int32,
  rows~ : Int32 = 0,
) -> Array[(Int32, Int32)] {
  let cols = if cols < 1 { 1 } else { cols }
  let count = kids.length()
  let mut rows = if rows > 0 {
    rows
  } else if count == 0 {
    1
  } else {
    (count + cols - 1) / cols
  }
  if rows < 1 {
    rows = 1
  }
  let out : Array[(Int32, Int32)] = []
  let mut settled = false
  let mut rounds = 0
  while !settled && rounds <= count + 1 {
    rounds = rounds + 1
    let occ : Array[Array[Bool]] = []
    for _r in 0..<rows {
      let line : Array[Bool] = []
      for _c in 0..<cols {
        line.push(false)
      }
      occ.push(line)
    }
    out.clear()
    settled = true
    for kid in kids {
      let cs = at_least_one(kid.col_span)
      let rs = at_least_one(kid.row_span)
      let mut found : (Int32, Int32)? = None
      let top = rows - rs + 1
      if top > 0 {
        for r in 0..<top {
          if found != None {
            break
          }
          let across = cols - cs + 1
          if across > 0 {
            for c in 0..<across {
              if cell_free(occ, r, c, rs, cs) {
                found = Some((r, c))
                break
              }
            }
          }
        }
      }
      match found {
        Some((r, c)) => {
          for dr in 0..<rs {
            for dc in 0..<cs {
              occ[r + dr][c + dc] = true
            }
          }
          out.push((r, c))
        }
        None => {
          rows = rows + 1
          settled = false
          break
        }
      }
    }
  }
  out
}

///|
fn cell_free(
  occ : Array[Array[Bool]],
  row : Int32,
  col : Int32,
  rows : Int32,
  cols : Int32,
) -> Bool {
  for r in 0..<rows {
    for c in 0..<cols {
      if occ[row + r][col + c] {
        return false
      }
    }
  }
  true
}

///|
/// What each row of the grid asks for: the tallest child that touches it,
/// counting a spanning child's height once per row it covers.
pub fn grid_row_heights(
  kids : Array[GridChild],
  slots : Array[(Int32, Int32)],
) -> Array[Int32] {
  let mut nrows = 1
  for i in 0..<kids.length() {
    let (r, _) = slots[i]
    let rs = at_least_one(kids[i].row_span)
    if r + rs > nrows {
      nrows = r + rs
    }
  }
  let heights = Array::make(nrows, 0)
  for i in 0..<kids.length() {
    let (r, _) = slots[i]
    let rs = at_least_one(kids[i].row_span)
    let share = (at_least_zero(kids[i].height) + rs - 1) / rs
    for k in 0..<rs {
      if share > heights[r + k] {
        heights[r + k] = share
      }
    }
  }
  heights
}

///|
/// Regions for the slots `grid_slots` handed out: equal columns, rows tall
/// enough for their content with the leftover shared out evenly, gutters
/// between cells.
pub fn arrange_grid(
  area : @geom.Region,
  slots : Array[(Int32, Int32)],
  kids : Array[GridChild],
  cols~ : Int32,
  gutter~ : Int32 = 0,
) -> Array[@geom.Region] {
  let cols = at_least_one(cols)
  let out : Array[@geom.Region] = []
  let heights = grid_row_heights(kids, slots)
  let nrows = heights.length()
  let gut_w = gutter * (cols - 1)
  let col_w = if area.width > gut_w { (area.width - gut_w) / cols } else { 0 }
  let mut total = gutter * (nrows - 1)
  for h in heights {
    total = total + h
  }
  let slack = area.height - total
  let extra = if slack > 0 { slack / nrows } else { 0 }
  let mut rem = if slack > 0 { slack % nrows } else { 0 }
  let row_y : Array[Int32] = []
  let row_h : Array[Int32] = []
  let mut y = area.y
  for r in 0..<nrows {
    let mut h = heights[r] + extra
    if rem > 0 {
      h = h + 1
      rem = rem - 1
    }
    row_y.push(y)
    row_h.push(h)
    y = y + h + gutter
  }
  for i in 0..<kids.length() {
    let (r, c) = slots[i]
    let cs = at_least_one(kids[i].col_span)
    let rs = at_least_one(kids[i].row_span)
    let mut h = (rs - 1) * gutter
    for k in 0..<rs {
      h = h + row_h[r + k]
    }
    let rect = @geom.Region::new(
      area.x + c * (col_w + gutter),
      row_y[r],
      cs * col_w + (cs - 1) * gutter,
      h,
    )
    out.push(rect.intersection(area))
  }
  out
}

///|
fn at_least_one(value : Int32) -> Int32 {
  if value < 1 {
    1
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
