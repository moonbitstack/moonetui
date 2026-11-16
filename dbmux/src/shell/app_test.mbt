// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn app_state(read_only : Bool) -> @shell.State {
  @shell.State::new(
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
  let state = @shell.State::new(
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
  assert_eq(state.panes[0].tabs.length(), 1)
  assert_eq(state.focus, @shell.Focus::Grid)
}

///|
test "saving previews the statements, and a yes sends them" {
  let state = app_state(false)
  state.show_page(app_page())
  let grid = state.grid().unwrap()
  grid.set_cell(0, "total", @table.Cell::of("11"))
  let commands = state.press("C-s")
  assert_eq(commands.length(), 0)
  assert_eq(state.mode, @shell.Mode::Preview)
  assert_eq(
    state.preview.contains("UPDATE \"orders\" SET \"total\" = '11'"),
    true,
  )
  assert_eq(state.preview.contains("1 update"), true)
  ignore(state.press("y"))
  assert_eq(state.mode, @shell.Mode::Confirm)
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
  assert_eq(state.mode, @shell.Mode::Browse)
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
  assert_eq(state.mode, @shell.Mode::Typing)
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
  assert_eq(state.mode, @shell.Mode::Palette)
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
  assert_eq(state.mode, @shell.Mode::Help)
  ignore(state.press("esc"))
  assert_eq(state.mode, @shell.Mode::Browse)
}

///|
test "tabs turn and close" {
  let state = app_state(false)
  state.show_page(app_page())
  state.show_page(
    @table.Page::new(None, "users", ["id"], [[@table.Cell::of("1")]], ["id"]),
  )
  assert_eq(state.panes[0].tabs.length(), 2)
  ignore(state.press("gt"))
  assert_eq(state.panes[0].tab, 0)
  ignore(state.press("C-w"))
  assert_eq(state.panes[0].tabs.length(), 1)
}

///|
test "the status line counts what is on screen" {
  let state = app_state(false)
  state.show_page(app_page())
  assert_eq(state.status(), "1-2 · 2 columns")
  state.grid().unwrap().set_cell(0, "total", @table.Cell::of("11"))
  assert_eq(state.status(), "1-2 · 2 columns · unsaved changes")
}

///|
test "a split shows the table on both sides, with a tab each" {
  let state = app_state(false)
  state.show_page(app_page())
  state.split(@shell.Layout::SplitVertical)
  assert_eq(state.panes.length(), 2)
  assert_eq(state.layout, @shell.Layout::SplitVertical)
  assert_eq(state.panes[1].tabs.length(), 1)
  assert_eq(state.pane_label(1), "orders")
}

///|
test "each pane keeps its own tabs" {
  let state = app_state(false)
  state.show_page(app_page())
  state.split(@shell.Layout::SplitVertical)
  state.other_pane()
  assert_eq(state.pane, 1)
  state.show_page(
    @table.Page::new(None, "users", ["id"], [[@table.Cell::of("1")]], ["id"]),
  )
  assert_eq(state.panes[0].tabs.length(), 1)
  assert_eq(state.panes[1].tabs.length(), 2)
  assert_eq(state.pane_label(0), "orders")
  assert_eq(state.pane_label(1), "users")
}

///|
test "a second split turns the divider" {
  let state = app_state(false)
  state.show_page(app_page())
  state.split(@shell.Layout::SplitVertical)
  state.split(@shell.Layout::SplitHorizontal)
  assert_eq(state.panes.length(), 2)
  assert_eq(state.layout, @shell.Layout::SplitHorizontal)
}

///|
test "closing the split keeps the pane that had the keyboard" {
  let state = app_state(false)
  state.show_page(app_page())
  state.split(@shell.Layout::SplitVertical)
  state.other_pane()
  state.unsplit()
  assert_eq(state.panes.length(), 1)
  assert_eq(state.pane, 0)
  assert_eq(state.layout, @shell.Layout::Single)
  assert_eq(state.panes[0].tabs.length(), 1)
}

///|
test "the split is said in the status line" {
  let state = app_state(false)
  state.show_page(app_page())
  state.split(@shell.Layout::SplitVertical)
  assert_eq(state.status(), "1-2 · 2 columns · 2 panes ⇔")
}

///|
test "the split keys reach the state through the keyboard" {
  let state = app_state(false)
  state.show_page(app_page())
  ignore(state.press("C-v"))
  assert_eq(state.layout, @shell.Layout::SplitVertical)
  ignore(state.press("C-x"))
  assert_eq(state.layout, @shell.Layout::SplitHorizontal)
  ignore(state.press("C-o"))
  assert_eq(state.pane, 1)
  ignore(state.press("C-q"))
  assert_eq(state.layout, @shell.Layout::Single)
}

///|
/// Clear the prompt's draft and type `text` into it.
fn type_over(state : @shell.State, text : String) -> Unit {
  for _ in 0..<state.draft.length() {
    ignore(state.press("backspace"))
  }
  for c in text {
    ignore(state.press(c.to_string()))
  }
}

///|
test "the page size is asked on the prompt line, and a new one reloads from the start" {
  let state = app_state(false)
  state.show_page(app_page())
  ignore(state.press("L"))
  assert_eq(state.draft, "100")
  type_over(state, "25")
  let out = state.press("enter")
  assert_eq(state.grid().unwrap().limit, 25)
  assert_eq(state.grid().unwrap().offset, 0L)
  assert_true(out[0] is Reload)
  // Nothing, or more than a page holds, is said and changes nothing.
  for bad in ["0", "abc", "10001"] {
    ignore(state.press("L"))
    type_over(state, bad)
    assert_eq(state.press("enter").length(), 0)
    assert_eq(state.grid().unwrap().limit, 25)
  }
}

///|
test "the columns shown are picked on the prompt line, and a hidden one comes back" {
  let state = app_state(false)
  state.show_page(app_page())
  ignore(state.press("C"))
  assert_eq(state.draft, "id, total")
  type_over(state, "total")
  ignore(state.press("enter"))
  assert_eq(state.grid().unwrap().hidden, ["id"])
  ignore(state.press("C"))
  assert_eq(state.draft, "total")
  type_over(state, "id, total, nope")
  ignore(state.press("enter"))
  assert_eq(state.grid().unwrap().hidden, [])
  // Naming no column of the table keeps what was shown.
  ignore(state.press("C"))
  type_over(state, "nope")
  ignore(state.press("enter"))
  assert_eq(state.grid().unwrap().hidden, [])
}

///|
test "the history steps back through the queries that ran, and forward to an empty editor" {
  let history = @shell.History::new()
  for q in ["select 1", "select 2", "select 2", "select 3"] {
    history.add(q)
  }
  assert_eq(history.back(), Some("select 3"))
  assert_eq(history.back(), Some("select 2"))
  assert_eq(history.back(), Some("select 1"))
  assert_eq(history.back(), None)
  assert_eq(history.forward(), Some("select 2"))
  assert_eq(history.forward(), Some("select 3"))
  assert_eq(history.forward(), Some(""))
  assert_eq(history.forward(), None)
}

///|
test "the history file is read back as it was written, multi-line queries and all" {
  let history = @shell.History::new()
  history.add("select *\n  from orders")
  history.add("delete from orders where id = 2")
  let again = @shell.History::new()
  again.load(history.text())
  assert_eq(again.back(), Some("delete from orders where id = 2"))
  assert_eq(again.back(), Some("select *\n  from orders"))
}

///|
test "the history keeps the newest queries up to its limit" {
  let history = @shell.History::new()
  for i in 0..<(@shell.history_limit + 3) {
    history.add("select \{i}")
  }
  let again = @shell.History::new()
  again.load(history.text())
  let mut oldest = ""
  while again.back() is Some(q) {
    oldest = q
  }
  assert_eq(oldest, "select 3")
}
