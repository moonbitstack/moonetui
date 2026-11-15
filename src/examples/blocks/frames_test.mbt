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
test "a piece falls, turns, and settles into the board" {
  let size = @geom.Size::new(80, 24)
  let screen = @blocks.Screen::new()
  let grid = screen.grid
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@blocks.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("blocks/00 title", size, total.to_string(), ui.screen())
  assert_true(grid.stage() == @blocks.Title)
  grid.start()
  assert_true(grid.stage() == @blocks.Playing)
  assert_eq(grid.piece().length(), 4)
  shot(ui, driver, total, "blocks/01 falling", size)
  // Turn and step aside: the piece is still four cells and still on the board.
  grid.turn()
  grid.shift(-1)
  assert_eq(grid.piece().length(), 4)
  shot(ui, driver, total, "blocks/02 turned", size)
  // Dropped to the floor: it settles, and a new piece comes in at the top.
  for _ in 0..<20 {
    grid.drop()
  }
  shot(ui, driver, total, "blocks/03 settled", size)
  assert_true(grid.stage() == @blocks.Playing)
  assert_eq(grid.piece().length(), 4)
}
