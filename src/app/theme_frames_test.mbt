// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A palette held to one role: how an application hands a theme to a widget,
/// since a widget takes plain styles and knows nothing of roles.
fn ink(theme : @design.Theme, role : @design.Role) -> @style.Style {
  @style.Style::new(fg=theme.colour(role))
}

///|
/// The frame `widget` draws at `size` under `theme`, as its rows and as the
/// screen they were parsed back from: the rows are the snapshot, the screen
/// answers what colour each cell ended up.
fn frame(
  widget : &@widget.Widget,
  size : @geom.Size,
  theme : @design.Theme,
) -> (Array[String], @vt.Grid) raise {
  let tty = @driver.Headless::new(size)
  let ui = @app.App::new(tty, @app.leaf(1, widget), sheet=theme.sheet())
  ui.start()
  ui.refresh()
  ignore(ui.step())
  let screen = @vt.Grid::new(size.width, size.height)
  screen.write(tty.output())
  (screen.rows(), screen)
}

///|
/// The two palettes the frames below are drawn with, pinned: without this a
/// change to a theme would move the frames and the expectations together.
test "the palettes the frames are drawn with hold these colours" {
  assert_eq(@design.dark.colour(@design.Primary), @style.cyan)
  assert_eq(
    @design.light.colour(@design.Primary),
    @style.Colour::rgb(0, 102, 153),
  )
  assert_eq(@design.light.colour(@design.Text), @style.Colour::rgb(28, 32, 40))
}

///|
test "a slider draws the same frame in both themes, each in its own colours" {
  let dark = @design.dark
  let light = @design.light
  let (dark_rows, dark_screen) = frame(
    @widget.Slider::new(
      value=40,
      bar_style=ink(dark, Primary),
      thumb_style=ink(dark, Accent),
    ),
    @geom.Size::new(24, 1),
    dark,
  )
  let (light_rows, light_screen) = frame(
    @widget.Slider::new(
      value=40,
      bar_style=ink(light, Primary),
      thumb_style=ink(light, Accent),
    ),
    @geom.Size::new(24, 1),
    light,
  )
  assert_eq(dark_rows, [
    "━━━━━━━━●───────────  40",
  ])
  assert_eq(light_rows, dark_rows)
  assert_eq(dark_screen.at(0, 0).style.fg, dark.colour(Primary))
  assert_eq(light_screen.at(0, 0).style.fg, light.colour(Primary))
  assert_eq(dark_screen.at(8, 0).style.fg, dark.colour(Accent))
}

///|
test "a paginator draws the same frame in both themes, each in its own colours" {
  let dark = @design.dark
  let light = @design.light
  let (dark_rows, dark_screen) = frame(
    @widget.Paginator::new(
      page=2,
      pages=9,
      current_style=@style.Style::new(reverse=true, fg=dark.colour(Accent)),
    ),
    @geom.Size::new(24, 1),
    dark,
  )
  let (light_rows, light_screen) = frame(
    @widget.Paginator::new(
      page=2,
      pages=9,
      current_style=@style.Style::new(reverse=true, fg=light.colour(Accent)),
    ),
    @geom.Size::new(24, 1),
    light,
  )
  assert_eq(dark_rows, ["‹ 1 2 3 4 5 6 7 8 9  ›  "])
  assert_eq(light_rows, dark_rows)
  assert_eq(dark_screen.at(6, 0).style.fg, dark.colour(Accent))
  assert_eq(light_screen.at(6, 0).style.fg, light.colour(Accent))
}

///|
test "a key panel draws the same frame in both themes, each in its own colours" {
  let dark = @design.dark
  let light = @design.light
  let bindings : Array[(String, String)] = [
    ("ctrl+p", "command palette"),
    ("ctrl+s", "save the file"),
  ]
  let (dark_rows, dark_screen) = frame(
    @widget.KeyPanel::new(
      bindings~,
      key_style=ink(dark, Primary),
      note_style=ink(dark, Muted),
    ),
    @geom.Size::new(60, 1),
    dark,
  )
  let (light_rows, light_screen) = frame(
    @widget.KeyPanel::new(
      bindings~,
      key_style=ink(light, Primary),
      note_style=ink(light, Muted),
    ),
    @geom.Size::new(60, 1),
    light,
  )
  assert_eq(dark_rows, [
    "ctrl+p command palette        ctrl+s save the file          ",
  ])
  assert_eq(light_rows, dark_rows)
  assert_eq(dark_screen.at(0, 0).style.fg, dark.colour(Primary))
  assert_eq(light_screen.at(0, 0).style.fg, light.colour(Primary))
}

///|
test "a calendar draws the same frame in both themes, each in its own colours" {
  let dark = @design.dark
  let light = @design.light
  let (dark_rows, dark_screen) = frame(
    @widget.Calendar::on(
      2026,
      3,
      7,
      style=ink(dark, Text),
      title_style=ink(dark, Primary),
    ),
    @geom.Size::new(21, 8),
    dark,
  )
  let (light_rows, light_screen) = frame(
    @widget.Calendar::on(
      2026,
      3,
      7,
      style=ink(light, Text),
      title_style=ink(light, Primary),
    ),
    @geom.Size::new(21, 8),
    light,
  )
  assert_eq(dark_rows[0], "March 2026           ")
  assert_eq(dark_rows[3], " 2  3  4  5  6  7  8 ")
  assert_eq(light_rows, dark_rows)
  assert_eq(dark_screen.at(0, 0).style.fg, dark.colour(Primary))
  assert_eq(light_screen.at(0, 0).style.fg, light.colour(Primary))
}

///|
test "a hex view draws the same frame in both themes, each in its own colours" {
  let dark = @design.dark
  let light = @design.light
  let (dark_rows, dark_screen) = frame(
    @widget.HexView::new(
      data=b"Hello!",
      offset_style=ink(dark, Muted),
      ascii_style=ink(dark, Accent),
    ),
    @geom.Size::new(80, 1),
    dark,
  )
  let (light_rows, light_screen) = frame(
    @widget.HexView::new(
      data=b"Hello!",
      offset_style=ink(light, Muted),
      ascii_style=ink(light, Accent),
    ),
    @geom.Size::new(80, 1),
    light,
  )
  assert_eq(
    dark_rows[0],
    "00000000  48 65 6c 6c 6f 21                                  Hello!             ",
  )
  assert_eq(light_rows, dark_rows)
  assert_eq(dark_screen.at(0, 0).style.fg, dark.colour(Muted))
  assert_eq(light_screen.at(0, 0).style.fg, light.colour(Muted))
}

///|
test "a diff draws the same frame in both themes, each in its own colours" {
  let dark = @design.dark
  let light = @design.light
  let patch : String =
    #|--- a/x
    #|+++ b/x
    #|@@ -1 +1 @@
    #|-old
    #|+new
  let (dark_rows, dark_screen) = frame(
    @widget.Diff::of_unified(
      patch,
      added_style=ink(dark, Success),
      removed_style=ink(dark, Error),
    ),
    @geom.Size::new(20, 5),
    dark,
  )
  let (light_rows, light_screen) = frame(
    @widget.Diff::of_unified(
      patch,
      added_style=ink(light, Success),
      removed_style=ink(light, Error),
    ),
    @geom.Size::new(20, 5),
    light,
  )
  assert_eq(dark_rows[3], "- old               ")
  assert_eq(dark_rows[4], "+ new               ")
  assert_eq(light_rows, dark_rows)
  assert_eq(dark_screen.at(0, 3).style.fg, dark.colour(Error))
  assert_eq(light_screen.at(0, 3).style.fg, light.colour(Error))
  assert_eq(dark_screen.at(0, 4).style.fg, dark.colour(Success))
}
