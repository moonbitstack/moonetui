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
test "the page scrolls to its end and back, and the band and key bar stay put" {
  let size = @geom.Size::new(88, 20)
  let screen = @read.Screen::new()
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@read.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("read/00 open", size, total.to_string(), ui.screen())
  let opening = ui.screen()
  assert_true(opening[0].contains("read"))
  assert_true(opening[2].contains("moonetui"))
  assert_true(opening[size.height - 1].contains("quit"))
  // A table whose columns line up: the widget lays it out, the pipes are gone.
  driver.push(b"[F")
  shot(ui, driver, total, "read/01 end", size)
  let end = ui.screen()
  assert_true(end[0] == opening[0])
  assert_true(end[size.height - 1] == opening[size.height - 1])
  assert_true(end[2] != opening[2])
  assert_true(end.iter().any(row => row.contains("charts")))
  assert_false(end.iter().any(row => row.contains("|:--")))
  driver.push(b"[H")
  shot(ui, driver, total, "read/02 back", size)
  assert_eq(ui.screen(), opening)
}
