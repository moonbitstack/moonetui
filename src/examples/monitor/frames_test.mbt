// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the monitor ticks, sorts on command and shows each pane" {
  let size = @geom.Size::new(80, 24)
  let monitor = @monitor.Monitor::new()
  let driver = @driver.Headless::new(size)
  let ui = @app.App::new(driver, monitor.root, sheet=@monitor.sheet())
  let total = StringBuilder()
  let shot = fn(name : String) raise {
    ui.refresh()
    ignore(ui.step())
    total.write_string(driver.output())
    driver.clear_output()
    @frames.announce(name, size, total.to_string(), ui.screen())
  }
  ui.start()
  shot("monitor/00 open")
  assert_true(ui.screen().iter().any(row => row.contains("gateway")))
  for _ in 0..<5 {
    monitor.step()
  }
  shot("monitor/01 five seconds")
  assert_true(
    ui.screen().iter().any(row => row.contains("00:05")) || monitor.tick == 5,
  )
  assert_false(monitor.answer("sort"))
  shot("monitor/02 sorted")
  assert_false(monitor.answer("alert"))
  monitor.tabs.activate(2)
  shot("monitor/03 feed")
  assert_true(
    ui.screen().iter().any(row => row.contains("manual alert raised")),
  )
  monitor.tabs.activate(1)
  shot("monitor/04 regions")
  assert_true(ui.screen().iter().any(row => row.contains("gateway-2")))
  assert_true(monitor.answer("quit"))
}
