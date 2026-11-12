// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// How many blank cells lie between the first and last mark of a row: what an
/// outline leaves inside it.
fn blanks_between(row : String) -> Int32 {
  let mut first = -1
  let mut last = -1
  for i in 0..<row.length() {
    if row[i] != ' ' {
      if first < 0 {
        first = i
      }
      last = i
    }
  }
  if first < 0 {
    return row.length()
  }
  let mut blanks = 0
  for i in first..<=last {
    if row[i] == ' ' {
      blanks = blanks + 1
    }
  }
  blanks
}

///|
fn canvas_rows(
  canvas : &@widget.Widget,
  width : Int32,
  height : Int32,
) -> Array[String] {
  let out : Array[String] = []
  for row in 0..<height {
    out.push(canvas.render_line(row, size(width, height)).text())
  }
  out
}

///|
test "a point lands in the cell and the dot its coordinates name" {
  let canvas = @widget.Canvas::new(shapes=[Dot(0.5, 0.5)])
  let w : &@widget.Widget = canvas
  // Eight dots across and eight down: the middle is dot 4 of 8, which is the
  // first dot of the second row's third cell.
  assert_eq(canvas_rows(w, 4, 2), ["    ", "  \u{2801} "])
}

///|
test "a horizontal line fills the row of dots it runs along" {
  let canvas = @widget.Canvas::new(shapes=[Line(0.0, 0.5, 1.0, 0.5)])
  let w : &@widget.Widget = canvas
  assert_eq(canvas_rows(w, 4, 2), ["    ", "\u{2809}\u{2809}\u{2809}\u{2809}"])
}

///|
test "y grows upwards, as a plot's does" {
  let low = @widget.Canvas::new(shapes=[Dot(0.5, 0.1)])
  let high = @widget.Canvas::new(shapes=[Dot(0.5, 0.9)])
  let low_rows = canvas_rows(low, 2, 4)
  let high_rows = canvas_rows(high, 2, 4)
  assert_eq(low_rows[3].trim() != "", true)
  assert_eq(high_rows[0].trim() != "", true)
  assert_eq(high_rows[3].trim(), "")
}

///|
test "a rectangle is an outline: four corners drawn, the middle left alone" {
  let canvas = @widget.Canvas::new(shapes=[Rect(0.1, 0.1, 0.9, 0.9)])
  let rows = canvas_rows(canvas, 6, 4)
  assert_eq(rows[0].trim() != "", true)
  assert_eq(rows[3].trim() != "", true)
  // The left and right edges are drawn and the cells between them are not, so
  // the two middle rows hold two marks and the top row a run of them.
  assert_eq(blanks_between(rows[1]), 4)
  assert_eq(blanks_between(rows[0]) < 4, true)
}

///|
test "a circle reaches all four sides of its box and leaves its centre empty" {
  let canvas = @widget.Canvas::new(shapes=[Circle(0.5, 0.5, 0.4)])
  let rows = canvas_rows(canvas, 8, 6)
  assert_eq(rows[0].trim() != "", true)
  assert_eq(rows[5].trim() != "", true)
  // At its widest the circle is two marks with the inside left blank.
  assert_eq(blanks_between(rows[3]), 4)
}

///|
test "a shape outside the range is cut, not wrapped" {
  let canvas = @widget.Canvas::new(shapes=[
    Dot(-4.0, 0.5),
    Line(2.0, 2.0, 3.0, 3.0),
  ])
  assert_eq(canvas_rows(canvas, 4, 2), ["    ", "    "])
}

///|
test "the same shapes are a thumbnail at one size and a plot at another" {
  let canvas = @widget.Canvas::new(shapes=[Circle(0.5, 0.5, 0.45)])
  let small = canvas_rows(canvas, 4, 2)
  let large = canvas_rows(canvas, 12, 6)
  assert_eq(small, [
    "\u{2870}\u{280a}\u{2811}\u{2886}", "\u{2831}\u{2884}\u{2860}\u{280e}",
  ])
  assert_eq(large[3] != small[0], true)
  // Every row of the plot is a full row of cells, dots or spaces.
  for row in large {
    assert_eq(row.length(), 12)
  }
}

///|
test "drawing adds to what is there, and the range says what the numbers mean" {
  let canvas = @widget.Canvas::new(
    shapes=[Dot(0.0, 0.0)],
    x_range=(-1.0, 1.0),
    y_range=(-1.0, 1.0),
  )
  assert_eq(canvas.shapes().length(), 1)
  assert_eq(canvas.x_range(), (-1.0, 1.0))
  canvas.draw(Dot(1.0, 1.0))
  canvas.draw(Line(0.0, 0.0, 1.0, 1.0))
  assert_eq(canvas.shapes().length(), 3)
  // The corners of the range are the corners of the plot, not its middle.
  let rows = canvas_rows(canvas, 4, 2)
  // The corner of the range is the corner of the plot, and its middle is the
  // middle: y grows upwards, so (1, 1) is top right and (0, 0) is central.
  assert_eq(rows[0][3] != ' ', true)
  assert_eq(rows[1][2] != ' ', true)
  canvas.set_range(x_range=(0.0, 1.0), y_range=(0.0, 1.0))
  assert_eq(canvas.y_range(), (0.0, 1.0))
  canvas.set_shapes([])
  assert_eq(canvas_rows(canvas, 4, 2), ["    ", "    "])
}

///|
test "a canvas fills what it is given and takes nothing from the keyboard" {
  let canvas = @widget.Canvas::new()
  assert_eq(canvas.focusable(), false)
  assert_eq(canvas.hint(size(10, 3)), size(10, 3))
  assert_eq(press(canvas, 1, size(10, 3), key(Down)), [])
  assert_eq(canvas.render_line(9, size(10, 3)).text(), "")
}

///|
/// The eight dots of one cell, four down each of its two columns: a vertical
/// line at either edge of the range reaches all of them.
test "all eight dots of a cell can be lit, and each lands where it belongs" {
  let left = @widget.Canvas::new(shapes=[Line(0.0, 0.0, 0.0, 1.0)])
  assert_eq(canvas_rows(left, 1, 2), ["\u{2847}", "\u{2847}"])
  let right = @widget.Canvas::new(shapes=[Line(1.0, 0.0, 1.0, 1.0)])
  assert_eq(canvas_rows(right, 1, 2), ["\u{28b8}", "\u{28b8}"])
}
