// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn hex16(text : String) -> String {
  let out = StringBuilder()
  let digit = fn(v : Int32) {
    if v < 10 {
      (48 + v).unsafe_to_char()
    } else {
      (97 + v - 10).unsafe_to_char()
    }
  }
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    out.write_char(digit(unit / 0x1000 % 16))
    out.write_char(digit(unit / 0x100 % 16))
    out.write_char(digit(unit / 0x10 % 16))
    out.write_char(digit(unit % 16))
  }
  out.to_string()
}

///|
fn interop_wanted() -> Bool {
  match @env.get_env_var("MOONETUI_INTEROP") {
    Some(_) => true
    None => false
  }
}

///|
fn announce(
  name : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  if !interop_wanted() {
    return
  }
  let line = StringBuilder()
  line.write_string(
    "interop\t" +
    name +
    "\tpyte,tmux\t" +
    size.width.to_string() +
    "\t" +
    size.height.to_string() +
    "\t" +
    hex16(stream),
  )
  for row in rows {
    line.write_string("\t" + hex16(row))
  }
  println(line.to_string())
}

///|
fn shot(
  ui : @app.App[@driver.Headless],
  driver : @driver.Headless,
  total : StringBuilder,
  name : String,
  size : @geom.Size,
) -> Unit raise {
  driver.clear_output()
  ui.refresh()
  ignore(ui.step())
  total.write_string(driver.output())
  announce(name, size, total.to_string(), ui.screen())
}

///|
test "a slide moves tiles, a merge scores, and a wall is not a turn" {
  let size = @geom.Size::new(80, 24)
  let screen = @game2048.Screen::new()
  let grid = screen.grid
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@game2048.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("2048/00 open", size, total.to_string(), ui.screen())
  assert_eq(grid.cell(0, 0), 2)
  assert_eq(grid.cell(3, 0), 4)
  // Right: the two tiles travel to the right edge, nothing merges, and the
  // board adds one because something moved.
  grid.slide(1)
  shot(ui, driver, total, "2048/01 right", size)
  assert_eq(grid.cell(3, 0), 4)
  assert_eq(grid.cell(2, 0), 2)
  assert_eq(grid.score(), 0)
  // A set piece: two 2s side by side, slid left, become a 4 worth four points.
  grid.fill([2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
  grid.slide(3)
  shot(ui, driver, total, "2048/02 merged", size)
  assert_eq(grid.cell(0, 0), 4)
  assert_eq(grid.score(), 4)
  // A slide into a wall that changes nothing is not a turn: no score, no tile.
  let before = grid.score()
  grid.fill([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2])
  grid.slide(3)
  shot(ui, driver, total, "2048/03 wall", size)
  assert_eq(grid.cell(0, 3), 2)
  // Restart: the two tiles a new board has, and no score.
  grid.restart()
  shot(ui, driver, total, "2048/04 again", size)
  assert_eq(grid.score(), 0)
  assert_eq(grid.cell(0, 0), 2)
  assert_true(before >= 4)
}
