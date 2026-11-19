// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn demo_state(production~ : Bool = false) -> @shell.State {
  let state = @shell.State::new(
    if production {
      "billing"
    } else {
      "demo"
    },
    if production {
      @config.Engine::Postgres
    } else {
      @config.Engine::Sqlite
    },
    if production {
      @sqlkit.Dialect::Postgres
    } else {
      @sqlkit.Dialect::Sqlite
    },
    false,
    production,
    @keymap.Keymap::default(),
  )
  state.tables = [
    { schema: None, name: "customers", is_view: false, },
    { schema: None, name: "orders", is_view: false, },
    { schema: None, name: "products", is_view: false, },
    { schema: None, name: "order_items", is_view: false, },
    { schema: None, name: "monthly_sales", is_view: true, },
  ]
  state
}

///|
fn orders() -> @table.Page {
  let rows = [
    ["1001", "Ada Lovelace", "142.50", "paid", "2026-11-02"],
    ["1002", "Alan Turing", "38.00", "shipped", "2026-11-03"],
    ["1003", "Grace Hopper", "1290.00", "paid", "2026-11-05"],
    ["1004", "Edsger Dijkstra", "15.75", "refunded", "2026-11-08"],
    ["1005", "Barbara Liskov", "264.10", "pending", "2026-11-11"],
    ["1006", "Donald Knuth", "512.00", "paid", "2026-11-14"],
    ["1007", "Frances Allen", "77.30", "shipped", "2026-11-17"],
  ]
  @table.Page::new(
    None,
    "orders",
    ["id", "customer", "total", "status", "placed"],
    rows.map(row => row.map(@table.Cell::of)),
    ["id"],
  )
}

///|
fn customers() -> @table.Page {
  let rows = [
    ["1", "Ada Lovelace", "London"],
    ["2", "Alan Turing", "Manchester"],
    ["3", "Grace Hopper", "Arlington"],
    ["4", "Edsger Dijkstra", "Nuenen"],
  ]
  @table.Page::new(
    None,
    "customers",
    ["id", "name", "city"],
    rows.map(row => row.map(@table.Cell::of)),
    ["id"],
  )
}

///|
/// The window as the loop in `main` drives it: the state moved, the widgets
/// brought up to it, the tree swapped when the layout changed, one frame drawn.
fn shot(
  ui : @app.App[@driver.Headless],
  driver : @driver.Headless,
  screen : @ui.Screen,
  total : StringBuilder,
  name : String,
  size : @geom.Size,
  pane~ : Int32 = 0,
  swap~ : Bool = false,
) -> Unit raise {
  screen.refresh()
  if swap {
    ui.swap_root(screen.node())
  }
  let mut tries = 0
  while ui.focused() != @ui.pane_id(pane) && tries < 8 {
    ui.focus_next(1)
    tries = tries + 1
  }
  driver.clear_output()
  ui.refresh()
  ignore(ui.step())
  total.write_string(driver.output())
  @frames.announce(name, size, total.to_string(), ui.screen())
}

///|
test "the tables, a table open, two panes, the palette and the key help" {
  let size = @geom.Size::new(110, 30)
  let state = demo_state()
  let screen = @ui.Screen::new(state)
  screen.refresh()
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.node(), sheet=@ui.sheet(), quit=[
    @app.ctrl_c,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  shot(ui, driver, screen, total, "dbmux/00 tables", size)
  assert_true(ui.screen().join("\n").contains("monthly_sales"))
  state.show_page(orders())
  shot(ui, driver, screen, total, "dbmux/01 orders", size)
  assert_true(ui.screen().join("\n").contains("Grace Hopper"))
  state.split(@shell.Layout::SplitVertical)
  state.show_page(customers())
  shot(
    ui,
    driver,
    screen,
    total,
    "dbmux/02 split",
    size,
    pane=state.pane,
    swap=true,
  )
  assert_true(ui.screen().join("\n").contains("Manchester"))
  state.unsplit()
  ignore(state.press("C-p"))
  shot(ui, driver, screen, total, "dbmux/03 palette", size, swap=true)
  assert_true(state.mode is @shell.Mode::Palette)
  // The query takes the terminal's own cursor, a blinking bar.
  assert_true(driver.output().contains(" q"))
  assert_true(driver.output().contains("[5 q"))
  ignore(state.press("esc"))
  ignore(state.press("?"))
  shot(ui, driver, screen, total, "dbmux/04 keys", size)
  assert_true(state.mode is @shell.Mode::Help)
  ignore(state.press("esc"))
  state.focus = @shell.Focus::Editor
  screen
  .editor()
  .set_text(
    "select id, customer, total\nfrom orders\nwhere status = 'paid'  -- this month\n  and total > 100\norder by total desc;",
  )
  shot(ui, driver, screen, total, "dbmux/06 editor", size)
  // Normal mode: a blinking block on the first character, past the gutter.
  assert_true(driver.output().contains("[1 q"))
  assert_true(ui.screen().join("\n").contains("order by total desc"))
  state.focus = @shell.Focus::Grid
  state.mode = @shell.Mode::Preview
  state.preview = "UPDATE orders SET status = 'shipped' WHERE id = 1005;\nDELETE FROM orders WHERE id = 1004;"
  shot(ui, driver, screen, total, "dbmux/07 save", size)
  assert_true(ui.screen().join("\n").contains("2 statements"))
}

///|
test "a production connection says so before anything else" {
  let size = @geom.Size::new(110, 30)
  let state = demo_state(production=true)
  state.show_page(orders())
  let screen = @ui.Screen::new(state)
  screen.refresh()
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.node(), sheet=@ui.sheet(), quit=[
    @app.ctrl_c,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  shot(ui, driver, screen, total, "dbmux/05 production", size)
  assert_true(ui.screen()[0].contains("PRODUCTION"))
}
