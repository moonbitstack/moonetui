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
test "the givens hold, a digit goes in, and a clash is marked" {
  let size = @geom.Size::new(80, 22)
  let screen = @sudoku.Screen::new()
  let board = screen.board
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@sudoku.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("sudoku/00 open", size, total.to_string(), ui.screen())
  // The grid is whole: thirteen rows from the top border to the bottom one, each
  // as wide as the others, with the boxes' thick rules where the boxes meet.
  let grid = ui
    .screen()
    .filter(row => row.contains("┃") || row.contains("━"))
  assert_eq(grid.length(), @sudoku.GRID)
  let widths = grid.map(row => row.trim().length())
  assert_true(widths.iter().all(w => w == @sudoku.SPAN))
  assert_eq(grid.filter(row => row.contains("╋")).length(), 2)
  assert_eq(board.cursor(), (2, 0))
  assert_eq(board.cell(0, 0), 5)
  // A blank takes a digit; a given does not move.
  assert_eq(board.cell(2, 0), 0)
  board.write(9)
  assert_eq(board.cell(2, 0), 9)
  board.steer(-2, 0)
  board.write(4)
  assert_eq(board.cell(0, 0), 5)
  shot(ui, driver, total, "sudoku/01 wrote", size)
  // A four already sits at the start of row five: another one is a clash.
  board.steer(1, 4)
  board.write(4)
  assert_true(board.clash(1, 4))
  shot(ui, driver, total, "sudoku/02 clash", size)
  assert_eq(board.stage(), 0)
}
