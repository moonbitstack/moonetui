// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) struct Offset {
  x : Int32
  y : Int32
} derive(Eq, Debug)

///|
pub let origin : Offset = { x: 0, y: 0, }

///|
pub fn Offset::is_origin(self : Offset) -> Bool {
  self.x == 0 && self.y == 0
}

///|
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
pub fn Offset::scale(self : Offset, factor : Int32) -> Offset {
  { x: self.x * factor, y: self.y * factor, }
}

///|
pub(all) struct Size {
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub fn Size::new(width : Int32, height : Int32) -> Size {
  { width: at_least_zero(width), height: at_least_zero(height), }
}

///|
pub fn Size::area(self : Size) -> Int32 {
  self.width * self.height
}

///|
pub fn Size::is_empty(self : Size) -> Bool {
  self.width == 0 || self.height == 0
}

///|
pub fn Size::region(self : Size) -> Region {
  { x: 0, y: 0, width: self.width, height: self.height, }
}

///|
pub fn Size::contains(self : Size, x : Int32, y : Int32) -> Bool {
  x >= 0 && x < self.width && y >= 0 && y < self.height
}

///|
pub fn Size::clamp_offset(self : Size, offset : Offset) -> Offset {
  {
    x: clamp(offset.x, 0, at_least_zero(self.width - 1)),
    y: clamp(offset.y, 0, at_least_zero(self.height - 1)),
  }
}

///|
pub(all) struct Region {
  x : Int32
  y : Int32
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub fn Region::new(
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) -> Region {
  { x, y, width: at_least_zero(width), height: at_least_zero(height), }
}

///|
pub fn Region::from_corners(
  x1 : Int32,
  y1 : Int32,
  x2 : Int32,
  y2 : Int32,
) -> Region {
  let left = if x1 < x2 { x1 } else { x2 }
  let top = if y1 < y2 { y1 } else { y2 }
  let right = if x1 < x2 { x2 } else { x1 }
  let bottom = if y1 < y2 { y2 } else { y1 }
  { x: left, y: top, width: right - left, height: bottom - top, }
}

///|
pub fn Region::offset(self : Region) -> Offset {
  { x: self.x, y: self.y, }
}

///|
pub fn Region::size(self : Region) -> Size {
  { width: self.width, height: self.height, }
}

///|
pub fn Region::right(self : Region) -> Int32 {
  self.x + self.width
}

///|
pub fn Region::bottom(self : Region) -> Int32 {
  self.y + self.height
}

///|
pub fn Region::area(self : Region) -> Int32 {
  self.width * self.height
}

///|
pub fn Region::is_empty(self : Region) -> Bool {
  self.width == 0 || self.height == 0
}

///|
pub fn Region::translate(self : Region, offset : Offset) -> Region {
  let moved = self.offset() + offset
  { ..self, x: moved.x, y: moved.y, }
}

///|
pub fn Region::contains(self : Region, x : Int32, y : Int32) -> Bool {
  x >= self.x && x < self.right() && y >= self.y && y < self.bottom()
}

///|
pub fn Region::contains_region(self : Region, other : Region) -> Bool {
  other.x >= self.x &&
  other.y >= self.y &&
  other.right() <= self.right() &&
  other.bottom() <= self.bottom()
}

///|
pub fn Region::overlaps(self : Region, other : Region) -> Bool {
  !self.intersection(other).is_empty()
}

///|
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
pub fn Region::split_vertical(self : Region, cut : Int32) -> (Region, Region) {
  let at = clamp(cut, 0, self.width)
  ({ ..self, width: at, }, { ..self, x: self.x + at, width: self.width - at, })
}

///|
pub fn Region::split_horizontal(self : Region, cut : Int32) -> (Region, Region) {
  let at = clamp(cut, 0, self.height)
  (
    { ..self, height: at, },
    { ..self, y: self.y + at, height: self.height - at, },
  )
}

///|
pub fn Region::clip(self : Region, width : Int32, height : Int32) -> Region {
  self.intersection({ x: 0, y: 0, width, height, })
}

///|
pub(all) struct Spacing {
  top : Int32
  right : Int32
  bottom : Int32
  left : Int32
} derive(Eq, Debug)

///|
pub fn Spacing::all(amount : Int32) -> Spacing {
  { top: amount, right: amount, bottom: amount, left: amount, }
}

///|
pub fn Spacing::horizontal(amount : Int32) -> Spacing {
  { top: 0, right: amount, bottom: 0, left: amount, }
}

///|
pub fn Spacing::vertical(amount : Int32) -> Spacing {
  { top: amount, right: 0, bottom: amount, left: 0, }
}

///|
pub fn Spacing::width(self : Spacing) -> Int32 {
  self.left + self.right
}

///|
pub fn Spacing::height(self : Spacing) -> Int32 {
  self.top + self.bottom
}

///|
pub fn Spacing::add(self : Spacing, other : Spacing) -> Spacing {
  {
    top: self.top + other.top,
    right: self.right + other.right,
    bottom: self.bottom + other.bottom,
    left: self.left + other.left,
  }
}

///|
pub fn Spacing::is_zero(self : Spacing) -> Bool {
  self.top == 0 && self.right == 0 && self.bottom == 0 && self.left == 0
}

///|
pub fn Spacing::grow_region(self : Spacing, region : Region) -> Region {
  Region::new(
    region.x - self.left,
    region.y - self.top,
    region.width + self.width(),
    region.height + self.height(),
  )
}

///|
pub fn Spacing::shrink_region(self : Spacing, region : Region) -> Region {
  Region::new(
    region.x + self.left,
    region.y + self.top,
    region.width - self.width(),
    region.height - self.height(),
  )
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
