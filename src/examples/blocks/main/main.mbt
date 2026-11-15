// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let screen = @blocks.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@blocks.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  ui.every(60, () => {
    screen.grid.fall()
    ui.refresh()
  })
  @native.run(() => ui.step())
  ui.stop()
}
