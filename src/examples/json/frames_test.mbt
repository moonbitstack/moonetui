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
test "a path is read off the cursor, a key folds, and a query greys the rest" {
  let size = @geom.Size::new(80, 22)
  let screen = @json.Screen::new()
  let doc = screen.doc
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@json.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  @frames.announce("json/00 open", size, total.to_string(), ui.screen())
  assert_eq(doc.visible().length(), 25)
  assert_eq(doc.path(), "$")
  // Down to a leaf: the path is read off the keys above it.
  doc.walk(2)
  assert_eq(doc.at().key, "version")
  assert_eq(doc.path(), "$.version")
  // Folding a container hides the lines under it, and unfolding brings them back.
  doc.walk(2)
  assert_eq(doc.at().key, "keywords")
  doc.fold()
  assert_false(doc.at().open)
  assert_eq(doc.visible().length(), 25 - 3)
  assert_true(doc.note.has_prefix("folded "))
  shot(ui, driver, total, "json/01 folded", size)
  doc.fold()
  assert_eq(doc.visible().length(), 25)
  // A query keeps the lines it matches lit and dims the rest.
  doc.begin()
  for ch in [100, 114, 105, 118, 101, 114] {
    doc.letter(ch)
  }
  doc.settle()
  assert_eq(doc.query, "driver")
  shot(ui, driver, total, "json/02 found", size)
  // Walking skips what is folded away, and escape clears the query.
  doc.walk(40)
  assert_true(doc.cursor < 25)
  shot(ui, driver, total, "json/03 walked", size)
  doc.clear()
  assert_eq(doc.query, "")
  // A leaf has nothing to fold, and says so.
  doc.walk(-40)
  assert_eq(doc.cursor, 0)
  doc.walk(1)
  doc.fold()
  assert_true(doc.note.has_suffix("nothing to fold"))
  shot(ui, driver, total, "json/04 leaf", size)
}
