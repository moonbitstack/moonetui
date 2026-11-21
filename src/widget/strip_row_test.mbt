// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a strip row draws the row the function returns at the width it is given" {
  let widths : Array[Int32] = []
  let row = @widget.StripRow::new(fn(width) {
    widths.push(width)
    @strip.Strip::of("x".repeat(width), @style.Style::new(fg=@style.green))
  })
  let size = @geom.Size::new(6, 1)
  assert_eq(row.render_line(0, size).text(), "xxxxxx")
  // The width comes from the size of the row as it is drawn, not from a size
  // the widget remembered.
  assert_eq(row.render_line(0, @geom.Size::new(3, 1)).text(), "xxx")
  assert_eq(widths, [6, 3])
  assert_eq(row.hint(size), @geom.Size::new(6, 1))
}

///|
test "a strip row takes no keys and cannot be focused" {
  let row = @widget.StripRow::new(fn(width) {
    @strip.Strip::blank(width, @style.default)
  })
  let ctx = @widget.Ctx::new(1, @geom.Size::new(4, 1))
  assert_eq(row.focusable(), false)
  assert_eq(row.handle(ctx, @widget.Msg::Focus(true)), false)
}
