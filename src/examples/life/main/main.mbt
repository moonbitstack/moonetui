// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Life, at 8 generations a second: fast enough to watch a glider cross the
/// field, slow enough to see each generation arrive.
fn main raise {
  let screen = @life.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@life.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  ui.every(120, () => {
    screen.field.step()
    ui.refresh()
  })
  @native.run(() => ui.step())
  ui.stop()
}
