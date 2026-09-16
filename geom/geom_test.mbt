// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "offset arithmetic" {
  let a : @geom.Offset = { x: 3, y: 4, }
  let b : @geom.Offset = { x: 10, y: -2, }
  assert_eq(a + b, { x: 13, y: 2, })
  assert_eq(b - a, { x: 7, y: -6, })
  assert_eq(-a, { x: -3, y: -4, })
  assert_eq(a.scale(3), { x: 9, y: 12, })
  assert_eq(a.transpose(), { x: 4, y: 3, })
  assert_eq(@geom.origin.is_origin(), true)
  assert_eq(a.is_origin(), false)
}

///|
test "size clamps negative extents" {
  assert_eq(@geom.Size::new(-4, 3), { width: 0, height: 3, })
  assert_eq(@geom.Size::new(6, -1).is_empty(), true)
  assert_eq(@geom.Size::new(6, 4).area(), 24)
  assert_eq(@geom.Size::new(6, 4).region(), { x: 0, y: 0, width: 6, height: 4, })
}

///|
test "size contains and clamps offsets" {
  let size = @geom.Size::new(6, 4)
  assert_eq(size.contains(5, 3), true)
  assert_eq(size.contains(6, 3), false)
  assert_eq(size.contains(-1, 0), false)
  assert_eq(size.clamp_offset({ x: 99, y: 99, }), { x: 5, y: 3, })
  assert_eq(size.clamp_offset({ x: -99, y: 2, }), { x: 0, y: 2, })
  // A zero-extent axis has no valid cell, so it clamps to zero rather than -1.
  assert_eq(@geom.Size::new(0, 0).clamp_offset({ x: 4, y: 4, }), { x: 0, y: 0, })
}

///|
test "region corners and edges" {
  let r = @geom.Region::new(2, 3, 10, 5)
  assert_eq(r.right(), 12)
  assert_eq(r.bottom(), 8)
  assert_eq(r.offset(), { x: 2, y: 3, })
  assert_eq(r.size(), { width: 10, height: 5, })
  assert_eq(r.area(), 50)
  assert_eq(@geom.Region::from_corners(12, 8, 2, 3), r)
  assert_eq(@geom.Region::new(2, 3, -7, 5).is_empty(), true)
}

///|
test "region intersection is commutative and contained in both" {
  let a = @geom.Region::new(0, 0, 10, 10)
  let b = @geom.Region::new(5, 5, 10, 10)
  let hit = a.intersection(b)
  assert_eq(hit, @geom.Region::new(5, 5, 5, 5))
  assert_eq(b.intersection(a), hit)
  assert_eq(a.contains_region(hit), true)
  assert_eq(b.contains_region(hit), true)
  assert_eq(a.overlaps(b), true)
}

///|
test "regions that only touch do not overlap" {
  let a = @geom.Region::new(0, 0, 4, 4)
  let b = @geom.Region::new(4, 0, 4, 4)
  assert_eq(a.intersection(b).is_empty(), true)
  assert_eq(a.overlaps(b), false)
}

///|
test "region union ignores empty operands" {
  let a = @geom.Region::new(1, 1, 3, 3)
  let empty = @geom.Region::new(20, 20, 0, 0)
  assert_eq(a.union(empty), a)
  assert_eq(empty.union(a), a)
  assert_eq(
    a.union(@geom.Region::new(6, 1, 2, 2)),
    @geom.Region::new(1, 1, 7, 3),
  )
}

///|
test "region translate and contains" {
  let r = @geom.Region::new(2, 2, 3, 3)
  assert_eq(r.contains(2, 2), true)
  assert_eq(r.contains(5, 2), false)
  let moved = r.translate({ x: -2, y: 1, })
  assert_eq(moved, @geom.Region::new(0, 3, 3, 3))
  assert_eq(moved.contains(0, 3), true)
}

///|
test "region splits keep every cell exactly once" {
  let r = @geom.Region::new(0, 0, 9, 4)
  let (left, right) = r.split_vertical(4)
  assert_eq(left, @geom.Region::new(0, 0, 4, 4))
  assert_eq(right, @geom.Region::new(4, 0, 5, 4))
  assert_eq(left.area() + right.area(), r.area())
  let (top, bottom) = r.split_horizontal(1)
  assert_eq(top, @geom.Region::new(0, 0, 9, 1))
  assert_eq(bottom, @geom.Region::new(0, 1, 9, 3))
  assert_eq(top.area() + bottom.area(), r.area())
}

///|
test "region split outside the region yields one empty part" {
  let r = @geom.Region::new(0, 0, 5, 5)
  let (left, right) = r.split_vertical(99)
  assert_eq(left, r)
  assert_eq(right.is_empty(), true)
  let (top, bottom) = r.split_horizontal(-3)
  assert_eq(top.is_empty(), true)
  assert_eq(bottom, r)
}

///|
test "region clip keeps the on-screen part" {
  let off_screen = @geom.Region::new(-3, -2, 6, 5)
  assert_eq(off_screen.clip(10, 10), @geom.Region::new(0, 0, 3, 3))
  assert_eq(@geom.Region::new(20, 20, 4, 4).clip(10, 10).is_empty(), true)
}

///|
test "spacing grows and shrinks a region" {
  let r = @geom.Region::new(4, 4, 10, 6)
  let pad = @geom.Spacing::all(2)
  assert_eq(pad.width(), 4)
  assert_eq(pad.height(), 4)
  assert_eq(pad.grow_region(r), @geom.Region::new(2, 2, 14, 10))
  assert_eq(pad.shrink_region(r), @geom.Region::new(6, 6, 6, 2))
  assert_eq(@geom.Spacing::horizontal(1).height(), 0)
  assert_eq(@geom.Spacing::vertical(1).width(), 0)
}

///|
test "padding wider than the region collapses that axis" {
  let r = @geom.Region::new(0, 0, 3, 3)
  let pad = @geom.Spacing::all(5)
  let inner = pad.shrink_region(r)
  assert_eq(inner.is_empty(), true)
  assert_eq(inner.width, 0)
  assert_eq(inner.height, 0)
}
