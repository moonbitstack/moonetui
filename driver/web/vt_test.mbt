// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let esc : String = "\u{1b}["

///|
test "text lands at the cursor and moves it along" {
  let grid = @web.Grid::new(6, 2)
  grid.write("hi")
  assert_eq(grid.rows(), ["hi    ", "      "])
  grid.write(esc + "2;3Hxy")
  assert_eq(grid.rows(), ["hi    ", "  xy  "])
}

///|
test "a wide character claims the column after it" {
  let grid = @web.Grid::new(6, 1)
  grid.write("中x")
  assert_eq(grid.at(0, 0).text, "中")
  // The second column belongs to the same character and is left empty so that
  // nothing paints over half of it.
  assert_eq(grid.at(1, 0).text, "")
  assert_eq(grid.at(2, 0).text, "x")
}

///|
test "a combining mark joins the cell before it" {
  let grid = @web.Grid::new(4, 1)
  grid.write("e\u{301}")
  assert_eq(grid.at(0, 0).text, "e\u{301}")
  assert_eq(grid.at(1, 0).text, " ")
}

///|
test "styles carry from the escape sequence onto the cells" {
  let grid = @web.Grid::new(4, 1)
  grid.write(esc + "31mab" + esc + "39mc")
  assert_eq(grid.at(0, 0).style.fg, @style.red)
  assert_eq(grid.at(1, 0).style.fg, @style.red)
  assert_eq(grid.at(2, 0).style.fg, @style.Color::Default)
}

///|
test "bright, indexed and true colour all arrive" {
  let grid = @web.Grid::new(3, 1)
  grid.write(esc + "91ma" + esc + "38;5;214mb" + esc + "38;2;1;2;3mc")
  assert_eq(grid.at(0, 0).style.fg, @style.bright_red)
  assert_eq(grid.at(1, 0).style.fg, Ansi256(214))
  assert_eq(grid.at(2, 0).style.fg, Rgb(1, 2, 3))
}

///|
test "attributes accumulate until a reset" {
  let grid = @web.Grid::new(3, 1)
  grid.write(esc + "1m" + esc + "4ma" + esc + "0mb")
  assert_eq(grid.at(0, 0).style.attrs.bold, true)
  assert_eq(grid.at(0, 0).style.attrs.underline, true)
  assert_eq(grid.at(1, 0).style.attrs.bold, false)
}

///|
test "erase clears the grid and parks the cursor" {
  let grid = @web.Grid::new(3, 2)
  grid.write("abcdef")
  grid.write(esc + "2J")
  assert_eq(grid.rows(), ["   ", "   "])
  grid.write("z")
  assert_eq(grid.rows(), ["z  ", "   "])
}

///|
test "private sequences are ignored rather than printed" {
  let grid = @web.Grid::new(4, 1)
  // Hiding the cursor, entering the alternate screen, enabling the mouse: all
  // real output from the library, none of it text.
  grid.write(esc + "?25l" + esc + "?1049h" + esc + "?1000hok")
  assert_eq(grid.rows(), ["ok  "])
}

///|
test "only the cells that changed are reported as dirty" {
  let grid = @web.Grid::new(4, 1)
  grid.take_dirty() |> ignore
  grid.write(esc + "1;2Hx")
  let changed = grid.take_dirty()
  assert_eq(changed, [(1, 0)])
  // Collecting them clears the marks, so an unchanged frame draws nothing.
  assert_eq(grid.take_dirty(), [])
}

///|
test "a resize clears the grid and marks it all for redrawing" {
  let grid = @web.Grid::new(4, 1)
  grid.write("abcd")
  grid.resize(2, 2)
  assert_eq(grid.rows(), ["  ", "  "])
  assert_eq(grid.take_dirty().length(), 4)
  grid.dirty_all()
  assert_eq(grid.take_dirty().length(), 4)
}

///|
test "writing past the edge wraps to the next row" {
  let grid = @web.Grid::new(3, 2)
  grid.write("abcdef")
  assert_eq(grid.rows(), ["abc", "def"])
}

///|
test "a sequence split across writes still arrives whole" {
  let grid = @web.Grid::new(4, 1)
  grid.write("a" + esc[0:1].to_owned())
  grid.write("[31mb")
  // The escape opened in one write and finished in the next; the colour still
  // reaches the cell.
  assert_eq(grid.at(1, 0).text, "b")
}
