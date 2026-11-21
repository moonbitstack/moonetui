// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let screen = @hello.Screen::new()
  let tty = @node.NodeTty::new()
  let ui = @app.App::new(tty, screen.root, base=@style.Style::new(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  ui.start()
  @node.pump(16, () => {
    let alive = ui.step() catch { _ => false }
    for report in ui.drain() {
      match report {
        Selected(index~, ..) => {
          screen.choose(index)
          ui.refresh()
        }
        _ => ()
      }
    }
    if !alive {
      ui.stop() catch {
        _ => ()
      }
    }
    alive
  })
}
