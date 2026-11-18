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
test "a tail is held, a level is turned off, an error is found, and typed" {
  let size = @geom.Size::new(80, 22)
  let screen = @logs.Screen::new()
  let tail = screen.tail
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@logs.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("logs/00 tail", size, total.to_string(), ui.screen())
  assert_eq(tail.lines.length(), 200)
  assert_true(tail.count(@logs.Error) > 0)
  assert_eq(tail.visible().length(), 200)
  // Holding the tail stops it following, and the arrows walk the file.
  tail.hold()
  assert_false(tail.follow)
  tail.walk(-3)
  shot(ui, driver, total, "logs/01 held", size)
  // Turning information off leaves the warnings and the errors.
  tail.toggle(0)
  let without = tail.visible().length()
  assert_true(without < 200)
  assert_eq(without, tail.count(@logs.Warn) + tail.count(@logs.Error))
  shot(ui, driver, total, "logs/02 levels", size)
  // `e` jumps to the next error after the cursor and says which line it is on.
  tail.next_error()
  assert_true(tail.lines[tail.visible()[tail.cursor]].level == @logs.Error)
  shot(ui, driver, total, "logs/03 error", size)
  // Typing filters the file, and escape clears it again.
  tail.begin()
  for ch in [114, 101, 116, 114, 121] {
    tail.letter(ch)
  }
  tail.settle()
  assert_eq(tail.query, "retry")
  assert_true(tail.visible().length() < without)
  shot(ui, driver, total, "logs/04 typed", size)
  tail.clear()
  assert_eq(tail.visible().length(), without)
  // A letter back removes one, and the count follows.
  tail.begin()
  tail.letter(106)
  tail.letter(111)
  tail.rub()
  assert_eq(tail.query, "j")
  tail.clear()
  shot(ui, driver, total, "logs/05 cleared", size)
}
