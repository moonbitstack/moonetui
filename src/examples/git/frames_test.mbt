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
  @frames.announce("git/00 open", size, total.to_string(), ui.screen())
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
