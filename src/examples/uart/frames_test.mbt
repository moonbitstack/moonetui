// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A serial frame carries no escape bytes, so a terminal emulator has nothing
/// to model it against and this test announces nothing to the check in CI: the
/// rows it would have shown are asserted here instead — their width, their
/// words, and the absence of the byte that would make them a control sequence.
test "a sensor node writes whole rows and no escape bytes" {
  let size = @geom.Size::new(40, 8)
  let screen = @uart.Screen::new()
  let wire = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(wire, screen.root, plain=true, quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(wire.output())
  wire.clear_output()
  let rows = ui.screen()
  assert_eq(rows.length(), 8)
  assert_true(rows[0].contains("sensor node"))
  assert_true(rows[0].contains("115200"))
  assert_true(rows.iter().any(row => row.contains("link up")))
  assert_true(rows.iter().any(row => row.contains("78%")))
  // A serial line is not a terminal: not one escape byte leaves this side.
  assert_false(total.to_string().contains("\u{1b}"))
  // Every row is the width it was given, so the receiver can split on newlines.
  for row in rows {
    assert_eq(@strip.str_cells(row), 40)
  }
  // A beat redraws the same rows: nothing about the node changes on its own.
  wire.clear_output()
  ignore(ui.step())
  total.write_string(wire.output())
  assert_eq(ui.screen(), rows)
}
