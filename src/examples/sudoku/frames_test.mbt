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
test "the givens hold, a digit goes in, and a clash is marked" {
  let size = @geom.Size::new(80, 22)
  let screen = @sudoku.Screen::new()
  let board = screen.board
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@sudoku.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("sudoku/00 open", size, total.to_string(), ui.screen())
  assert_eq(board.cursor(), (2, 0))
  assert_eq(board.cell(0, 0), 5)
  // A blank takes a digit; a given does not move.
  assert_eq(board.cell(2, 0), 0)
  board.write(9)
  assert_eq(board.cell(2, 0), 9)
  board.steer(-2, 0)
  board.write(4)
  assert_eq(board.cell(0, 0), 5)
  shot(ui, driver, total, "sudoku/01 wrote", size)
  // A four already sits at the start of row five: another one is a clash.
  board.steer(1, 4)
  board.write(4)
  assert_true(board.clash(1, 4))
  shot(ui, driver, total, "sudoku/02 clash", size)
  assert_eq(board.stage(), 0)
}
