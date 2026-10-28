// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn room(width : Int32, height : Int32) -> @geom.Region {
  @geom.Region::new(0, 0, width, height)
}

///|
test "an anchor held to both edges of an axis stretches across it" {
  let got = @layout.anchor_region(
    room(20, 10),
    @geom.Size::new(4, 2),
    anchor=@layout.stretch,
  )
  assert_eq(got, @geom.Region::new(0, 0, 20, 10))
  assert_eq(@layout.stretch.spans_x(), true)
  assert_eq(@layout.stretch.spans_y(), true)
  assert_eq(@layout.free.spans_x(), false)
  assert_eq(@layout.free.spans_y(), false)
}

///|
test "an anchor held to one edge keeps that edge and its own size" {
  let want = @geom.Size::new(4, 2)
  assert_eq(
    @layout.anchor_region(
      room(20, 10),
      want,
      anchor=@layout.Anchor::new(top=true, left=true),
    ),
    @geom.Region::new(0, 0, 4, 2),
  )
  assert_eq(
    @layout.anchor_region(
      room(20, 10),
      want,
      anchor=@layout.Anchor::new(top=true, right=true),
    ),
    @geom.Region::new(16, 0, 4, 2),
  )
  assert_eq(
    @layout.anchor_region(
      room(20, 10),
      want,
      anchor=@layout.Anchor::new(bottom=true, left=true),
    ),
    @geom.Region::new(0, 8, 4, 2),
  )
  assert_eq(
    @layout.anchor_region(
      room(20, 10),
      want,
      anchor=@layout.Anchor::new(bottom=true, right=true),
    ),
    @geom.Region::new(16, 8, 4, 2),
  )
}

///|
test "an anchor held to no edge is put where its pivot says" {
  let want = @geom.Size::new(4, 2)
  let at = (pivot : @layout.Pivot) => {
    @layout.anchor_region(room(20, 10), want, anchor=@layout.free, pivot~)
  }
  assert_eq(at(@layout.Middle), @geom.Region::new(8, 4, 4, 2))
  assert_eq(at(@layout.TopRight), @geom.Region::new(16, 0, 4, 2))
  assert_eq(at(@layout.BottomLeft), @geom.Region::new(0, 8, 4, 2))
  assert_eq(at(@layout.BottomCentre), @geom.Region::new(8, 8, 4, 2))
  assert_eq(at(@layout.MiddleRight), @geom.Region::new(16, 4, 4, 2))
  assert_eq(at(@layout.TopLeft), @geom.Region::new(0, 0, 4, 2))
}

///|
test "every pivot puts its box inside the room it was given" {
  let space = room(21, 11)
  let want = @geom.Size::new(5, 3)
  for pivot in @layout.pivots() {
    let got = @layout.anchor_region(space, want, anchor=@layout.free, pivot~)
    assert_eq(space.contains_region(got), true)
    assert_eq(got.width, 5)
    assert_eq(got.height, 3)
  }
  assert_eq(@layout.pivots().length(), 9)
}

///|
test "a margin holds the box off the room before the anchor is applied" {
  let got = @layout.anchor_region(
    room(20, 10),
    @geom.Size::new(4, 2),
    anchor=@layout.Anchor::new(top=true, right=true),
    margin=@geom.Spacing::all(2),
  )
  assert_eq(got, @geom.Region::new(14, 2, 4, 2))
}

///|
test "a box bigger than its room is cut down to it" {
  let want = @geom.Size::new(20, 10)
  assert_eq(
    @layout.anchor_region(
      room(6, 4),
      want,
      anchor=@layout.free,
      pivot=@layout.Middle,
    ),
    @geom.Region::new(0, 0, 6, 4),
  )
  assert_eq(
    @layout.anchor_region(room(6, 4), want, anchor=@layout.stretch),
    @geom.Region::new(0, 0, 6, 4),
  )
}

///|
test "an anchor's own words are what they say" {
  assert_eq(@layout.free.is_free(), true)
  assert_eq(@layout.stretch.is_free(), false)
  assert_eq(@layout.Anchor::new(left=true).is_free(), false)
  assert_eq(@layout.Anchor::new(top=true, left=true).spans_x(), false)
  assert_eq(@layout.Anchor::new(left=true, right=true).spans_y(), false)
  assert_eq(@layout.corners().length(), 4)
  assert_eq(@layout.centre, @layout.Middle)
  assert_eq(@layout.TopLeft.frac_x(), 0.0)
  assert_eq(@layout.TopLeft.frac_y(), 0.0)
  assert_eq(@layout.Middle.frac_x(), 0.5)
  assert_eq(@layout.Middle.frac_y(), 0.5)
  assert_eq(@layout.BottomRight.frac_x(), 1.0)
  assert_eq(@layout.BottomRight.frac_y(), 1.0)
}

///|
test "an empty room leaves an empty place" {
  assert_eq(
    @layout.anchor_region(
      room(0, 0),
      @geom.Size::new(4, 2),
      anchor=@layout.free,
    ),
    @geom.Region::new(0, 0, 0, 0),
  )
}
