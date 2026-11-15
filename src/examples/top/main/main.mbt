// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let screen = @top.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@top.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  ui.every(120, () => {
    screen.monitor.step()
    ui.refresh()
  })
  @native.run(() => ui.step())
  ui.stop()
}
