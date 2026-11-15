// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// 2048. There is no clock: the board moves when a reader presses an arrow,
/// which is the whole of the game.
fn main raise {
  let screen = @game2048.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@game2048.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  @native.run(() => ui.step())
  ui.stop()
}
