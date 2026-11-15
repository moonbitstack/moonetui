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
test "a game has a title, a run, sparks, and a score screen" {
  let size = @geom.Size::new(80, 24)
  let screen = @snake.Screen::new()
  let board = screen.board
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@snake.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("snake/00 title", size, total.to_string(), ui.screen())
  // A game opens on its title, with no snake on the field.
  assert_true(board.phase() == @snake.Title)
  board.start()
  assert_true(board.phase() == @snake.Playing)
  assert_eq(board.length(), 3)
  assert_eq(board.head(), (23, 8))
  shot(ui, driver, total, "snake/01 playing", size)
  // The apple is put where the head will be: eating it throws six sparks.
  let (x, y) = board.head()
  board.place_food(board.cell_at(x + 1, y))
  board.step()
  assert_eq(board.score(), 1)
  assert_eq(board.sparks(), 6)
  shot(ui, driver, total, "snake/02 ate", size)
  // The sparks burn out in four frames of the clock.
  for _ in 0..<4 {
    board.drift()
  }
  assert_eq(board.sparks(), 0)
  // Paused: the clock stops, and the field says so.
  board.toggle_pause()
  let held = board.head()
  board.step()
  assert_eq(board.head(), held)
  shot(ui, driver, total, "snake/03 paused", size)
  board.toggle_pause()
  // Into the top wall: the run ends, and the score screen names the score.
  board.turn(0)
  for _ in 0..<12 {
    board.step()
  }
  assert_true(board.phase() == @snake.Over)
  shot(ui, driver, total, "snake/04 over", size)
  assert_eq(board.best(), 1)
  // Again, from the score screen.
  board.start()
  assert_true(board.phase() == @snake.Playing)
  assert_eq(board.score(), 0)
  shot(ui, driver, total, "snake/05 again", size)
}
