// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "one changed column produces one span" {
  let before = [@strip.Strip::of("hello", plain)]
  let after = [@strip.Strip::of("hEllo", plain)]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].y, 0)
  assert_eq(spans[0].x, 1)
  assert_eq(spans[0].line.text(), "E")
}

///|
test "identical screens produce no spans" {
  let rows = [@strip.Strip::of("same", plain), @strip.Strip::of("rows", plain)]
  assert_eq(@comp.diff(rows, rows).length(), 0)
}

///|
test "a style change alone is a difference" {
  let before = [@strip.Strip::of("ab", plain)]
  let after = [
    @strip.Strip::join([
      @strip.Strip::of("a", plain),
      @strip.Strip::of("b", red),
    ]),
  ]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].x, 1)
  assert_eq(spans[0].line.segs[0].style, red)
}

///|
test "a row that got shorter has its tail cleared" {
  let before = [@strip.Strip::of("longer", plain)]
  let after = [@strip.Strip::of("longer", plain).crop(0, 4)]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].x, 4)
  assert_eq(spans[0].line.text(), "  ")
}

///|
test "a wide character drags both of its columns into the span" {
  let before = [@strip.Strip::of("ab中", plain)]
  let after = [@strip.Strip::of("ab文", plain)]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].x, 2)
  assert_eq(spans[0].line.text(), "文")
}

///|
test "a full repaint is one span per row" {
  let rows = [@strip.Strip::of("ab", plain), @strip.Strip::of("cd", plain)]
  let spans = @comp.full(rows)
  assert_eq(spans.length(), 2)
  assert_eq(spans[1].y, 1)
  assert_eq(spans[1].x, 0)
}
