// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The UTF-16 units of `text` as hex, so what this test hands over survives
/// the trip through a test runner unchanged.
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
/// Whether frames are announced at all: `moon test` prints a report, and CI
/// sets `MOONETUI_INTEROP` to read the frames themselves.
fn interop_wanted() -> Bool {
  match @env.get_env_var("MOONETUI_INTEROP") {
    Some(_) => true
    None => false
  }
}

///|
/// Announces one frame of the game: its name, the emulators that can model it,
/// the bytes written since the game started, and the rows it is meant to show.
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
/// Draws the screen as it stands and announces it, so two emulators can be
/// asked what the same bytes show.
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
test "a game is played key by key, and every frame says which" {
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
  announce("snake/00 open", size, total.to_string(), ui.screen())
  assert_true(board.phase() == @snake.Playing)
  assert_eq(board.length(), 3)
  // Three cells in the middle, heading right: the apple is four cells ahead.
  assert_eq(board.head(), (15, 6))
  assert_eq(board.food_at(), (19, 6))
  // Two frames of the clock: the head is two cells further right, same length.
  board.step()
  board.step()
  shot(ui, driver, total, "snake/01 moving", size)
  assert_eq(board.head(), (17, 6))
  assert_eq(board.length(), 3)
  // The apple is put where the head will be, so the next frame takes it.
  let (x, y) = board.head()
  board.place_food(board.cell_at(x + 1, y))
  board.step()
  shot(ui, driver, total, "snake/02 ate", size)
  assert_eq(board.score(), 1)
  assert_eq(board.length(), 4)
  // Pause: the board says so, and the clock no longer moves the snake.
  board.toggle_pause()
  shot(ui, driver, total, "snake/03 paused", size)
  board.step()
  assert_eq(board.head(), (18, 6))
  assert_true(board.phase() == @snake.Paused)
  board.toggle_pause()
  // Up, into the top wall: the game ends, and the screen says how it ended.
  board.turn(0)
  for _ in 0..<12 {
    board.step()
  }
  shot(ui, driver, total, "snake/04 over", size)
  assert_true(board.phase() == @snake.Over)
  assert_true(board.score() >= 1)
  // Again: a new game, in the middle, with nothing eaten yet.
  board.restart()
  shot(ui, driver, total, "snake/05 again", size)
  assert_true(board.phase() == @snake.Playing)
  assert_eq(board.score(), 0)
  assert_eq(board.length(), 3)
}
