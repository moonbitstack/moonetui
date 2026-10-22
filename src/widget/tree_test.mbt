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
test "the wheel scrolls a tree past its cursor" {
  let tree = dune()
  let w : &@widget.Widget = tree
  let at = size(20, 2)
  let wheel = @widget.Msg::Mouse({
    kind: ScrollDown,
    button: 0,
    x: 0,
    y: 0,
    mods: @event.none,
  })
  let top = rows(w, at)
  ignore(press(w, 1, at, wheel))
  ignore(press(w, 1, at, wheel))
  let scrolled = rows(w, at)
  assert_eq(scrolled != top, true)
  assert_eq(scrolled[0].contains("Paul"), true)
}
