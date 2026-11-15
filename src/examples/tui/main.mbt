// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A styled application in a real terminal. The screen it draws lives in
/// `model.mbt`, where the frame tests drive the same one.
fn main raise {
  let demo = @dbmux.Demo::new()
  let tty = @native.NativeTty::new()
  let ui = @app.App::new(tty, demo.root, sheet=@dbmux.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  ui.start()
  @native.run(() => {
    let alive = ui.step()
    let reports = ui.drain()
    if reports.length() > 0 {
      demo.answer(reports)
      ui.refresh()
    }
    alive
  })
  ui.stop()
}
