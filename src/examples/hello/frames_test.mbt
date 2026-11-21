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
test "the list moves under the arrows and the field takes what it chose" {
  let size = @geom.Size::new(80, 24)
  let screen = @hello.Screen::new()
  // One chunk per key and an empty one after it: the frame a key produces is
  // drawn on the step after its handler answered.
  let driver = @driver.Headless::new(
    size,
    script=[b"\x1b[B", b"", b"\x1b[B", b"", b"\x0d", b""],
    tick=16,
  )
  let ui = @app.App::new(driver, screen.root, base=@style.Style::new(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("hello/00 open", size, total.to_string(), ui.screen())
  let opening = ui.screen()
  assert_true(opening[0].contains("moonetui"))
  assert_true(opening[size.height - 1].contains("up down"))
  assert_eq(screen.chosen(), 0)
  // The first arrow moves the list, and the report hands the item to the field.
  ignore(ui.step())
  for report in ui.drain() {
    match report {
      Selected(index~, ..) => screen.choose(index)
      _ => ()
    }
    ui.refresh()
  }
  assert_eq(screen.chosen(), 1)
  shot(ui, driver, total, "hello/01 second", size)
  assert_true(ui.screen().iter().any(row => row.contains("beta")))
  // The second arrow and the return key leave the list on the third item.
  ignore(ui.step())
  for report in ui.drain() {
    match report {
      Selected(index~, ..) => screen.choose(index)
      _ => ()
    }
    ui.refresh()
  }
  ignore(ui.step())
  for report in ui.drain() {
    match report {
      Selected(index~, ..) => screen.choose(index)
      _ => ()
    }
    ui.refresh()
  }
  assert_eq(screen.chosen(), 2)
  shot(ui, driver, total, "hello/02 chosen", size)
  assert_true(ui.screen().iter().any(row => row.contains("gamma")))
}
