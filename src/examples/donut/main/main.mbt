// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The torus at about 33 frames a second: fast enough to read as a rotation,
/// slow enough that a terminal can draw every frame.
fn main raise {
  let screen = @donut.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@donut.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  ui.every(30, () => {
    screen.donut.spin()
    ui.refresh()
  })
  @native.run(() => ui.step())
  ui.stop()
}
