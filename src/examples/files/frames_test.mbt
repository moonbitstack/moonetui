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
test "three columns: where from, what is here, what is next" {
  let size = @geom.Size::new(90, 18)
  let screen = @files.Screen::new()
  let files = screen.files
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@files.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("files/00 root", size, total.to_string(), ui.screen())
  assert_eq(files.selection(), "src/")
  assert_eq(files.depth(), 0)
  shot(ui, driver, total, "files/01 same", size)
  assert_eq(files.selection(), "src/")
}
