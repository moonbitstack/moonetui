// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "an anchored node sits on its corner and takes none of the flow" {
  let pinned = @app.leaf(
    1,
    @widget.Static::new("pin"),
    styles=@design.Styles::new(
      width=Cells(6),
      height=Cells(3),
      anchor=@layout.Anchor::new(bottom=true, right=true),
      border=@design.Round,
    ),
  )
  let filler = @app.leaf(2, @widget.Static::new("flow runs all the way across"))
  let tree = @app.column(0, [pinned, filler])
  let tty = @driver.Headless::new(@geom.Size::new(30, 8))
  let ui = @app.App::new(tty, tree)
  ui.start()
  let region = ui.rect_of(1)
  assert_eq(region, @geom.Region::new(24, 5, 6, 3))
  let screen = ui.screen()
  assert_eq(screen[7].contains("╰"), true)
  assert_eq(screen[0].contains("flow runs all the way"), true)
}

///|
test "a node held to nothing floats where its pivot says" {
  let floating = @app.leaf(
    1,
    @widget.Static::new("mid"),
    styles=@design.Styles::new(
      width=Cells(8),
      height=Cells(3),
      anchor=@layout.free,
      pivot=@layout.Middle,
      border=@design.Round,
    ),
  )
  let tree = @app.column(0, [floating])
  let tty = @driver.Headless::new(@geom.Size::new(30, 9))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.rect_of(1), @geom.Region::new(11, 3, 8, 3))
}

///|
test "an anchored node stays in the focus ring and takes input" {
  let bar = @widget.Scrollbar::new(content=40, viewport=10)
  let pinned = @app.leaf(
    1,
    bar,
    styles=@design.Styles::new(
      width=Cells(1),
      anchor=@layout.Anchor::new(top=true, right=true),
    ),
  )
  let note = @app.leaf(2, @widget.Static::new("body"))
  let tree = @app.column(0, [pinned, note])
  let tty = @driver.Headless::new(@geom.Size::new(20, 8), script=[
    ascii("\u001b[B"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.rect_of(1), @geom.Region::new(19, 0, 1, 8))
  ignore(ui.step())
  ignore(ui.step())
  let moved = ui.drain().filter(out => out is Scrolled(..))
  assert_eq(moved.length() > 0, true)
}

///|
test "a theme switch restyles the whole tree in one call" {
  let note = @app.leaf(
    1,
    @widget.Static::new("red"),
    box=@layout.Box::new(extent=Cells(1)),
    classes=["error"],
  )
  let tree = @app.column(0, [note])
  let tty = @driver.Headless::new(@geom.Size::new(10, 2))
  let ui = @app.App::new(tty, tree, sheet=@design.dark.sheet())
  ui.start()
  let before = tty.output()
  ui.set_theme(@design.light)
  ignore(ui.step())
  let after = tty.output()
  assert_eq(before != "", true)
  assert_eq(after != "", true)
  assert_eq(before != after, true)
  assert_eq(ui.screen()[0].contains("red"), true)
}
