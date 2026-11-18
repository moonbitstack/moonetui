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
test "a reveal opens a cell, a flag marks one, and a mine ends the field" {
  let size = @geom.Size::new(80, 22)
  let screen = @sweep.Screen::new()
  let field = screen.field
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@sweep.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("sweep/00 open", size, total.to_string(), ui.screen())
  assert_eq(field.cursor(), (5, 5))
  assert_eq(field.opened(), 0)
  // The cursor sits on a mine; one row up is safe, and revealing it opens one.
  field.steer(0, -1)
  field.reveal()
  assert_eq(field.opened(), 1)
  shot(ui, driver, total, "sweep/01 revealed", size)
  // A flag on a hidden cell, and the same key takes it off again.
  field.steer(0, 1)
  field.toggle_flag()
  assert_true(field.flagged(5, 5))
  shot(ui, driver, total, "sweep/02 flagged", size)
  field.toggle_flag()
  assert_false(field.flagged(5, 5))
  // Revealing the mine ends the field, and the board shows every mine.
  field.reveal()
  assert_true(field.stage() == @sweep.Over)
  shot(ui, driver, total, "sweep/03 boom", size)
}
