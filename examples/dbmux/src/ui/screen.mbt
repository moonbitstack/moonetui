// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The window: the band, the table list, the pane, and the keys along the
/// bottom. Rebuilt only when the state changes shape, so the widgets keep
/// their scroll and their cursor.
pub struct Screen {
  state : @shell.State
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
  { state, pane: Router::new(0, state), second: Router::new(1, state), }
}

///|
/// The keys the bar offers, by what has the keyboard.
fn Screen::keys(self : Screen) -> Array[(String, String)] {
  match self.state.focus {
    @shell.Focus::Tree =>
      [
        ("tab", "pane"),
        ("↑↓", "table"),
        ("enter", "open"),
        ("C-p", "palette"),
        ("?", "keys"),
        ("q", "quit"),
      ]
    @shell.Focus::Grid =>
      [
        ("tab", "pane"),
        ("e", "edit"),
        ("f", "filter"),
        ("s", "sort"),
        ("C-s", "save"),
        ("C-v", "split"),
        ("C-p", "palette"),
        ("?", "keys"),
      ]
    @shell.Focus::Editor =>
      [
        ("tab", "pane"),
        ("C-r", "run"),
        ("C-n", "complete"),
        ("C-↑↓", "history"),
        ("esc", "normal"),
        ("C-p", "palette"),
      ]
  }
}

///|
/// The tree the application draws. One id per leaf: the list narrow, the pane
/// wide, a hairline between them.
pub fn Screen::node(self : Screen) -> @app.Node {
  let state = self.state
  let band = @app.leaf(
    1,
    line(width => band(state, width~)),
    box=@layout.Box::new(extent=Cells(1)),
  )
  let tables_head = @app.leaf(
    7,
    line(width => {
      head(
        "tables",
        count=state.tables.length().to_string(),
        width~,
        active=state.focus is @shell.Focus::Tree,
      )
    }),
    box=@layout.Box::new(extent=Cells(1)),
  )
  let tables = @app.leaf(3, tables(state), box=@layout.Box::new(extent=Frac(1)))
  let left = @app.column(
    9,
    [tables_head, tables],
    box=@layout.Box::new(extent=Cells(28)),
  )
  let first = @app.leaf(4, self.pane, box=@layout.Box::new(extent=Frac(1)))
  let right : @app.Node = match state.layout {
    @shell.Layout::Single => first
    @shell.Layout::SplitVertical => {
      let other = @app.leaf(
        5,
        self.second,
        box=@layout.Box::new(extent=Frac(1)),
      )
      let rule = @app.leaf(12, divider(), box=@layout.Box::new(extent=Cells(1)))
      @app.row(
        10,
        [first, rule, other],
        box=@layout.Box::new(extent=Frac(1)),
        gap=1,
      )
    }
    @shell.Layout::SplitHorizontal => {
      let other = @app.leaf(
        5,
        self.second,
        box=@layout.Box::new(extent=Frac(1)),
      )
      @app.column(
        10,
        [first, other],
        box=@layout.Box::new(extent=Frac(1)),
        gap=1,
      )
    }
  }
  let rule = @app.leaf(8, divider(), box=@layout.Box::new(extent=Cells(1)))
  let middle = @app.row(
    2,
    [left, rule, right],
    box=@layout.Box::new(extent=Frac(1)),
    gap=1,
  )
  let foot = @app.leaf(
    6,
    line(width => keys(self.keys(), width~)),
    box=@layout.Box::new(extent=Cells(1)),
  )
  @app.column(0, [band, middle, foot], gap=1)
}

///|
/// Bring the widgets up to what the state says. Cheap enough for every frame
/// at the sizes a terminal table has.
pub fn Screen::refresh(self : Screen) -> Unit {
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
