// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A point, in cells, relative to whatever origin the caller has in mind.
pub(all) struct Offset {
  x : Int
  y : Int
} derive(Eq, Debug)

///|
/// The zero offset — the top-left corner of the coordinate space.
pub let origin : Offset = { x: 0, y: 0, }

///|
/// True when this is the top-left corner.
pub fn Offset::is_origin(self : Offset) -> Bool {
  self.x == 0 && self.y == 0
}

///|
/// Swap the axes. A horizontal layout is implemented by transposing into the
/// vertical case and transposing the result back.
pub fn Offset::transpose(self : Offset) -> Offset {
  { x: self.y, y: self.x, }
}

///|
pub impl Add for Offset with fn add(self, other) {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
pub impl Sub for Offset with fn sub(self, other) {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
pub impl Neg for Offset with fn neg(self) {
  { x: -self.x, y: -self.y, }
}

///|
/// Scale both axes by the same whole factor.
pub fn Offset::scale(self : Offset, factor : Int) -> Offset {
  { x: self.x * factor, y: self.y * factor, }
}

///|
/// A width and a height, in cells.
pub(all) struct Size {
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// Build a size, clamping negative extents to zero.
pub fn Size::new(width : Int, height : Int) -> Size {
  { width: at_least_zero(width), height: at_least_zero(height), }
}

///|
/// The number of cells this size covers.
pub fn Size::area(self : Size) -> Int {
  self.width * self.height
}

///|
/// True when the size covers no cells at all.
pub fn Size::is_empty(self : Size) -> Bool {
  self.width == 0 || self.height == 0
}

///|
/// This size as a region anchored at the origin.
pub fn Size::region(self : Size) -> Region {
  { x: 0, y: 0, width: self.width, height: self.height, }
}

///|
/// True when the coordinate falls inside a region of this size anchored at the
/// origin.
pub fn Size::contains(self : Size, x : Int, y : Int) -> Bool {
  x >= 0 && x < self.width && y >= 0 && y < self.height
}

///|
/// Pull an offset back inside this size. A zero-extent axis clamps to zero.
pub fn Size::clamp_offset(self : Size, offset : Offset) -> Offset {
  {
    x: clamp(offset.x, 0, at_least_zero(self.width - 1)),
    y: clamp(offset.y, 0, at_least_zero(self.height - 1)),
  }
}

///|
/// A rectangle in cell coordinates: a top-left corner plus extents.
pub(all) struct Region {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// Build a region, clamping negative extents to zero.
pub fn Region::new(x : Int, y : Int, width : Int, height : Int) -> Region {
  { x, y, width: at_least_zero(width), height: at_least_zero(height), }
}

///|
/// The region spanned by two corners, given in either order.
pub fn Region::from_corners(x1 : Int, y1 : Int, x2 : Int, y2 : Int) -> Region {
  let left = if x1 < x2 { x1 } else { x2 }
  let top = if y1 < y2 { y1 } else { y2 }
  let right = if x1 < x2 { x2 } else { x1 }
  let bottom = if y1 < y2 { y2 } else { y1 }
  { x: left, y: top, width: right - left, height: bottom - top, }
}

///|
/// The top-left corner.
pub fn Region::offset(self : Region) -> Offset {
  { x: self.x, y: self.y, }
}

///|
/// The extents.
pub fn Region::size(self : Region) -> Size {
  { width: self.width, height: self.height, }
}

///|
/// The first column past the right edge.
pub fn Region::right(self : Region) -> Int {
  self.x + self.width
}

///|
/// The first row past the bottom edge.
pub fn Region::bottom(self : Region) -> Int {
  self.y + self.height
}

///|
/// The number of cells covered.
pub fn Region::area(self : Region) -> Int {
  self.width * self.height
}

///|
/// True when the region covers no cells.
pub fn Region::is_empty(self : Region) -> Bool {
  self.width == 0 || self.height == 0
}

///|
/// Move the region without resizing it.
pub fn Region::translate(self : Region, offset : Offset) -> Region {
  let moved = self.offset() + offset
  { ..self, x: moved.x, y: moved.y, }
}

///|
/// True when the cell at these coordinates is inside the region.
pub fn Region::contains(self : Region, x : Int, y : Int) -> Bool {
  x >= self.x && x < self.right() && y >= self.y && y < self.bottom()
}

///|
/// True when `other` lies entirely inside this region.
pub fn Region::contains_region(self : Region, other : Region) -> Bool {
  other.x >= self.x &&
  other.y >= self.y &&
  other.right() <= self.right() &&
  other.bottom() <= self.bottom()
}

///|
/// True when the two regions share at least one cell.
pub fn Region::overlaps(self : Region, other : Region) -> Bool {
  !self.intersection(other).is_empty()
}

///|
/// The cells common to both regions, empty when they do not overlap.
pub fn Region::intersection(self : Region, other : Region) -> Region {
  let left = if self.x > other.x { self.x } else { other.x }
  let top = if self.y > other.y { self.y } else { other.y }
  let right = if self.right() < other.right() {
    self.right()
  } else {
    other.right()
  }
  let bottom = if self.bottom() < other.bottom() {
    self.bottom()
  } else {
    other.bottom()
  }
  {
    x: left,
    y: top,
    width: at_least_zero(right - left),
    height: at_least_zero(bottom - top),
  }
}

///|
/// The smallest region holding both. An empty operand is ignored, so a bounding
/// box can be grown from an empty seed.
pub fn Region::union(self : Region, other : Region) -> Region {
  if self.is_empty() {
    return other
  }
  if other.is_empty() {
    return self
  }
  Region::from_corners(
    if self.x < other.x {
      self.x
    } else {
      other.x
    },
    if self.y < other.y {
      self.y
    } else {
      other.y
    },
    if self.right() > other.right() {
      self.right()
    } else {
      other.right()
    },
    if self.bottom() > other.bottom() {
      self.bottom()
    } else {
      other.bottom()
    },
  )
}

///|
/// Cut the region in two at `cut` columns from its left edge. A cut outside the
/// region gives one full part and one empty part.
pub fn Region::split_vertical(self : Region, cut : Int) -> (Region, Region) {
  let at = clamp(cut, 0, self.width)
  ({ ..self, width: at, }, { ..self, x: self.x + at, width: self.width - at, })
}

///|
/// Cut the region in two at `cut` rows from its top edge.
pub fn Region::split_horizontal(self : Region, cut : Int) -> (Region, Region) {
  let at = clamp(cut, 0, self.height)
  (
    { ..self, height: at, },
    { ..self, y: self.y + at, height: self.height - at, },
  )
}

///|
/// Clip the region to a screen of this size anchored at the origin.
pub fn Region::clip(self : Region, width : Int, height : Int) -> Region {
  self.intersection({ x: 0, y: 0, width, height, })
}

///|
/// Padding around a region: the four edges, in the CSS order.
pub(all) struct Spacing {
  top : Int
  right : Int
  bottom : Int
  left : Int
} derive(Eq, Debug)

///|
/// The same padding on all four edges.
pub fn Spacing::all(amount : Int) -> Spacing {
  { top: amount, right: amount, bottom: amount, left: amount, }
}

///|
/// Padding on the left and right edges only.
pub fn Spacing::horizontal(amount : Int) -> Spacing {
  { top: 0, right: amount, bottom: 0, left: amount, }
}

///|
/// Padding on the top and bottom edges only.
pub fn Spacing::vertical(amount : Int) -> Spacing {
  { top: amount, right: 0, bottom: amount, left: 0, }
}

///|
/// The total padding across the horizontal axis.
pub fn Spacing::width(self : Spacing) -> Int {
  self.left + self.right
}

///|
/// The total padding across the vertical axis.
pub fn Spacing::height(self : Spacing) -> Int {
  self.top + self.bottom
}

///|
/// Push the edges of a region outwards by this padding.
pub fn Spacing::grow_region(self : Spacing, region : Region) -> Region {
  Region::new(
    region.x - self.left,
    region.y - self.top,
    region.width + self.width(),
    region.height + self.height(),
  )
}

///|
/// Pull the edges of a region inwards by this padding. Padding wider than the
/// region collapses that axis to zero rather than inverting it.
pub fn Spacing::shrink_region(self : Spacing, region : Region) -> Region {
  Region::new(
    region.x + self.left,
    region.y + self.top,
    region.width - self.width(),
    region.height - self.height(),
  )
}

///|
fn at_least_zero(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
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
pub extend Offset with Debug::{to_repr}

///|
pub extend Offset with Add::{add}

///|
pub extend Offset with Eq::{not_equal, equal}

///|
pub extend Offset with Neg::{neg}

///|
pub extend Offset with Sub::{sub}

///|
pub extend Region with Debug::{to_repr}

///|
pub extend Region with Eq::{not_equal, equal}

///|
pub extend Size with Debug::{to_repr}

///|
pub extend Size with Eq::{not_equal, equal}

///|
pub extend Spacing with Debug::{to_repr}

///|
pub extend Spacing with Eq::{not_equal, equal}
