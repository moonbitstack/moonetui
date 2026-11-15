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
test "three panes, a tab between them, and a file that stages" {
  let size = @geom.Size::new(100, 18)
  let screen = @git.Screen::new()
  let repo = screen.repo
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@git.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("git/00 open", size, total.to_string(), ui.screen())
  assert_eq(repo.focus(), 1)
  assert_true(repo.selection().contains("tree, not the list"))
  // A tab lands on the file pane, where a space stages the row.
  repo.next_pane()
  assert_eq(repo.focus(), 2)
  assert_false(repo.staged(0))
  repo.toggle()
  assert_true(repo.staged(0))
  shot(ui, driver, total, "git/01 staged", size)
  // One down, one more stage: the cursor moves inside the pane it is in.
  repo.shift(1)
  repo.toggle()
  shot(ui, driver, total, "git/02 two staged", size)
  assert_true(repo.staged(0))
  assert_true(repo.staged(1))
  assert_false(repo.staged(2))
}
