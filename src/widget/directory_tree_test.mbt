// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn fake_dirs() -> (String) -> Array[@widget.DirEntry] {
  fn(path : String) {
    if path == "/" {
      [
        @widget.DirEntry::new("readme.md", is_dir=false),
        @widget.DirEntry::new("zeta", is_dir=true),
        @widget.DirEntry::new("src", is_dir=true),
      ]
    } else if path == "/src" {
      [@widget.DirEntry::new("main.mbt", is_dir=false)]
    } else if path == "/zeta" {
      [@widget.DirEntry::new("deep", is_dir=true)]
    } else {
      []
    }
  }
}

///|
test "directory tree sorts folders first and renders icons" {
  let dirs = @widget.DirectoryTree::new(path="/", loader=fake_dirs())
  let w : &@widget.Widget = dirs
  assert_eq(rows(w, size(18, 4)), [
    "📂 /              ", "├── 📁 src        ", "├── 📁 zeta       ",
    "└── 📄 readme.md  ",
  ])
  assert_eq(dirs.path(), "/")
}

///|
test "directory tree loads directories as they expand" {
  let dirs = @widget.DirectoryTree::new(path="/", loader=fake_dirs())
  let w : &@widget.Widget = dirs
  let at = size(20, 4)
  ignore(press(w, 3, at, key(Down)))
  ignore(press(w, 3, at, key(Down)))
  assert_eq(press(w, 3, at, key(Char(32))), [
    @widget.ToggledAt(id=3, index=1, on=true),
    @widget.Repaint(id=3),
  ])
  assert_eq(rows(w, at), [
    "📂 /                ", "├── 📂 src          ", "│   └── 📄 main.mbt ",
    "├── 📁 zeta         ",
  ])
}

///|
test "directory tree reports files and directories by path" {
  let dirs = @widget.DirectoryTree::new(path="/", loader=fake_dirs())
  let w : &@widget.Widget = dirs
  let at = size(20, 4)
  assert_eq(
    press(
      w,
      5,
      at,
      Mouse({ kind: Down, button: 0, x: 8, y: 3, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=5),
      @widget.Highlighted(id=5, index=3),
      @widget.Repaint(id=5),
      @widget.Selected(id=5, index=3),
      @widget.Submitted(id=5, value="/readme.md"),
    ],
  )
  assert_eq(
    press(
      w,
      5,
      at,
      Mouse({ kind: Down, button: 0, x: 8, y: 1, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=5),
      @widget.Highlighted(id=5, index=1),
      @widget.Repaint(id=5),
      @widget.Selected(id=5, index=1),
      @widget.ToggledAt(id=5, index=1, on=true),
      @widget.Repaint(id=5),
      @widget.Changed(id=5, value="/src"),
    ],
  )
}

///|
test "directory tree reloads under a new root" {
  let dirs = @widget.DirectoryTree::new(path="/", loader=fake_dirs())
  let w : &@widget.Widget = dirs
  dirs.set_path("/src")
  assert_eq(dirs.path(), "/src")
  assert_eq(rows(w, size(18, 2)), [
    "📂 /src           ", "└── 📄 main.mbt   ",
  ])
}
