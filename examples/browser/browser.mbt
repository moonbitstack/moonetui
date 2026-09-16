// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Build the application and hand the browser the frame loop.
///
/// Every line below is the same as the terminal example except the driver: that
/// is the point of the driver seam.
pub fn start() -> Unit {
  let head = @widget.Header::new("moonetui in a browser", note="tab to move")
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon", "中文也对齐",
  ])
  let field = @widget.Input::new(placeholder="type here")
  let bar = @widget.Progress::new(total=100)
  let foot = @widget.Footer::new([
    ("tab", "next"),
    ("up down", "move"),
    ("enter", "choose"),
  ])
  bar.set(35)
  let tree = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, field, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(4, bar, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(5, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  let tty = @web.WebTty::new(canvas="moonetui", font_px=16)
  let ui = @app.App::new(tty, tree, base=@style.Style::new())
  ui.start() catch {
    _ => ()
  }
  @web.pump(() => {
    let alive = ui.step() catch { _ => false }
    for report in ui.drain() {
      match report {
        Selected(index~, ..) => {
          field.set(list.items()[index])
          bar.advance(10)
          ui.refresh()
        }
        _ => ()
      }
    }
    alive
  })
}
