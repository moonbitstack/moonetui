// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn app_state(read_only : Bool) -> @app.State {
  @app.State::new(
    "local",
    @config.Engine::Sqlite,
    @sqlkit.Dialect::Sqlite,
    read_only,
    false,
    @keymap.Keymap::default(),
  )
}

///|
fn app_page() -> @table.Page {
  @table.Page::new(
    None,
    "orders",
    ["id", "total"],
    [
      [@table.Cell::of("1"), @table.Cell::of("10")],
      [@table.Cell::of("2"), @table.Cell::of("20")],
    ],
    ["id"],
  )
}

///|
test "a read-only connection refuses a write and allows a read" {
  let state = app_state(true)
  assert_eq(
    state.refusal("delete from orders"),
    Some("this connection is read-only"),
  )
  assert_eq(state.refusal("select * from orders"), None)
}

///|
test "the production mark comes before the read-only one" {
  let state = @app.State::new(
    "prod",
    @config.Engine::Postgres,
    @sqlkit.Dialect::Postgres,
    false,
    true,
    @keymap.Keymap::default(),
  )
  assert_eq(state.badge(), "PRODUCTION")
  assert_eq(app_state(true).badge(), "read-only")
  assert_eq(app_state(false).badge(), "")
}

///|
test "opening a table twice keeps one tab" {
  let state = app_state(false)
  state.show_page(app_page())
  state.show_page(app_page())
  assert_eq(state.tabs.length(), 1)
  assert_eq(state.focus, @app.Focus::Grid)
}

///|
test "saving previews the statements, and a yes sends them" {
  let state = app_state(false)
  state.show_page(app_page())
  let grid = state.grid().unwrap()
  grid.set_cell(0, "total", @table.Cell::of("11"))
  let commands = state.press("C-s")
  assert_eq(commands.length(), 0)
  assert_eq(state.mode, @app.Mode::Preview)
  assert_eq(
    state.preview.contains("UPDATE \"orders\" SET \"total\" = '11'"),
    true,
  )
  assert_eq(state.preview.contains("1 update"), true)
  ignore(state.press("y"))
  assert_eq(state.mode, @app.Mode::Confirm)
  let out = state.press("y")
  assert_eq(out.length(), 1)
  match out[0] {
    Save(statements~, ..) => assert_eq(statements.length(), 1)
    _ => fail("expected a save")
  }
}

///|
test "a read-only connection will not even preview a save" {
  let state = app_state(true)
  state.show_page(app_page())
  state.grid().unwrap().set_cell(0, "total", @table.Cell::of("11"))
  ignore(state.press("C-s"))
  assert_eq(state.mode, @app.Mode::Browse)
  assert_eq(state.message, "this connection is read-only")
}

///|
test "a save with nothing changed says so" {
  let state = app_state(false)
  state.show_page(app_page())
  ignore(state.press("C-s"))
  assert_eq(state.message, "nothing to save")
}

///|
test "a filter is typed on the prompt line and becomes the grid's WHERE" {
  let state = app_state(false)
  state.show_page(app_page())
  ignore(state.press("f"))
  assert_eq(state.mode, @app.Mode::Typing)
  for key in ["t", "o", "t", "a", "l", ">", "5"] {
    ignore(state.press(key))
  }
  let out = state.press("enter")
  assert_eq(state.grid().unwrap().filter, "total>5")
  match out[0] {
    Reload => ()
    _ => fail("a new filter reloads the page")
  }
}

///|
test "the cursor's cell becomes the filter" {
  let state = app_state(false)
  state.show_page(app_page())
  state.grid().unwrap().step(1, 1)
  let out = state.press("F")
  assert_eq(state.grid().unwrap().filter, "\"total\" = '20'")
  match out[0] {
    Reload => ()
    _ => fail("a cell filter reloads the page")
  }
}

///|
test "a marked row and an added row reach the save" {
  let state = app_state(false)
  state.show_page(app_page())
  let grid = state.grid().unwrap()
  grid.toggle_delete(0)
  ignore(grid.add_row())
  grid.set_cell(2, "id", @table.Cell::of("3"))
  ignore(state.press("C-s"))
  assert_eq(state.preview.contains("DELETE FROM \"orders\""), true)
  assert_eq(state.preview.contains("INSERT INTO \"orders\""), true)
}

///|
test "the palette narrows as letters are typed" {
  let state = app_state(false)
  ignore(state.press("C-p"))
  assert_eq(state.mode, @app.Mode::Palette)
  for key in ["s", "a", "v"] {
    ignore(state.press(key))
  }
  let matches = state.palette_matches()
  assert_eq(matches.length() > 0, true)
  assert_eq(matches[0].contains("save"), true)
}

///|
test "the help panel is a key away and goes away again" {
  let state = app_state(false)
  ignore(state.press("?"))
  assert_eq(state.mode, @app.Mode::Help)
  ignore(state.press("esc"))
  assert_eq(state.mode, @app.Mode::Browse)
}

///|
test "tabs turn and close" {
  let state = app_state(false)
  state.show_page(app_page())
  state.show_page(
    @table.Page::new(None, "users", ["id"], [[@table.Cell::of("1")]], ["id"]),
  )
  assert_eq(state.tabs.length(), 2)
  ignore(state.press("gt"))
  assert_eq(state.tab, 0)
  ignore(state.press("C-w"))
  assert_eq(state.tabs.length(), 1)
}

///|
test "the status line counts what is on screen" {
  let state = app_state(false)
  state.show_page(app_page())
  assert_eq(state.status(), "1-2 · 2 columns")
  state.grid().unwrap().set_cell(0, "total", @table.Cell::of("11"))
  assert_eq(state.status(), "1-2 · 2 columns · unsaved changes")
}
