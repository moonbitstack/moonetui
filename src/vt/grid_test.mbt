// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let esc : String = "\u{1b}["

///|
test "text lands at the cursor and moves it along" {
  let grid = @vt.Grid::new(6, 2)
  grid.write("hi")
  assert_eq(grid.rows(), ["hi    ", "      "])
  grid.write(esc + "2;3Hxy")
  assert_eq(grid.rows(), ["hi    ", "  xy  "])
}

///|
test "a wide character claims the column after it" {
  let grid = @vt.Grid::new(6, 1)
  grid.write("中x")
  assert_eq(grid.at(0, 0).text, "中")
  assert_eq(grid.at(1, 0).text, "")
  assert_eq(grid.at(2, 0).text, "x")
}

///|
test "a combining mark joins the cell before it" {
  let grid = @vt.Grid::new(4, 1)
  grid.write("e\u{301}")
  assert_eq(grid.at(0, 0).text, "e\u{301}")
  assert_eq(grid.at(1, 0).text, " ")
}

///|
test "styles carry from the escape sequence onto the cells" {
  let grid = @vt.Grid::new(4, 1)
  grid.write(esc + "31mab" + esc + "39mc")
  assert_eq(grid.at(0, 0).style.fg, @style.red)
  assert_eq(grid.at(1, 0).style.fg, @style.red)
  assert_eq(grid.at(2, 0).style.fg, @style.Colour::Default)
}

///|
test "bright, indexed and true colour all arrive" {
  let grid = @vt.Grid::new(3, 1)
  grid.write(esc + "91ma" + esc + "38;5;214mb" + esc + "38;2;1;2;3mc")
  assert_eq(grid.at(0, 0).style.fg, @style.bright_red)
  assert_eq(grid.at(1, 0).style.fg, Ansi256(214))
  assert_eq(grid.at(2, 0).style.fg, Rgb(1, 2, 3))
}

///|
test "attributes accumulate until a reset" {
  let grid = @vt.Grid::new(3, 1)
  grid.write(esc + "1m" + esc + "4ma" + esc + "0mb")
  assert_eq(grid.at(0, 0).style.attrs.bold, true)
  assert_eq(grid.at(0, 0).style.attrs.underline, true)
  assert_eq(grid.at(1, 0).style.attrs.bold, false)
}

///|
test "erase clears the grid and parks the cursor" {
  let grid = @vt.Grid::new(3, 2)
  grid.write("abcdef")
  grid.write(esc + "2J")
  assert_eq(grid.rows(), ["   ", "   "])
  grid.write("z")
  assert_eq(grid.rows(), ["z  ", "   "])
}

///|
test "private modes are kept, not printed" {
  let grid = @vt.Grid::new(4, 1)
  assert_eq(grid.mode(25), true)
  assert_eq(grid.mode(1000), false)
  grid.write(esc + "?25l" + esc + "?1000;1006hok")
  assert_eq(grid.rows(), ["ok  "])
  assert_eq(grid.mode(25), false)
  assert_eq(grid.mode(1000), true)
  assert_eq(grid.mode(1006), true)
  grid.write(esc + "?1000l")
  assert_eq(grid.mode(1000), false)
}

///|
test "entering the alternate screen clears it" {
  let grid = @vt.Grid::new(3, 1)
  grid.write("abc" + esc + "?1049h")
  assert_eq(grid.rows(), ["   "])
}

///|
test "only the cells that changed are reported as dirty" {
  let grid = @vt.Grid::new(4, 1)
  grid.take_dirty() |> ignore
  grid.write(esc + "1;2Hx")
  let changed = grid.take_dirty()
  assert_eq(changed, [(1, 0)])
  assert_eq(grid.take_dirty(), [])
}

///|
test "a resize clears the grid and marks it all for redrawing" {
  let grid = @vt.Grid::new(4, 1)
  grid.write("abcd")
  grid.resize(2, 2)
  assert_eq(grid.rows(), ["  ", "  "])
  assert_eq(grid.take_dirty().length(), 4)
  grid.dirty_all()
  assert_eq(grid.take_dirty().length(), 4)
}

///|
test "writing past the edge wraps to the next row" {
  let grid = @vt.Grid::new(3, 2)
  grid.write("abcdef")
  assert_eq(grid.rows(), ["abc", "def"])
}

///|
test "a sequence split across writes still arrives whole" {
  let grid = @vt.Grid::new(4, 1)
  grid.write("a" + esc[0:1].to_owned())
  grid.write("[31mb")
  assert_eq(grid.at(1, 0).text, "b")
}

///|
test "a zero or missing position means the first row and column" {
  let grid = @vt.Grid::new(3, 2)
  grid.write(esc + "2;2Hx" + esc + "Hy" + esc + "0;0Hz")
  assert_eq(grid.rows(), ["z  ", " x "])
}

///|
test "the cursor moves by counts and stops at the edges" {
  let grid = @vt.Grid::new(4, 3)
  grid.write(esc + "2B" + esc + "3Ca" + esc + "9Ab" + esc + "9Dc")
  assert_eq(grid.rows(), ["c  b", "    ", "   a"])
  grid.write(esc + "2G" + esc + "3dd")
  assert_eq(grid.cursor(), (2, 2))
  assert_eq(grid.at(1, 2).text, "d")
}

///|
test "erasing in display covers the part asked for" {
  let grid = @vt.Grid::new(3, 2)
  grid.write("abcdef" + esc + "1;2H" + esc + "J")
  assert_eq(grid.rows(), ["a  ", "   "])
  grid.write(esc + "HXYZ" + esc + "2;1Hpqr" + esc + "2;2H" + esc + "1J")
  assert_eq(grid.rows(), ["   ", "  r"])
}

///|
test "erasing in line covers the part asked for" {
  let grid = @vt.Grid::new(4, 1)
  grid.write("abcd" + esc + "1;3H" + esc + "K")
  assert_eq(grid.rows(), ["ab  "])
  grid.write(esc + "1;1Habcd" + esc + "1;2H" + esc + "1K")
  assert_eq(grid.rows(), ["  cd"])
  grid.write(esc + "2K")
  assert_eq(grid.rows(), ["    "])
}

///|
test "erasing paints the background in force" {
  let grid = @vt.Grid::new(2, 1)
  grid.write(esc + "44m" + esc + "2J")
  assert_eq(grid.at(1, 0).style.bg, @style.blue)
}

///|
test "string sequences are skipped whole, even when split" {
  let grid = @vt.Grid::new(6, 1)
  grid.write("a\u{1b}]0;title\u{07}b\u{1b}]8;;https://x\u{1b}\\c")
  assert_eq(grid.rows(), ["abc   "])
  grid.write("\u{1b}]2;par")
  grid.write("tial\u{07}d\u{1b}(Be")
  assert_eq(grid.rows(), ["abcde "])
}

///|
test "attributes can be switched off one at a time" {
  let grid = @vt.Grid::new(5, 1)
  grid.write(
    esc +
    "1;3;4;7;9ma" +
    esc +
    "22mb" +
    esc +
    "23mc" +
    esc +
    "24;27md" +
    esc +
    "29me",
  )
  assert_eq(grid.at(0, 0).style.attrs.bold, true)
  assert_eq(grid.at(1, 0).style.attrs.bold, false)
  assert_eq(grid.at(2, 0).style.attrs.italic, false)
  assert_eq(grid.at(3, 0).style.attrs.underline, false)
  assert_eq(grid.at(3, 0).style.attrs.reverse, false)
  assert_eq(grid.at(4, 0).style.attrs, @style.plain)
}

///|
test "a line feed on the last row scrolls the screen up" {
  let grid = @vt.Grid::new(2, 2)
  grid.write("ab\ncd\nef")
  assert_eq(grid.rows(), ["cd", "ef"])
}

///|
test "tab and backspace move the cursor without writing" {
  let grid = @vt.Grid::new(12, 1)
  grid.write("a\tb\u{08}c")
  assert_eq(grid.rows(), ["a       c   "])
}

///|
test "a wide character that would straddle the edge starts the next row" {
  let grid = @vt.Grid::new(3, 2)
  grid.write("ab中")
  assert_eq(grid.rows(), ["ab ", "中 "])
}
