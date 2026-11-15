// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A dashboard that moves: a spectrum of load, a rate, and a clock. It is the
/// smallest complete thing this toolkit can build that looks like a product.
fn main raise {
  let screen = @pulse.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@pulse.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  ui.every(90, () => {
    screen.pulse.tick()
    ui.refresh()
  })
  @native.run(() => ui.step())
  ui.stop()
}
