// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let screen = @logs.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@logs.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  @native.run(() => ui.step())
  ui.stop()
}
