// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The window: a header, the table list, the pane, and the keys along the
/// bottom. Rebuilt only when the state changes shape, so the widgets keep
/// their scroll and their cursor.
pub struct Screen {
  state : @shell.State
  header : @widget.Header
  footer : @widget.Footer
  list : @widget.ListView
  pane : Router
  second : Router
}

///|
/// The id of a pane's leaf in the widget tree. The pane with the keyboard has
/// to be the one the application gives the keys to.
pub fn pane_id(pane : Int32) -> Int32 {
  4 + pane
}

///|
pub fn Screen::new(state : @shell.State) -> Screen {
  let list = @widget.ListView::new([])
  let pane = Router::new(0, state, list)
  let second = Router::new(1, state, list)
  {
    state,
    header: @widget.Header::new(state.connection),
    footer: @widget.Footer::new([]),
    list,
    pane,
    second,
  }
}

///|
/// The tree the application draws. One id per leaf, the pane wide, the list
/// narrow: the same shape a database client has had since the terminals were
/// green.
pub fn Screen::node(self : Screen) -> @app.Node {
  let head = @app.leaf(
    1,
    self.header,
    box=@layout.Box::new(extent=Cells(1)),
    name="Header",
  )
  let left = @app.leaf(3, self.list, box=@layout.Box::new(extent=Cells(28)), classes=[
    "framed",
  ])
  let first = @app.leaf(4, self.pane, box=@layout.Box::new(extent=Frac(1)), classes=[
    "framed",
  ])
  let right : @app.Node = match self.state.layout {
    @shell.Layout::Single => first
    @shell.Layout::SplitVertical => {
      let other = @app.leaf(
        5,
        self.second,
        box=@layout.Box::new(extent=Frac(1)),
        classes=["framed"],
      )
      @app.row(10, [first, other], box=@layout.Box::new(extent=Frac(1)), gap=1)
    }
    @shell.Layout::SplitHorizontal => {
      let other = @app.leaf(
        5,
        self.second,
        box=@layout.Box::new(extent=Frac(1)),
        classes=["framed"],
      )
      @app.column(10, [first, other], box=@layout.Box::new(extent=Frac(1)))
    }
  }
  let middle = @app.row(
    2,
    [left, right],
    box=@layout.Box::new(extent=Frac(1)),
    gap=1,
  )
  let foot = @app.leaf(6, self.footer, box=@layout.Box::new(extent=Cells(1)))
  @app.column(0, [head, middle, foot])
}

///|
/// Bring the widgets up to what the state says. Cheap enough for every frame
/// at the sizes a terminal table has.
pub fn Screen::refresh(self : Screen) -> Unit {
  let state = self.state
  let badge = state.badge()
  let title = if badge == "" {
    state.connection
  } else {
    state.connection + " · " + badge
  }
  self.header.set(title)
  self.header.set_note(state.status())
  let items : Array[String] = []
  for table in state.tables {
    let schema = match table.schema {
      Some(s) => s + " / "
      None => ""
    }
    items.push(
      schema + table.name + (if table.is_view { " · view" } else { "" }),
    )
  }
  if self.list.items().length() != items.length() {
    self.list.set(items)
  }
  if state.tree_at < items.length() {
    self.list.select(state.tree_at)
  }
  self.footer.set([
    ("tab", "pane"),
    ("enter", "open"),
    ("C-p", "palette"),
    ("?", "keys"),
    ("C-r", "run"),
    ("C-n", "complete"),
    ("C-s", "save"),
    ("C-v", "split"),
    ("C-o", "pane"),
    ("q", "quit"),
  ])
  self.sync_panes()
}

///|
pub fn Screen::bus(self : Screen) -> Bus {
  self.pane.bus()
}

///|
pub fn Screen::editor(self : Screen) -> Editor {
  self.pane.editor()
}

///|
/// Keep the keyboard on the pane the state calls active, and both panes drawn
/// from their own tabs.
pub fn Screen::sync_panes(self : Screen) -> Unit {
  self.pane.sync()
  self.second.sync()
}
