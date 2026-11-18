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
test "four regions, one page, and a clock that can be held" {
  let size = @geom.Size::new(100, 20)
  let screen = @top.Screen::new()
  let monitor = screen.monitor
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@top.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("top/00 open", size, total.to_string(), ui.screen())
  assert_eq(monitor.tick(), 0)
  // Six readings: the bars, the charts and the table all move with the tick.
  for _ in 0..<6 {
    monitor.step()
  }
  shot(ui, driver, total, "top/01 running", size)
  assert_eq(monitor.tick(), 6)
  // Held: a step does nothing, and the title says so.
  monitor.toggle()
  monitor.step()
  shot(ui, driver, total, "top/02 held", size)
  assert_eq(monitor.tick(), 6)
}
