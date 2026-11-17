// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn orders() -> @table.Page {
  @table.Page::new(
    Some("public"),
    "orders",
    ["id", "user_id", "total", "note"],
    [
      [
        @table.Cell::of("1"),
        @table.Cell::of("42"),
        @table.Cell::of("10.50"),
        @table.Cell::none(),
      ],
      [
        @table.Cell::of("2"),
        @table.Cell::of("43"),
        @table.Cell::of("7.00"),
        @table.Cell::of("rush"),
      ],
    ],
    ["id"],
  )
}

///|
fn plain() -> @table.Page {
  @table.Page::new(
    None,
    "notes",
    ["body", "tag"],
    [
      [@table.Cell::of("a"), @table.Cell::of("x")],
      [@table.Cell::of("a"), @table.Cell::of("x")],
    ],
    [],
  )
}

///|
test "a cell changed and changed back leaves the table clean" {
  let grid = @table.Grid::new(orders())
  assert_eq(grid.is_dirty(), false)
  grid.set_cell(1, "total", @table.Cell::of("8.00"))
  assert_eq(grid.is_dirty(), true)
  assert_eq(grid.changed_cells(), 1)
  assert_eq(grid.cell(1, "total").text, "8.00")
  grid.set_cell(1, "total", @table.Cell::of("7.00"))
  assert_eq(grid.is_dirty(), false)
}

///|
test "an update carries the key and the old value it replaces" {
  let grid = @table.Grid::new(orders())
  grid.set_cell(1, "total", @table.Cell::of("8.00"))
  let plan = @table.plan(grid, @sqlkit.Dialect::Postgres)
  assert_eq(plan.updates, 1)
  assert_eq(plan.statements.length(), 1)
  assert_eq(
    plan.statements[0],
    "UPDATE \"public\".\"orders\" SET \"total\" = '8.00' WHERE \"id\" = '2'",
  )
  assert_eq(plan.summary(), "1 update")
}

///|
test "a table with no key matches the whole row it read" {
  let grid = @table.Grid::new(plain())
  grid.set_cell(0, "tag", @table.Cell::of("y"))
  let plan = @table.plan(grid, @sqlkit.Dialect::Sqlite)
  assert_eq(
    plan.statements[0],
    "UPDATE \"notes\" SET \"tag\" = 'y' WHERE \"body\" = 'a' AND \"tag\" = 'x'",
  )
}

///|
test "a NULL in the old row is asked for as IS NULL" {
  let grid = @table.Grid::new(orders())
  grid.set_cell(0, "note", @table.Cell::of("first"))
  let plan = @table.plan(grid, @sqlkit.Dialect::Mysql)
  assert_eq(
    plan.statements[0],
    "UPDATE `public`.`orders` SET `note` = 'first' WHERE `id` = '1'",
  )
  // and a row whose key is NULL is matched with IS NULL
  let nullable = @table.Page::new(
    None,
    "t",
    ["k", "v"],
    [[@table.Cell::none(), @table.Cell::of("1")]],
    ["k"],
  )
  let g2 = @table.Grid::new(nullable)
  g2.set_cell(0, "v", @table.Cell::of("2"))
  let p2 = @table.plan(g2, @sqlkit.Dialect::Postgres)
  assert_eq(
    p2.statements[0],
    "UPDATE \"t\" SET \"v\" = '2' WHERE \"k\" IS NULL",
  )
}

///|
test "an added row is one insert, a marked row one delete" {
  let grid = @table.Grid::new(orders())
  let row = grid.add_row()
  assert_eq(row, 2)
  grid.set_cell(2, "id", @table.Cell::of("3"))
  grid.set_cell(2, "user_id", @table.Cell::of("44"))
  grid.set_cell(2, "total", @table.Cell::of("1.00"))
  grid.toggle_delete(0)
  let plan = @table.plan(grid, @sqlkit.Dialect::SqlServer)
  assert_eq(plan.inserts, 1)
  assert_eq(plan.deletes, 1)
  assert_eq(
    plan.statements[0],
    "INSERT INTO [public].[orders] ([id], [user_id], [total], [note]) VALUES ('3', '44', '1.00', NULL)",
  )
  assert_eq(
    plan.statements[1],
    "DELETE FROM [public].[orders] WHERE [id] = '1'",
  )
  assert_eq(plan.summary(), "1 insert, 1 delete")
}

///|
test "an added row dropped before saving never reaches the database" {
  let grid = @table.Grid::new(orders())
  ignore(grid.add_row())
  assert_eq(grid.is_dirty(), true)
  grid.toggle_delete(2)
  assert_eq(grid.row_count(), 2)
  assert_eq(grid.is_dirty(), false)
}

///|
test "paging walks by the limit and stops at the first page" {
  let grid = @table.Grid::new(orders())
  assert_eq(grid.range_text(), "1-2")
  assert_eq(grid.turn_page(false), false)
  assert_eq(grid.turn_page(true), true)
  assert_eq(grid.offset, 100)
  assert_eq(grid.range_text(), "101-102")
  ignore(grid.turn_page(false))
  assert_eq(grid.offset, 0)
}

///|
test "a header is pressed through ascending, descending and off" {
  let grid = @table.Grid::new(orders())
  grid.press_column("total")
  assert_eq(grid.sort_mark("total"), "▲")
  grid.press_column("total")
  assert_eq(grid.sort_mark("total"), "▼")
  grid.press_column("total")
  assert_eq(grid.sort_mark("total"), "")
}

///|
test "a second sort column keeps the first" {
  let grid = @table.Grid::new(orders())
  grid.press_column("user_id")
  grid.press_column("total")
  assert_eq(grid.sorts.length(), 2)
  assert_eq(grid.sorts[0].column, "user_id")
  assert_eq(grid.sorts[1].column, "total")
}

///|
test "a hidden column leaves the screen but keeps its values" {
  let grid = @table.Grid::new(orders())
  grid.hidden.push("note")
  assert_eq(grid.visible().length(), 3)
  assert_eq(grid.visible_index("note"), None)
  assert_eq(grid.cell(1, "note").text, "rush")
}

///|
test "filtering by the cell under the cursor quotes the value" {
  let grid = @table.Grid::new(orders())
  grid.step(1, 1)
  assert_eq(
    grid.filter_for_cell(@sqlkit.Dialect::Postgres),
    Some("\"user_id\" = '43'"),
  )
  grid.step(-1, 0)
  grid.step(0, 2)
  assert_eq(
    grid.filter_for_cell(@sqlkit.Dialect::Postgres),
    Some("\"note\" IS NULL"),
  )
}

///|
test "reverting takes the changes back and leaves the page" {
  let grid = @table.Grid::new(orders())
  grid.set_cell(0, "total", @table.Cell::of("99"))
  ignore(grid.add_row())
  grid.revert()
  assert_eq(grid.is_dirty(), false)
  assert_eq(grid.cell(0, "total").text, "10.50")
  assert_eq(grid.row_count(), 2)
}

///|
/// A grid over one page, as the client builds it.
fn plan_grid(page : @table.Page) -> @table.Grid {
  @table.Grid::new(page)
}

///|
test "a changed hash field is one HSET, a marked row one HDEL" {
  let page = @table.Page::new(
    None,
    "user:1",
    ["field", "value"],
    [
      [@table.Cell::of("name"), @table.Cell::of("Ada")],
      [@table.Cell::of("city"), @table.Cell::of("London")],
    ],
    [],
  )
  let grid = plan_grid(page)
  grid.set_cell(0, "value", @table.Cell::of("Ada Lovelace"))
  grid.toggle_delete(1)
  let plan = @table.redis_plan(grid) catch {
    @table.Refused(text~) => abort(text)
  }
  assert_eq(plan.statements, [
    "HSET user:1 name \"Ada Lovelace\"", "HDEL user:1 city",
  ])
  assert_eq(plan.updates, 1)
  assert_eq(plan.deletes, 1)
}

///|
test "a value with a space is quoted, and one with both quotes is refused" {
  let page = @table.Page::new(
    None,
    "greeting",
    ["value"],
    [[@table.Cell::of("hello")]],
    [],
  )
  let grid = plan_grid(page)
  grid.set_cell(0, "value", @table.Cell::of("hello there"))
  let plan = @table.redis_plan(grid) catch {
    @table.Refused(text~) => abort(text)
  }
  assert_eq(plan.statements, ["SET greeting \"hello there\""])
  grid.set_cell(0, "value", @table.Cell::of("both \" and ' here"))
  let refused = Ok(@table.redis_plan(grid)) catch {
    @table.Refused(text~) => Err(text)
  }
  assert_eq(refused is Err(_), true)
}

///|
test "a list has no cell to set, and says so" {
  let page = @table.Page::new(
    None,
    "queue",
    ["index", "value"],
    [[@table.Cell::of("0"), @table.Cell::of("a")]],
    [],
  )
  let grid = plan_grid(page)
  grid.set_cell(0, "value", @table.Cell::of("b"))
  let refused = Ok(@table.redis_plan(grid)) catch {
    @table.Refused(text~) => Err(text)
  }
  assert_eq(refused is Err(_), true)
}
