// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn hex16(text : String) -> String {
  let out = StringBuilder()
  let digit = fn(v : Int32) {
    if v < 10 {
      (48 + v).unsafe_to_char()
    } else {
      (97 + v - 10).unsafe_to_char()
    }
  }
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    out.write_char(digit(unit / 0x1000 % 16))
    out.write_char(digit(unit / 0x100 % 16))
    out.write_char(digit(unit / 0x10 % 16))
    out.write_char(digit(unit % 16))
  }
  out.to_string()
}

///|
fn interop_wanted() -> Bool {
  match @env.get_env_var("MOONETUI_INTEROP") {
    Some(_) => true
    None => false
  }
}

///|
fn announce(
  name : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  if !interop_wanted() {
    return
  }
  let line = StringBuilder()
  line.write_string(
    "interop\t" +
    name +
    "\tpyte,tmux\t" +
    size.width.to_string() +
    "\t" +
    size.height.to_string() +
    "\t" +
    hex16(stream),
  )
  for row in rows {
    line.write_string("\t" + hex16(row))
  }
  println(line.to_string())
}

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
  announce(name, size, total.to_string(), ui.screen())
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
  announce("board/00 open", size, total.to_string(), ui.screen())
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
