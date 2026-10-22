// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let screen : @geom.Region = @geom.Region::new(0, 0, 20, 10)

///|
fn spans(regions : Array[@geom.Region], dir : @layout.Dir) -> Array[Int32] {
  let out : Array[Int32] = []
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

///|
test "rows grow until every child has a cell" {
  let kids : Array[@layout.GridChild] = []
  for _ in 0..<3 {
    kids.push(@layout.GridChild::new(col_span=2, height=1))
  }
  assert_eq(@layout.grid_slots(kids, cols=2), [(0, 0), (1, 0), (2, 0)])
}

///|
test "spans claim the first free block that fits" {
  let kids = [
    @layout.GridChild::new(col_span=2, height=1),
    @layout.GridChild::new(height=1),
    @layout.GridChild::new(row_span=2, height=2),
    @layout.GridChild::new(height=1),
  ]
  let slots = @layout.grid_slots(kids, cols=3, rows=2)
  assert_eq(slots, [(0, 0), (0, 2), (1, 0), (1, 1)])
  let heights = @layout.grid_row_heights(kids, slots)
  assert_eq(heights, [1, 1, 1])
}

///|
test "a span wider than the grid is held to the grid" {
  let kids = [
    @layout.GridChild::new(col_span=5, height=1),
    @layout.GridChild::new(height=1),
  ]
  let slots = @layout.grid_slots(kids, cols=2)
  assert_eq(slots, [(0, 0), (1, 0)])
  let rects = @layout.arrange_grid(
    @geom.Region::new(0, 0, 10, 2),
    slots,
    kids,
    cols=2,
  )
  assert_eq(rects, [
    @geom.Region::new(0, 0, 10, 1),
    @geom.Region::new(0, 1, 5, 1),
  ])
}

///|
test "columns share the width and lose no column to rounding" {
  let kids = Array::make(3, @layout.GridChild::new(height=1))
  let slots = @layout.grid_slots(kids, cols=3)
  let area = @geom.Region::new(0, 0, 10, 1)
  let plain = @layout.arrange_grid(area, slots, kids, cols=3)
  assert_eq(plain.map(r => (r.x, r.width)), [(0, 4), (4, 3), (7, 3)])
  let spaced = @layout.arrange_grid(area, slots, kids, cols=3, gutter=1)
  assert_eq(spaced.map(r => (r.x, r.width)), [(0, 3), (4, 3), (8, 2)])
}
