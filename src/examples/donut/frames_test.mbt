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
/// How much of a frame is not a space: a torus that failed to project leaves an
/// empty grid, which is the failure this test is for.
fn ink(rows : Array[String]) -> Int32 {
  let mut count = 0
  for row in rows {
    for i in 0..<row.length() {
      if row[i] != ' ' {
        count = count + 1
      }
    }
  }
  count
}

///|
test "the torus turns, and holding it stops the turning" {
  let size = @geom.Size::new(80, 24)
  let screen = @donut.Screen::new()
  let donut = screen.donut
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@donut.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("donut/00 open", size, total.to_string(), ui.screen())
  // A torus, not a blank grid: the first frame has already drawn itself.
  assert_true(ink(donut.frame()) > 120)
  let first = donut.angle()
  donut.spin()
  donut.spin()
  shot(ui, driver, total, "donut/01 turning", size)
  assert_true(donut.angle() > first)
  // Held: the angle stays, and so does the frame.
  donut.toggle()
  let held = donut.angle()
  donut.spin()
  shot(ui, driver, total, "donut/02 held", size)
  assert_eq(donut.angle(), held)
}
