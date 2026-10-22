// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let head = @widget.Header::new("moonetui", note="ctrl-c to quit")
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon",
  ])
  let field = @widget.Input::new(placeholder="type here")
  let foot = @widget.Footer::new([
    ("tab", "next"),
    ("up down", "move"),
    ("enter", "choose"),
  ])
  let tree = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, field, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(4, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  let tty = @node.NodeTty::new()
  let ui = @app.App::new(tty, tree, base=@style.Style::new())
  ui.start()
  @node.pump(16, () => {
    let alive = ui.step() catch { _ => false }
    for report in ui.drain() {
      match report {
        Selected(index~, ..) => {
          field.set(list.items()[index])
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
