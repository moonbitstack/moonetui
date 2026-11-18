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
test "a generation is a frame, and a pause is not" {
  let size = @geom.Size::new(80, 24)
  let screen = @life.Screen::new()
  let field = screen.field
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@life.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("life/00 open", size, total.to_string(), ui.screen())
  // A glider, a blinker and a block: twelve cells, the first generation of the
  // demonstration a reader sees.
  assert_eq(field.alive(), 12)
  // The field opens on its title, and space starts it.
  assert_false(field.started())
  field.start()
  assert_true(field.started())
  assert_eq(field.gen(), 0)
  assert_true(field.alive_at(14, 6))
  field.step()
  shot(ui, driver, total, "life/01 one generation", size)
  assert_eq(field.gen(), 1)
  // The blinker stands up, the block and the glider keep their five cells.
  assert_true(field.alive_at(15, 5))
  assert_false(field.alive_at(14, 6))
  assert_eq(field.alive(), 12)
  // Paused: the field says so, and the clock no longer moves it.
  field.toggle()
  shot(ui, driver, total, "life/02 paused", size)
  field.step()
  assert_eq(field.gen(), 1)
}
