// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The first programme anyone writes with this library: a header, a list, a
// field that shows what the list chose, and a key bar. It is a package of its
// own so the same rows can be drawn without a terminal, which is what the frame
// test in CI checks.

///|
pub struct Screen {
  head : @widget.Header
  list : @widget.ListView
  field : @widget.Input
  foot : @widget.Footer
  root : @app.Node
}

///|
pub fn Screen::new() -> Screen {
  let head = @widget.Header::new("moonetui", note="ctrl-c to quit")
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon",
  ])
  let field = @widget.Input::new(placeholder="type here", caret=Bar(blink=true))
  let foot = @widget.Footer::new([
    ("tab", "next"),
    ("up down", "move"),
    ("enter", "choose"),
  ])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, field, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(4, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  { head, list, field, foot, root, }
}

///|
/// The field takes the item the list chose, so the two panes agree.
pub fn Screen::choose(self : Screen, index : Int32) -> Unit {
  let items = self.list.items()
  if index >= 0 && index < items.length() {
    self.field.set(items[index])
  }
}

///|
/// What the list has chosen.
pub fn Screen::chosen(self : Screen) -> Int32 {
  self.list.index()
}
