// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

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
  @frames.announce(name, size, total.to_string(), ui.screen())
}

///|
test "a piece falls, turns, and settles into the board" {
  let size = @geom.Size::new(80, 24)
  let screen = @blocks.Screen::new()
  let grid = screen.grid
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@blocks.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("blocks/00 title", size, total.to_string(), ui.screen())
  assert_true(grid.stage() == @blocks.Title)
  grid.start()
  assert_true(grid.stage() == @blocks.Playing)
  assert_eq(grid.piece().length(), 4)
  shot(ui, driver, total, "blocks/01 falling", size)
  // Turn and step aside: the piece is still four cells and still on the board.
  grid.turn()
  grid.shift(-1)
  assert_eq(grid.piece().length(), 4)
  shot(ui, driver, total, "blocks/02 turned", size)
  // Dropped to the floor: it settles, and a new piece comes in at the top.
  for _ in 0..<20 {
    grid.drop()
  }
  shot(ui, driver, total, "blocks/03 settled", size)
  assert_true(grid.stage() == @blocks.Playing)
  assert_eq(grid.piece().length(), 4)
}
