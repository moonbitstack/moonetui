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

///|
fn forest(count : Int32) -> @widget.Tree {
  let tree = @widget.Tree::new(root_label="root")
  for i in 0..<count {
    ignore(tree.add_leaf(tree.root_id(), "n\{i}"))
  }
  tree.expand(tree.root_id())
  tree
}

///|
test "tree nodes are read and written by id" {
  let tree = dune()
  let chars = tree.children(tree.root_id())[0]
  assert_eq(tree.node(chars).label(), "Characters")
  assert_eq(tree.node(chars).is_expanded(), true)
  tree.set_label(chars, "People")
  tree.set_data(chars, "p")
  assert_eq((tree.label(chars), tree.data(chars)), ("People", "p"))
  assert_eq(tree.children(chars).length(), 3)
  tree.collapse_all(tree.root_id())
  assert_eq(
    (tree.is_expanded(tree.root_id()), tree.is_expanded(chars)),
    (false, false),
  )
  tree.expand_all(tree.root_id())
  assert_eq(tree.line_count(), 5)
  assert_eq(tree.allow_expand(chars), true)
  tree.set_allow_expand(chars, false)
  assert_eq(tree.allow_expand(chars), false)
  tree.remove_children(chars)
  assert_eq(tree.line_count(), 2)
}

///|
test "tree clears to its root, and resets the root's label" {
  let tree = dune()
  tree.reset("Arrakis", data="a")
  assert_eq(tree.line_count(), 1)
  assert_eq(
    (tree.label(tree.root_id()), tree.data(tree.root_id())),
    ("Arrakis", "a"),
  )
  assert_eq(tree.add_leaf(tree.root_id(), "x"), 1)
  assert_eq(tree.cursor_node(), -1)
}

///|
test "tree guides follow their switch and depth" {
  let tree = dune()
  let w : &@widget.Widget = tree
  let at = size(20, 5)
  let guided = rows(w, at)
  tree.show_guides(false)
  assert_eq(rows(w, at) != guided, true)
  tree.show_guides(true)
  tree.set_guide_depth(8)
  let indent = (line : String) => line.length() - line.trim_start().length()
  assert_eq(indent(rows(w, at)[2]) > indent(guided[2]), true)
}

///|
test "tree pages, and Home and End go to the ends" {
  let tree = forest(20)
  let w : &@widget.Widget = tree
  let at = size(12, 5)
  ignore(rows(w, at))
  // No cursor yet: a page down starts at the top, a page up at the bottom.
  ignore(press(w, 1, at, key(PageDown)))
  assert_eq(tree.cursor_line(), 0)
  ignore(press(w, 1, at, key(PageDown)))
  assert_eq(tree.cursor_line(), 4)
  ignore(press(w, 1, at, key(End)))
  assert_eq(tree.cursor_line(), 20)
  ignore(press(w, 1, at, key(PageUp)))
  assert_eq(tree.cursor_line(), 16)
  ignore(press(w, 1, at, key(Home)))
  assert_eq(tree.cursor_line(), 0)
  let fresh = forest(3)
  let f : &@widget.Widget = fresh
  ignore(rows(f, at))
  ignore(press(f, 1, at, key(PageUp)))
  assert_eq(fresh.cursor_line(), 3)
}

///|
test "tree leaves modified keys and plain sideways keys to others" {
  let w : &@widget.Widget = dune()
  let at = size(20, 5)
  let codes : Array[@event.KeyCode] = [PageUp, PageDown, Home, End, Enter]
  for code in codes {
    assert_eq(feed(w, at, shift_key(code)), (false, []))
  }
  let ctrl = @event.Mods::of_param(5)
  assert_eq(feed(w, at, Key(@event.Key::with_mods(Down, ctrl))), (false, []))
  assert_eq(feed(w, at, key(Left)), (false, []))
  assert_eq(feed(w, at, key(Right)), (false, []))
  assert_eq(feed(w, at, key(Escape)), (false, []))
  assert_eq(feed(w, at, Paste("x")), (false, []))
}

///|
test "tree hovers by the pointer and scrolls up with the wheel" {
  let tree = forest(20)
  let w : &@widget.Widget = tree
  let at = size(12, 5)
  ignore(rows(w, at))
  assert_eq(feed(w, at, mouse(Move, 3, 2)), (true, [Repaint(id=1)]))
  assert_eq(feed(w, at, mouse(Move, 3, 2)), (true, []))
  for _ in 0..<3 {
    ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  }
  ignore(feed(w, at, mouse(ScrollUp, 0, 0)))
  assert_eq(rows(w, at)[0].trim(), "├── n1")
  assert_eq(feed(w, at, mouse(Up, 0, 0)), (false, []))
}
