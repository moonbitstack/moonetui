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
test "a walk into the grass, two strikes, and a creature caught" {
  let size = @geom.Size::new(80, 22)
  let screen = @mon.Screen::new()
  let field = screen.field
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@mon.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("mon/00 route", size, total.to_string(), ui.screen())
  assert_true(field.mode == @mon.Walk)
  assert_eq(field.x, 3)
  assert_eq(field.y, 4)
  // Two steps north put the party in the tall grass of the second band, and
  // the fourth step into it brings something out.
  field.walk(0, -1)
  assert_eq(field.steps, 1)
  field.walk(0, -1)
  assert_eq(field.steps, 2)
  field.walk(1, 0)
  assert_eq(field.steps, 3)
  field.walk(1, 0)
  assert_eq(field.steps, 4)
  assert_true(field.mode == @mon.Fight)
  assert_true(field.enemy.length() > 0)
  shot(ui, driver, total, "mon/01 wild", size)
  // Two strikes and the wild one is down; the party's creature has taken a hit.
  let was = field.lead_beast().hp
  field.strike()
  assert_true(field.lead_beast().hp < was)
  shot(ui, driver, total, "mon/02 struck", size)
  let mut turns = 0
  while field.mode == @mon.Fight && turns < 12 {
    field.strike()
    turns = turns + 1
  }
  assert_true(field.mode == @mon.Won)
  assert_eq(field.caught, 7)
  shot(ui, driver, total, "mon/03 caught", size)
  // Space puts the grass back, and a potion heals the one in front.
  field.rest()
  assert_true(field.mode == @mon.Walk)
  let before = field.lead_beast().hp
  field.heal()
  assert_true(field.lead_beast().hp >= before)
  shot(ui, driver, total, "mon/04 healed", size)
}
