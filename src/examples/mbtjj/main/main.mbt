// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let screen = @mbtjj.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@mbtjj.sheet(),
    quit=[@app.ctrl_c],
  )
  ui.start()
  @native.run(() => ui.step())
  ui.stop()
}
