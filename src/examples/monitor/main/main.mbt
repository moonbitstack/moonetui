// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The service monitor in a real terminal. The screen lives in `model.mbt`,
/// where the frame tests drive the same one.
fn main raise {
  let monitor = @monitor.Monitor::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    monitor.root,
    sheet=@monitor.sheet(),
    quit=[@app.ctrl_c, @app.esc],
  )
  ui.on(report => {
    match report {
      Submitted(value~, ..) => {
        if monitor.answer(value) {
          ui.quit()
        }
        ui.refresh()
        true
      }
      _ => false
    }
  })
  ui.every(1000, () => {
    monitor.step()
    ui.refresh()
  })
  ui.run()
}
