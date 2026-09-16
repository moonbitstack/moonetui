// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let head = @widget.Header::new("moonetui", note="ctrl-c to quit")
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
  let tty = @native.NativeTty::new()
  let ui = @app.App::new(tty, tree, base=@style.Style::new())
  ui.start()
  // A native program can block on the terminal, so the loop is a loop.
  @native.run(() => {
    let alive = ui.step()
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
  ui.stop()
}
