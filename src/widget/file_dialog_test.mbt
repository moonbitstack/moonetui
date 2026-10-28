// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn tree() -> Array[@widget.FileEntry] {
  [
    @widget.FileEntry::new("src", dir=true),
    @widget.FileEntry::new("README.md", size=812),
    @widget.FileEntry::new("moon.mod", size=2400),
    @widget.FileEntry::new("notes.txt", size=40),
  ]
}

///|
test "a file dialog lists what the caller hands it" {
  let dialog = @widget.FileDialog::new(
    path="/home/moon",
    entries=tree(),
    title="Open file",
  )
  let w : &@widget.Widget = dialog
  assert_eq(rows(w, size(30, 9)), [
    "┌──────── Open file ─────────┐", "│ /home/moon                 │",
    "│ src/                       │", "│ README.md             812B │", "│ moon.mod                2K │",
    "│ notes.txt              40B │", "│>                           │", "│       Open    Cancel       │",
    "└────────────────────────────┘",
  ])
  assert_eq(w.hint(size(40, 24)), size(40, 9))
}

///|
test "a file dialog walks into a directory and reports it" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  let out = press(w, 2, size(30, 9), key(Enter))
  assert_eq(out, [@widget.Selected(id=2, index=0), @widget.Repaint(id=2)])
  ignore(press(w, 2, size(30, 9), key(Down)))
  let taken = press(w, 2, size(30, 9), key(Enter))
  assert_eq(taken, [
    @widget.Selected(id=2, index=0),
    @widget.Dismissed(id=2),
    @widget.Repaint(id=2),
  ])
  assert_eq(dialog.name(), "README.md")
  assert_eq(dialog.value(), "/README.md")
  assert_eq(dialog.is_answered(), true)
}

///|
test "a file dialog takes Escape as Cancel" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  let out = press(w, 2, size(30, 9), key(Escape))
  assert_eq(out, [
    @widget.Selected(id=2, index=1),
    @widget.Dismissed(id=2),
    @widget.Repaint(id=2),
  ])
  assert_eq(dialog.chosen(), Some(1))
}

///|
test "a save dialog takes typing into the name and Backspace back out" {
  let dialog = @widget.FileDialog::new(
    path="/tmp",
    entries=tree(),
    mode=Save,
    name="draft",
  )
  let w : &@widget.Widget = dialog
  let out = press(w, 3, size(30, 9), key(Char(49)))
  assert_eq(out, [@widget.Changed(id=3, value="draft1"), @widget.Repaint(id=3)])
  ignore(press(w, 3, size(30, 9), key(Backspace)))
  assert_eq(dialog.name(), "draft")
  assert_eq(dialog.value(), "/tmp/draft")
  assert_eq(dialog.buttons(), ["Save", "Cancel"])
}

///|
test "an open dialog jumps to the entry a letter starts" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  ignore(press(w, 3, size(30, 9), key(Char(110))))
  assert_eq(dialog.selected().map(entry => entry.name), Some("notes.txt"))
  assert_eq(press(w, 3, size(30, 9), key(Char(122))), [])
}

///|
test "a filter hides what does not end that way, but never a directory" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree(), filter="md")
  let w : &@widget.Widget = dialog
  assert_eq(dialog.selected().map(entry => entry.name), Some("src"))
  ignore(press(w, 3, size(30, 9), key(Down)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("README.md"))
  ignore(press(w, 3, size(30, 9), key(Down)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("README.md"))
  dialog.set_filter("")
  ignore(press(w, 3, size(30, 9), key(End)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("notes.txt"))
}

///|
test "a file dialog moves by a page and to either end" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  ignore(press(w, 3, size(30, 9), key(End)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("notes.txt"))
  ignore(press(w, 3, size(30, 9), key(PageUp)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("src"))
  ignore(press(w, 3, size(30, 9), key(PageDown)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("notes.txt"))
  ignore(press(w, 3, size(30, 9), key(Home)))
  assert_eq(dialog.selected().map(entry => entry.name), Some("src"))
  assert_eq(press(w, 3, size(30, 9), key(Up)), [])
}

///|
test "a click highlights an entry and a second click on it goes in" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  let out = press(
    w,
    4,
    size(30, 9),
    Mouse({ kind: Down, button: 0, x: 5, y: 3, mods: @event.none, }),
  )
  assert_eq(out, [@widget.TakeFocus(id=4), @widget.Repaint(id=4)])
  assert_eq(dialog.selected().map(entry => entry.name), Some("README.md"))
  let again = press(
    w,
    4,
    size(30, 9),
    Mouse({ kind: Down, button: 0, x: 5, y: 3, mods: @event.none, }),
  )
  assert_eq(again, [
    @widget.TakeFocus(id=4),
    @widget.Selected(id=4, index=0),
    @widget.Dismissed(id=4),
    @widget.Repaint(id=4),
  ])
  assert_eq(dialog.name(), "README.md")
}

///|
test "a click on the buttons of a file dialog answers it" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  // The two buttons are centred on the row above the bottom edge.
  let out = press(
    w,
    4,
    size(30, 9),
    Mouse({ kind: Down, button: 0, x: 10, y: 7, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=4),
    @widget.Selected(id=4, index=0),
    @widget.Dismissed(id=4),
    @widget.Repaint(id=4),
  ])
}

///|
test "the wheel scrolls a listing longer than the window" {
  let many : Array[@widget.FileEntry] = []
  for i in 0..<12 {
    many.push(@widget.FileEntry::new("f" + i.to_string(), size=i))
  }
  let dialog = @widget.FileDialog::new(path="/", entries=many)
  let w : &@widget.Widget = dialog
  assert_eq(w.hint(size(30, 24)), size(30, 15))
  assert_eq(
    press(
      w,
      4,
      size(30, 9),
      Mouse({ kind: ScrollDown, button: 0, x: 5, y: 3, mods: @event.none, }),
    ),
    [@widget.Repaint(id=4)],
  )
  let down = dialog.render_line(2, size(30, 9)).text()
  assert_eq(down.contains("f1"), true)
  assert_eq(
    press(
      w,
      4,
      size(30, 9),
      Mouse({ kind: ScrollUp, button: 0, x: 5, y: 3, mods: @event.none, }),
    ),
    [@widget.Repaint(id=4)],
  )
  assert_eq(dialog.render_line(2, size(30, 9)).text().contains("f0"), true)
}

///|
test "a focused file dialog marks the row it is on" {
  let dialog = @widget.FileDialog::new(path="/", entries=tree())
  let w : &@widget.Widget = dialog
  ignore(press(w, 1, size(30, 9), Focus(true)))
  let line = dialog.render_line(2, size(30, 9))
  assert_eq(line.segs.length() > 0, true)
  assert_eq(line.segs[1].style, @style.Style::new(reverse=true))
  ignore(press(w, 1, size(30, 9), Focus(false)))
  let dim = dialog.render_line(2, size(30, 9))
  assert_eq(dim.segs[1].style, @style.Style::new(dim=true, reverse=true))
}

///|
test "an empty file dialog has nothing chosen and no highlight" {
  let dialog = @widget.FileDialog::new()
  let w : &@widget.Widget = dialog
  assert_eq(dialog.selected(), None)
  assert_eq(dialog.title(), "Open file")
  assert_eq(press(w, 1, size(30, 9), key(Down)), [])
  assert_eq(w.hint(size(30, 24)), size(30, 5))
  assert_eq(dialog.render_line(0, size(1, 8)).text(), " ")
}

///|
test "a path that already ends in a slash is not given another" {
  let dialog = @widget.FileDialog::new(path="/tmp/", name="a.mbt")
  assert_eq(dialog.value(), "/tmp/a.mbt")
  let bare = @widget.FileDialog::new(name="a.mbt")
  assert_eq(bare.value(), "a.mbt")
  dialog.set_path("/var")
  assert_eq(dialog.path(), "/var")
  assert_eq(dialog.value(), "/var/a.mbt")
}

///|
test "a save dialog shows the filter in the name row when it is empty" {
  let dialog = @widget.FileDialog::new(mode=Save, filter="mbt")
  let line = dialog.render_line(6, size(30, 9)).text()
  assert_eq(line.contains("*.mbt"), true)
}
