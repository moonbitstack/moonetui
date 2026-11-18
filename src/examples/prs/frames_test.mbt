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
test "a request is picked, merged, and the card folds away" {
  let size = @geom.Size::new(80, 22)
  let screen = @prs.Screen::new()
  let board = screen.board
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@prs.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("prs/00 open", size, total.to_string(), ui.screen())
  assert_eq(board.number_of(0), 412)
  assert_true(board.review_of(0) == @prs.Approved)
  assert_true(board.open_card())
  // Down moves the cursor and the card follows it.
  board.shift(1)
  assert_eq(board.pick(), 1)
  assert_eq(board.number_of(1), 409)
  shot(ui, driver, total, "prs/01 second", size)
  // Merging turns the review over, and the feed says so at the top.
  board.merge()
  assert_true(board.review_of(1) == @prs.Merged)
  assert_eq(board.count(@prs.Merged), 1)
  shot(ui, driver, total, "prs/02 merged", size)
  // A second press says it is done rather than merging twice.
  board.merge()
  assert_eq(board.count(@prs.Merged), 1)
  // The card folds, and the feed moves up into its place.
  board.fold()
  assert_false(board.open_card())
  shot(ui, driver, total, "prs/03 folded", size)
  // A draft is not merged.
  board.shift(2)
  assert_eq(board.number_of(board.pick()), 398)
  board.merge()
  assert_true(board.review_of(board.pick()) == @prs.Draft)
}
