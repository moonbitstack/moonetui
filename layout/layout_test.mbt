// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let screen : @geom.Region = @geom.Region::new(0, 0, 20, 10)

///|
/// The extents of a row of regions along the stacking axis, which is what a
/// layout is really about.
fn spans(regions : Array[@geom.Region], dir : @layout.Dir) -> Array[Int] {
  let out : Array[Int] = []
  for r in regions {
    out.push(@layout.main_of(r.size(), dir))
  }
  out
}

///|
test "fixed sizes are taken literally" {
  let boxes = [
    @layout.Box::new(extent=Cells(3)),
    @layout.Box::new(extent=Cells(4)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  assert_eq(spans(placed, Vertical), [3, 4])
  assert_eq(placed[0], @geom.Region::new(0, 0, 20, 3))
  assert_eq(placed[1], @geom.Region::new(0, 3, 20, 4))
}

///|
test "an automatic box takes what its content asks for" {
  let boxes = [@layout.Box::new(), @layout.Box::new()]
  let placed = @layout.arrange(screen, Vertical, boxes, [2, 5])
  assert_eq(spans(placed, Vertical), [2, 5])
}

///|
test "fractions divide what is left and lose nothing to rounding" {
  // Ten rows between three shares does not divide evenly; the parts must still
  // add up to ten, or the layout leaves a blank row behind.
  let boxes = [
    @layout.Box::new(extent=Frac(1)),
    @layout.Box::new(extent=Frac(1)),
    @layout.Box::new(extent=Frac(1)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  let sizes = spans(placed, Vertical)
  assert_eq(sizes[0] + sizes[1] + sizes[2], 10)
  assert_eq(sizes, [4, 3, 3])
}

///|
test "shares are proportional" {
  let boxes = [
    @layout.Box::new(extent=Frac(3)),
    @layout.Box::new(extent=Frac(1)),
  ]
  let placed = @layout.arrange(screen, Horizontal, boxes, [])
  assert_eq(spans(placed, Horizontal), [15, 5])
}

///|
test "fixed boxes are served before the fractions" {
  let boxes = [
    @layout.Box::new(extent=Cells(4)),
    @layout.Box::new(extent=Frac(1)),
    @layout.Box::new(extent=Cells(2)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  assert_eq(spans(placed, Vertical), [4, 4, 2])
}

///|
test "a percentage is of the container" {
  let boxes = [
    @layout.Box::new(extent=Pct(50)),
    @layout.Box::new(extent=Frac(1)),
  ]
  let placed = @layout.arrange(screen, Horizontal, boxes, [])
  assert_eq(spans(placed, Horizontal), [10, 10])
}

///|
test "limits pin a box and the rest divide what is left" {
  let boxes = [
    @layout.Box::new(extent=Frac(1), max=2),
    @layout.Box::new(extent=Frac(1)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  // The first box wanted five rows, is capped at two, and the second takes the
  // rest — pinning one box changes what the others are entitled to.
  assert_eq(spans(placed, Vertical), [2, 8])
}

///|
test "a minimum wins over a share that is too small" {
  let boxes = [
    @layout.Box::new(extent=Frac(1), min=8),
    @layout.Box::new(extent=Frac(1)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  assert_eq(spans(placed, Vertical), [8, 2])
}

///|
test "gaps come out of the shared space" {
  let boxes = [
    @layout.Box::new(extent=Frac(1)),
    @layout.Box::new(extent=Frac(1)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [], gap=2)
  assert_eq(spans(placed, Vertical), [4, 4])
  // The second box starts after the first one plus the gap.
  assert_eq(placed[1].y, 6)
}

///|
test "padding shrinks the box, not its slot" {
  let boxes = [
    @layout.Box::new(extent=Cells(6), pad=@geom.Spacing::all(1)),
    @layout.Box::new(extent=Cells(4)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  assert_eq(placed[0], @geom.Region::new(1, 1, 18, 4))
  // The next box still starts where the unpadded slot ended.
  assert_eq(placed[1].y, 6)
}

///|
test "boxes pushed past the end come back empty" {
  let boxes = [
    @layout.Box::new(extent=Cells(8)),
    @layout.Box::new(extent=Cells(8)),
  ]
  let placed = @layout.arrange(screen, Vertical, boxes, [])
  assert_eq(placed[0].height, 8)
  // Only two rows are left, so the second box is cut short rather than drawn
  // outside the container.
  assert_eq(placed[1], @geom.Region::new(0, 8, 20, 2))
}

///|
test "no boxes means no regions" {
  assert_eq(@layout.arrange(screen, Vertical, [], []).length(), 0)
}

///|
test "horizontal and vertical are the same rules on the other axis" {
  let boxes = [
    @layout.Box::new(extent=Cells(5)),
    @layout.Box::new(extent=Frac(1)),
  ]
  let across = @layout.arrange(screen, Horizontal, boxes, [])
  assert_eq(across[0], @geom.Region::new(0, 0, 5, 10))
  assert_eq(across[1], @geom.Region::new(5, 0, 15, 10))
}
