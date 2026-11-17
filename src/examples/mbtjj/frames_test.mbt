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
/// One key, and the frame it draws kept: a stream that loses a frame makes the
/// screen an emulator replays disagree with the one the application holds, and
/// the disagreement is the test's, not the application's.
fn press(
  ui : @app.App[@driver.Headless],
  driver : @driver.Headless,
  total : StringBuilder,
  text : String,
) -> Unit raise {
  driver.push(key(text))
  ignore(ui.step())
  total.write_string(driver.output())
  driver.clear_output()
}

///|
fn shot(
  ui : @app.App[@driver.Headless],
  driver : @driver.Headless,
  total : StringBuilder,
  name : String,
  size : @geom.Size,
) -> Unit raise {
  ui.refresh()
  ignore(ui.step())
  total.write_string(driver.output())
  driver.clear_output()
  announce(name, size, total.to_string(), ui.screen())
}

///|
/// The whole screen as one string, for a check about what is on it rather than
/// which row it is on.
fn screen_text(rows : Array[String]) -> String {
  let out = StringBuilder()
  for row in rows {
    out.write_string(row)
    out.write_string("\n")
  }
  out.to_string()
}

///|
/// One key, as a terminal would send it.
fn key(text : String) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<text.length() {
    out.push(text[i].to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
test "a jujutsu log: a cursor, a revset, a diff and the operations" {
  let size = @geom.Size::new(100, 18)
  let screen = @mbtjj.Screen::new()
  let repo = screen.repo
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@mbtjj.sheet(), quit=[
    @app.ctrl_c,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("mbtjj/00 open", size, total.to_string(), ui.screen())
  // The cursor starts on the working copy, which is the only row marked `@`.
  let first = match repo.selection() {
    Some(change) => change
    None => abort("no revision under the cursor")
  }
  assert_eq(first.change_id, "qpvuntsm")
  assert_true(ui.screen()[0].contains("mbtjj"))
  // Two rows down: the log moves, and the change beside it says whose it is.
  press(ui, driver, total, "\u{1b}[B")
  press(ui, driver, total, "\u{1b}[B")
  let third = match repo.selection() {
    Some(change) => change
    None => abort("no revision under the cursor")
  }
  assert_eq(third.change_id, "zslqopmn")
  assert_true(screen_text(ui.screen()).contains("zslqopmn"))
  // `d` shows what the change does rather than what it is.
  press(ui, driver, total, "d")
  assert_true(repo.diff())
  assert_true(ui.screen()[2].contains("DIFF"))
  assert_true(screen_text(ui.screen()).contains("merge of 2 revisions"))
  shot(ui, driver, total, "mbtjj/01 diff", size)
  // `/` starts a revset; the letters narrow the log to the revision they name.
  press(ui, driver, total, "/")
  assert_true(repo.typing())
  for letter in ["c", "o", "n", "f"] {
    press(ui, driver, total, letter)
  }
  assert_eq(repo.filter(), "conf")
  assert_eq(repo.pickable().length(), 1)
  let found = match repo.selection() {
    Some(change) => change
    None => abort("no revision under the cursor")
  }
  assert_eq(found.change_id, "wqnwkozp")
  assert_true(ui.screen()[0].contains("revset conf"))
  shot(ui, driver, total, "mbtjj/02 revset", size)
  // Escape empties the revset and hands the keyboard back to the log.
  // Escape on its own is the start of a sequence until the terminal says
  // nothing more is coming: one more step with an empty read flushes it.
  press(ui, driver, total, "\u{1b}")
  press(ui, driver, total, "")
  assert_eq(repo.typing(), false)
  assert_eq(repo.filter(), "")
  assert_eq(repo.pickable().length(), 9)
  // `o` opens the operations the repository has seen.
  press(ui, driver, total, "o")
  assert_true(repo.ops())
  let last = ui.screen()[size.height - 2]
  assert_true(last.contains("18:47"))
  shot(ui, driver, total, "mbtjj/03 operations", size)
  // `q` leaves.
  press(ui, driver, total, "q")
  assert_eq(ui.screen_depth(), 1)
  assert_eq(repo.ops(), true)
}
