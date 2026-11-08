// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let help : Array[(String, String)] = [
  ("ctrl+p", "command palette"),
  ("ctrl+s", "save the file"),
  ("esc", "leave"),
]

///|
test "a key panel puts each key against what it does, in columns" {
  let panel = @widget.KeyPanel::new(bindings=help)
  let lines = rows(panel, size(60, 2))
  assert_eq(
    lines[0],
    "ctrl+p command palette        ctrl+s save the file          ",
  )
  assert_eq(lines[1].has_prefix("   esc leave"), true)
  assert_eq(@strip.str_cells(lines[1]), 60)
  assert_eq(panel.bindings().length(), 3)
}

///|
test "a key panel needs the rows it says it needs" {
  let panel = @widget.KeyPanel::new(bindings=help)
  assert_eq(panel.rows(60), 2)
  assert_eq(panel.rows(24), 3)
  assert_eq(panel.hint(size(60, 10)), size(60, 2))
  assert_eq(panel.hint(size(60, 1)), size(60, 1))
  let empty = @widget.KeyPanel::new()
  assert_eq(empty.rows(60), 0)
  assert_eq(empty.hint(size(60, 5)), size(60, 1))
}

///|
test "a narrow key panel keeps one column and cuts the description" {
  let panel = @widget.KeyPanel::new(bindings=help)
  let line = rows(panel, size(24, 3))[0]
  assert_eq(@strip.str_cells(line), 24)
  assert_eq(line.has_prefix("ctrl+p command palette"), true)
}

///|
test "a key panel takes no focus and answers no key" {
  let panel = @widget.KeyPanel::new(bindings=help)
  assert_eq(panel.focusable(), false)
  assert_eq(press(panel, 1, size(60, 2), key(Down)), [])
  assert_eq(press(panel, 1, size(60, 2), mouse(Down, 0, 0)), [])
}

///|
test "a key panel takes a new set of bindings" {
  let panel = @widget.KeyPanel::new(bindings=help)
  panel.set_bindings([("q", "quit")])
  assert_eq(panel.bindings().length(), 1)
  assert_eq(rows(panel, size(60, 1))[0].has_prefix("q quit"), true)
}
