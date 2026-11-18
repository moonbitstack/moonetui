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
test "a block marches, and a bullet takes one of it" {
  let size = @geom.Size::new(80, 22)
  let screen = @invaders.Screen::new()
  let field = screen.field
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@invaders.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("invaders/00 title", size, total.to_string(), ui.screen())
  assert_true(field.stage() == @invaders.Title)
  field.start()
  assert_true(field.stage() == @invaders.Playing)
  assert_eq(field.lives(), 3)
  field.shoot()
  shot(ui, driver, total, "invaders/01 shot", size)
  // The block steps every third frame; twelve frames is four steps of march.
  for _ in 0..<12 {
    field.step()
  }
  shot(ui, driver, total, "invaders/02 marched", size)
  assert_true(field.left() != 0)
  assert_eq(field.lives(), 3)
}
