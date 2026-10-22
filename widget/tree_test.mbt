// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn dune() -> @widget.Tree {
  let tree = @widget.Tree::new(root_label="Dune")
  let root = tree.root_id()
  let chars = tree.add(root, "Characters", expand=true)
  ignore(tree.add_leaf(chars, "Paul"))
  ignore(tree.add_leaf(chars, "Jessica"))
  ignore(tree.add_leaf(chars, "Chani"))
  tree.expand(root)
  tree
}

///|
fn shift_key(code : @event.KeyCode) -> @widget.Msg {
  Key(@event.Key::with_mods(code, { ctrl: false, alt: false, shift: true, }))
}

///|
test "tree renders guides icons and labels" {
  let tree = dune()
  let w : &@widget.Widget = tree
  assert_eq(rows(w, size(20, 5)), [
    "▼ Dune              ", "└── ▼ Characters    ", "    ├── Paul        ",
    "    ├── Jessica     ", "    └── Chani       ",
  ])
  assert_eq(w.hint(size(20, 24)), size(16, 5))
}

///|
test "tree hides the root but keeps the deeper guides" {
  let tree = dune()
  tree.show_root(false)
  let w : &@widget.Widget = tree
  assert_eq(rows(w, size(20, 4)), [
    "▼ Characters        ", "├── Paul            ", "├── Jessica         ",
    "└── Chani           ",
  ])
  assert_eq(w.hint(size(20, 24)), size(12, 4))
}

///|
test "tree walks its cursor and reports the highlight" {
  let tree = dune()
  let w : &@widget.Widget = tree
  let at = size(20, 5)
  assert_eq(press(w, 5, at, key(Down)), [
    @widget.Highlighted(id=5, index=0),
    @widget.Repaint(id=5),
  ])
  ignore(press(w, 5, at, key(Down)))
  assert_eq(tree.cursor_line(), 1)
  ignore(press(w, 5, at, key(End)))
  assert_eq(tree.cursor_line(), 4)
  ignore(press(w, 5, at, key(Home)))
  assert_eq(tree.cursor_line(), 0)
  assert_eq(press(w, 5, at, key(Up)), [])
  assert_eq(tree.cursor_line(), 0)
}

///|
test "enter selects and auto-expands the node at the cursor" {
  let tree = dune()
  tree.collapse(1)
  let w : &@widget.Widget = tree
  let at = size(20, 2)
  ignore(press(w, 6, at, key(Down)))
  ignore(press(w, 6, at, key(Down)))
  assert_eq(press(w, 6, at, key(Enter)), [
    @widget.Selected(id=6, index=1),
    @widget.ToggledAt(id=6, index=1, on=true),
    @widget.Repaint(id=6),
  ])
  assert_eq(press(w, 6, at, key(Enter)), [
    @widget.Selected(id=6, index=1),
    @widget.ToggledAt(id=6, index=1, on=false),
    @widget.Repaint(id=6),
  ])
  tree.set_auto_expand(false)
  assert_eq(press(w, 6, at, key(Enter)), [@widget.Selected(id=6, index=1)])
}

///|
test "enter on a leaf selects without toggling" {
  let tree = dune()
  let w : &@widget.Widget = tree
  let at = size(20, 5)
  ignore(press(w, 7, at, key(Down)))
  ignore(press(w, 7, at, key(Down)))
  ignore(press(w, 7, at, key(Down)))
  assert_eq(tree.cursor_line(), 2)
  assert_eq(press(w, 7, at, key(Enter)), [@widget.Selected(id=7, index=2)])
}

///|
test "space toggles the node at the cursor" {
  let tree = dune()
  let w : &@widget.Widget = tree
  let at = size(20, 5)
  ignore(press(w, 8, at, key(Down)))
  ignore(press(w, 8, at, key(Down)))
  assert_eq(press(w, 8, at, key(Char(32))), [
    @widget.ToggledAt(id=8, index=1, on=false),
    @widget.Repaint(id=8),
  ])
  assert_eq(tree.line_count(), 2)
  assert_eq(press(w, 8, at, key(Char(32))), [
    @widget.ToggledAt(id=8, index=1, on=true),
    @widget.Repaint(id=8),
  ])
  assert_eq(tree.line_count(), 5)
}

///|
test "shift space expands or collapses all the siblings" {
  let tree = @widget.Tree::new(root_label="root")
  let root = tree.root_id()
  ignore(tree.add(root, "A"))
  ignore(tree.add(root, "B"))
  tree.expand(root)
  let w : &@widget.Widget = tree
  let at = size(20, 3)
  ignore(press(w, 9, at, key(Down)))
  ignore(press(w, 9, at, key(Down)))
  assert_eq(press(w, 9, at, shift_key(Char(32))), [
    @widget.ToggledAt(id=9, index=1, on=true),
    @widget.ToggledAt(id=9, index=2, on=true),
    @widget.Repaint(id=9),
  ])
  assert_eq(press(w, 9, at, shift_key(Char(32))), [
    @widget.ToggledAt(id=9, index=1, on=false),
    @widget.ToggledAt(id=9, index=2, on=false),
    @widget.Repaint(id=9),
  ])
}

///|
test "shift arrows walk the family" {
  let tree = @widget.Tree::new(root_label="root")
  let root = tree.root_id()
  let a = tree.add(root, "A", expand=true)
  ignore(tree.add_leaf(a, "A1"))
  ignore(tree.add_leaf(a, "A2"))
  let b = tree.add(root, "B")
  ignore(tree.add(root, "C"))
  tree.expand(root)
  let w : &@widget.Widget = tree
  let at = size(24, 6)
  ignore(press(w, 2, at, key(Down)))
  ignore(press(w, 2, at, key(Down)))
  ignore(press(w, 2, at, key(Down)))
  ignore(press(w, 2, at, key(Down)))
  assert_eq(tree.cursor_line(), 3)
  assert_eq(press(w, 2, at, shift_key(Up)), [
    @widget.Highlighted(id=2, index=2),
    @widget.Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, shift_key(Down)), [
    @widget.Highlighted(id=2, index=3),
    @widget.Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, shift_key(Down)), [
    @widget.Highlighted(id=2, index=b),
    @widget.Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, shift_key(Left)), [
    @widget.Highlighted(id=2, index=0),
    @widget.Repaint(id=2),
  ])
  ignore(press(w, 2, at, key(Down)))
  assert_eq(press(w, 2, at, shift_key(Right)), [@widget.Repaint(id=2)])
  assert_eq(tree.cursor_line(), -1)
}

///|
test "click toggles the icon or moves the cursor and selects" {
  let tree = dune()
  tree.collapse(1)
  let w : &@widget.Widget = tree
  let at = size(20, 2)
  assert_eq(
    press(
      w,
      4,
      at,
      Mouse({ kind: Down, button: 0, x: 4, y: 1, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=4),
      @widget.ToggledAt(id=4, index=1, on=true),
      @widget.Repaint(id=4),
    ],
  )
  assert_eq(
    press(
      w,
      4,
      at,
      Mouse({ kind: Down, button: 0, x: 10, y: 2, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=4),
      @widget.Highlighted(id=4, index=2),
      @widget.Repaint(id=4),
      @widget.Selected(id=4, index=2),
    ],
  )
}

///|
test "tree keeps the cursor visible while walking past the fold" {
  let tree = @widget.Tree::new(root_label="root")
  let root = tree.root_id()
  for i in 0..<6 {
    ignore(tree.add_leaf(root, "L\{i + 1}"))
  }
  tree.expand(root)
  let w : &@widget.Widget = tree
  let at = size(10, 3)
  assert_eq(press(w, 3, at, key(End)), [
    @widget.Highlighted(id=3, index=6),
    @widget.Repaint(id=3),
  ])
  assert_eq(rows(w, at), [
    "├── L4    ", "├── L5    ", "└── L6    ",
  ])
  ignore(press(w, 3, at, key(Home)))
  assert_eq(rows(w, at), [
    "▼ root    ", "├── L1    ", "├── L2    ",
  ])
}

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
