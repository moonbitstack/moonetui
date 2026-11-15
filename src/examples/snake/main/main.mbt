// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A game in a real terminal. The board it plays on lives in `board.mbt`,
/// where the frame test turns it the same way.
fn main raise {
  let screen = @snake.Screen::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.root,
    sheet=@snake.sheet(),
    quit=[@app.ctrl_c, @app.esc, @app.q],
  )
  ui.start()
  // One step every 110 ms: fast enough to feel alive, slow enough to steer.
  ui.every(110, () => {
    screen.board.step()
    ui.refresh()
  })
  @native.run(() => ui.step())
  ui.stop()
}
