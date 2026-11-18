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
test "a hold fills, a jump spends fuel, and the logbook keeps the count" {
  let size = @geom.Size::new(80, 22)
  let screen = @drift.Screen::new()
  let ship = screen.ship
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@drift.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("drift/00 sol", size, total.to_string(), ui.screen())
  assert_eq(ship.here, 0)
  assert_eq(ship.credits, 1240)
  assert_eq(ship.held(), 0)
  // A port's price is its own, and the same twice.
  assert_eq(ship.price(0), @drift.price_at(0, 0))
  assert_true(@drift.price_at(0, 1) != @drift.price_at(2, 1))
  // Buying fills the hold and spends the credits.
  let price = ship.price(0)
  ship.buy()
  assert_eq(ship.held(), 1)
  assert_eq(ship.credits, 1240 - price)
  // Selling it back at the same port gives the same money back.
  ship.sell()
  assert_eq(ship.held(), 0)
  assert_eq(ship.credits, 1240)
  // A course set, a jump made, and the fuel is gone with it.
  ship.buy()
  ship.walk(1)
  assert_eq(ship.course, 2)
  let cost = ship.cost_to(2)
  let fuel = ship.fuel
  ship.jump()
  assert_eq(ship.here, 2)
  assert_eq(ship.fuel, fuel - cost)
  shot(ui, driver, total, "drift/01 rigel", size)
  // A good bought at one port sells for the price of the next.
  ship.sell()
  assert_true(ship.credits > 0)
  ship.jump()
  assert_eq(ship.note, "the ship is already at Rigel")
  shot(ui, driver, total, "drift/02 dockside", size)
  // The hold fills at twenty, and the twenty-first purchase says so.
  let mut bought = 0
  while bought < 24 {
    ship.buy()
    bought = bought + 1
  }
  assert_eq(ship.held(), 20)
  assert_eq(ship.note, "the hold is full")
  shot(ui, driver, total, "drift/03 full", size)
  // An empty port's shelf: selling a good the hold has none of says so.
  ship.pick(1)
  ship.sell()
  assert_true(ship.note.length() > 0)
  assert_true(ship.wealth() >= ship.credits)
}
