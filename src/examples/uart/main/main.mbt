// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let screen = @uart.Screen::new()
  let wire = @driver.Headless::new(@geom.Size::new(40, 8))
  let ui = @app.App::new(wire, screen.root, plain=true, quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  ui.start()
  let frame = wire.output()
  ui.stop()
  println("what the serial line receives, 40 columns by 8 rows:")
  println(frame)
  if frame.contains("\u{1b}") {
    println("escape bytes found on the wire")
  } else {
    println("no escape bytes on the wire: text and newlines only")
  }
}
