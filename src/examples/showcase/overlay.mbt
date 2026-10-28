// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn message_box() -> Demo {
  let ask = @widget.MessageBox::new(
    title="Quit",
    message="The buffer has changes that were never saved. Discard them?",
    kind=Question,
    buttons=@widget.yes_no,
  )
  let note = @widget.MessageBox::new(
    title="Saved",
    message="Everything is written to disk.",
    kind=Info,
    buttons=@widget.ok,
  )
  Demo::new(
    "MessageBox",
    @app.row(
      0,
      [
        @app.leaf(1, ask, box=@layout.Box::new(extent=Frac(1))),
        @app.leaf(2, note, box=@layout.Box::new(extent=Frac(1))),
      ],
      gap=1,
    ),
    group=Overlay,
    note="A question or a notice with a row of buttons: the arrows move, Enter takes, Escape closes.",
    rows=7,
  )
}

///|
pub fn input_box() -> Demo {
  let box = @widget.InputBox::new(
    title="Rename",
    prompt="New name",
    value="untitled",
    buttons=@widget.ok_cancel,
  )
  Demo::new(
    "InputBox",
    @app.column(0, [@app.leaf(1, box, box=line(5))]),
    group=Overlay,
    note="A prompt, a one-line field and two buttons: typing goes to the field, Enter takes the button highlighted.",
    rows=5,
  )
}

///|
pub fn file_dialog() -> Demo {
  let dialog = @widget.FileDialog::new(
    title="Open file",
    path="~/src/moonetui",
    mode=Open,
    filter="mbt",
    entries=[
      @widget.FileEntry::new("..", dir=true),
      @widget.FileEntry::new("src", dir=true),
      @widget.FileEntry::new("docs", dir=true),
      @widget.FileEntry::new("widget.mbt", size=4820),
      @widget.FileEntry::new("app.mbt", size=3110),
      @widget.FileEntry::new("README.md", size=812),
    ],
  )
  Demo::new(
    "FileDialog",
    @app.column(0, [@app.leaf(1, dialog, box=line(12))]),
    group=Overlay,
    note="A listing the caller hands over: this library never touches a file system, so walking the tree stays outside it.",
    rows=12,
  )
}

///|
pub fn menu_bar() -> Demo {
  let bar = @widget.MenuBar::new()
  bar.add("File", [
    @widget.Item::new("New", shortcut="ctrl-n"),
    @widget.Item::new("Open", shortcut="ctrl-o"),
    @widget.Item::separator(),
    @widget.Item::new("Quit", shortcut="ctrl-q"),
  ])
  bar.add("View", [
    @widget.Item::new("Wrap", checked=true),
    @widget.Item::new("Numbers", checked=true),
    @widget.Item::separator(),
    @widget.Item::new("Full screen"),
  ])
  bar.add("Help", [@widget.Item::new("About")])
  Demo::new(
    "MenuBar",
    @app.column(0, [
      @app.leaf(1, bar, box=line(1)),
      @app.leaf(
        2,
        @widget.label(
          "Enter or the down arrow opens a list.",
          style=@style.Style::new(dim=true),
        ),
        box=line(1),
      ),
    ]),
    group=Overlay,
    note="Titles along the top, each with a list that drops beneath it; the arrows walk along and then down.",
    rows=5,
  )
}

///|
pub fn menu() -> Demo {
  let menu = @widget.Menu::new(items=[
    @widget.Item::new("Cut", shortcut="ctrl-x"),
    @widget.Item::new("Copy", shortcut="ctrl-c"),
    @widget.Item::new("Paste", shortcut="ctrl-v"),
    @widget.Item::separator(),
    @widget.Item::new("Grayscale", checked=true),
    @widget.Item::new("Locked", enabled=false),
  ])
  Demo::new(
    "Menu",
    @app.column(0, [@app.leaf(1, menu, box=line(7))]),
    group=Overlay,
    note="A list on its own: ticks for what is on, keys beside them, rules between groups, and what is off is skipped.",
    rows=7,
  )
}

///|
pub fn command_palette() -> Demo {
  let palette = @widget.CommandPalette::new()
  palette.add("Open file", hint="read one in", key="ctrl-o")
  palette.add("Save file", hint="write it out", key="ctrl-s")
  palette.add("Toggle wrap", key="ctrl-w")
  palette.add("Switch theme", hint="dark, light, nord")
  palette.add("Quit", key="ctrl-q")
  Demo::new(
    "CommandPalette",
    @app.column(0, [@app.leaf(1, palette, box=line(9))]),
    group=Overlay,
    note="Type part of a name and the list narrows: the query's letters read out of the name in order.",
    rows=9,
  )
}
