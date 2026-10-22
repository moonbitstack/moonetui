// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a docked sidebar takes its edge and the flow keeps the rest" {
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Static::new("S"),
      styles=@design.Styles::new(dock=@design.Left),
    ),
    @app.leaf(2, @widget.Static::new("body")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(10, 3))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["Sbody     ", "          ", "          "])
}

///|
test "docked headers hold the top and bottom edges" {
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Static::new("head"),
      styles=@design.Styles::new(dock=@design.Top),
    ),
    @app.leaf(
      2,
      @widget.Static::new("foot"),
      styles=@design.Styles::new(dock=@design.Bottom),
    ),
    @app.leaf(3, @widget.Static::new("mid")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(10, 4))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), [
    "head      ", "mid       ", "          ", "foot      ",
  ])
}

///|
test "a stylesheet rule can dock a node by name" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Side"),
    @design.Styles::new(dock=@design.Right),
  )
  let tree = @app.column(0, [
    @app.leaf(1, @widget.Static::new("side"), name="Side"),
    @app.leaf(2, @widget.Static::new("body")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(10, 3))
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), ["body  side", "          ", "          "])
}

///|
test "two docks on one edge overlap and the later child draws on top" {
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Static::new("S1"),
      styles=@design.Styles::new(dock=@design.Left),
    ),
    @app.leaf(
      2,
      @widget.Static::new("T"),
      styles=@design.Styles::new(dock=@design.Left),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(10, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["T1        "])
}

///|
test "a grid lays its children out row by row" {
  let names = ["0", "1", "2", "3", "4"]
  let kids : Array[@app.Node] = []
  for i in 0..<5 {
    kids.push(@app.leaf(10 + i, @widget.Static::new(names[i])))
  }
  let tree = @app.grid(0, kids, cols=3)
  let tty = @driver.Headless::new(@geom.Size::new(9, 2))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["0  1  2  ", "3  4     "])
}

///|
test "a column span reaches across the row" {
  let tree = @app.grid(
    0,
    [
      @app.leaf(
        1,
        @widget.Static::new("aaaaaa"),
        styles=@design.Styles::new(column_span=2),
      ),
      @app.leaf(2, @widget.Static::new("b")),
      @app.leaf(3, @widget.Static::new("c")),
    ],
    cols=2,
  )
  let tty = @driver.Headless::new(@geom.Size::new(6, 2))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["aaaaaa", "b  c  "])
}

///|
test "a row span holds its column over several rows" {
  let tree = @app.grid(
    0,
    [
      @app.leaf(
        1,
        @widget.Static::new("a"),
        styles=@design.Styles::new(row_span=2),
      ),
      @app.leaf(2, @widget.Static::new("b")),
      @app.leaf(3, @widget.Static::new("c")),
    ],
    cols=2,
  )
  let tty = @driver.Headless::new(@geom.Size::new(6, 2))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["a  b  ", "   c  "])
}

///|
test "a gutter keeps gaps between the cells" {
  let tree = @app.grid(
    0,
    [
      @app.leaf(1, @widget.Static::new("aaa")),
      @app.leaf(2, @widget.Static::new("bbb")),
    ],
    cols=2,
    gutter=1,
  )
  let tty = @driver.Headless::new(@geom.Size::new(7, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["aaa bbb"])
}

///|
test "a grid is as wide as its columns and gutters" {
  let grid = @app.grid(
    0,
    [
      @app.leaf(1, @widget.Static::new("abcd")),
      @app.leaf(2, @widget.Static::new("ab")),
    ],
    cols=2,
    gutter=1,
  )
  assert_eq(grid.hint(@geom.Size::new(40, 10), Horizontal), 9)
}
