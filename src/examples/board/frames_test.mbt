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
test "a task is ticked, the list moves, and a refresh slides the trace" {
  let size = @geom.Size::new(80, 24)
  let screen = @board.Screen::new()
  let board = screen.board
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@board.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("board/00 open", size, total.to_string(), ui.screen())
  assert_eq(board.done_count(), 1)
  assert_eq(board.clock_text(), "18:30:00")
  // Space ticks the row under the cursor, and the bar at the foot of the panel
  // counts it.
  board.toggle()
  assert_eq(board.done_count(), 2)
  shot(ui, driver, total, "board/01 ticked", size)
  // The arrows walk the list, and a second press takes the tick off again.
  board.shift(1)
  assert_true(board.done_of(1))
  board.toggle()
  assert_eq(board.done_count(), 1)
  shot(ui, driver, total, "board/02 walked", size)
  // A refresh reads the machine again: the trace moves one sample along.
  let first = board.load[0]
  board.refresh()
  assert_true(board.load[0] != first)
  shot(ui, driver, total, "board/03 refresh", size)
  // The clock counts in seconds, and a day wraps.
  board.tick(2000)
  assert_eq(board.clock_text(), "18:30:02")
  board.tick(86400 * 1000)
  assert_eq(board.seconds_text(), "02")
}
