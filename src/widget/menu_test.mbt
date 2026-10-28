// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn file_items() -> Array[@widget.Item] {
  [
    @widget.Item::new("New", shortcut="ctrl-n"),
    @widget.Item::new("Open", shortcut="ctrl-o"),
    @widget.Item::separator(),
    @widget.Item::new("Wrap", checked=true),
    @widget.Item::new("Quit", shortcut="ctrl-q"),
  ]
}

///|
test "a menu lists its items with their ticks and shortcuts" {
  let menu = @widget.Menu::new(items=file_items())
  let w : &@widget.Widget = menu
  assert_eq(rows(w, size(20, 7)), [
    "┌──────────────────┐", "│   New     ctrl-n │",
    "│   Open    ctrl-o │", "├──────────────────┤",
    "│ ✓ Wrap           │", "│   Quit    ctrl-q │", "└──────────────────┘",
  ])
  assert_eq(w.hint(size(40, 24)), size(18, 7))
}

///|
test "a menu moves over its items and takes the one highlighted" {
  let menu = @widget.Menu::new(items=file_items())
  let w : &@widget.Widget = menu
  assert_eq(menu.highlighted(), 0)
  ignore(press(w, 2, size(20, 7), key(Down)))
  assert_eq(menu.highlighted(), 1)
  ignore(press(w, 2, size(20, 7), key(Down)))
  assert_eq(menu.highlighted(), 3, msg="the rule is skipped")
  let out = press(w, 2, size(20, 7), key(Enter))
  assert_eq(out, [@widget.Selected(id=2, index=3), @widget.Repaint(id=2)])
  assert_eq(menu.taken(), Some(3))
}

///|
test "a menu wraps around and goes to either end" {
  let menu = @widget.Menu::new(items=file_items())
  let w : &@widget.Widget = menu
  ignore(press(w, 2, size(20, 7), key(End)))
  assert_eq(menu.highlighted(), 4)
  assert_eq(press(w, 2, size(20, 7), key(Down)), [@widget.Repaint(id=2)])
  assert_eq(menu.highlighted(), 0)
  ignore(press(w, 2, size(20, 7), key(Up)))
  assert_eq(menu.highlighted(), 4)
  ignore(press(w, 2, size(20, 7), key(Home)))
  assert_eq(menu.highlighted(), 0)
  assert_eq(press(w, 2, size(20, 7), key(Escape)), [@widget.Dismissed(id=2)])
}

///|
test "a menu takes a click on an item and follows a move over one" {
  let menu = @widget.Menu::new(items=file_items())
  let w : &@widget.Widget = menu
  let out = press(
    w,
    3,
    size(20, 7),
    Mouse({ kind: Down, button: 0, x: 5, y: 2, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=3),
    @widget.Selected(id=3, index=1),
    @widget.Repaint(id=3),
  ])
  let hover = @widget.Menu::new(items=file_items())
  let w2 : &@widget.Widget = hover
  assert_eq(
    press(
      w2,
      3,
      size(20, 7),
      Mouse({ kind: Move, button: 0, x: 5, y: 5, mods: @event.none, }),
    ),
    [@widget.Repaint(id=3)],
  )
  assert_eq(hover.highlighted(), 4)
  assert_eq(
    press(
      w2,
      3,
      size(20, 7),
      Mouse({ kind: Move, button: 0, x: 5, y: 3, mods: @event.none, }),
    ),
    [],
  )
  assert_eq(
    press(
      w2,
      3,
      size(20, 7),
      Mouse({ kind: Up, button: 0, x: 5, y: 5, mods: @event.none, }),
    ),
    [],
  )
}

///|
test "a menu skips what is off and says when it has nothing to take" {
  let menu = @widget.Menu::new(items=[
    @widget.Item::new("Off", enabled=false),
    @widget.Item::new("On"),
  ])
  let w : &@widget.Widget = menu
  assert_eq(menu.highlighted(), 1)
  assert_eq(press(w, 2, size(20, 4), key(Enter)), [
    @widget.Selected(id=2, index=1),
    @widget.Repaint(id=2),
  ])
  let empty = @widget.Menu::new()
  let w2 : &@widget.Widget = empty
  assert_eq(empty.highlighted(), -1)
  assert_eq(press(w2, 2, size(20, 2), key(Down)), [])
  assert_eq(press(w2, 2, size(20, 2), key(Enter)), [])
  assert_eq(w2.hint(size(20, 20)), size(6, 2))
}

///|
test "a menu bar shows its titles and drops a list under one" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  assert_eq(w.hint(size(40, 24)), size(40, 1))
  assert_eq(
    bar.render_line(0, size(40, 1)).text().has_prefix(" File  Help"),
    true,
  )
  let out = press(w, 1, size(40, 8), key(Down))
  assert_eq(out, [@widget.Repaint(id=1)])
  assert_eq(bar.is_open(), true)
  assert_eq(bar.opened(), 0)
  assert_eq(w.hint(size(40, 24)), size(40, 8))
  let bar_line = bar.render_line(0, size(40, 8))
  assert_eq(bar_line.text().has_prefix(" File  Help"), true)
  assert_eq(bar_line.cell_length(), 40)
  assert_eq(
    bar
    .render_line(1, size(40, 8))
    .text()
    .has_prefix("┌────────────────┐"),
    true,
  )
  assert_eq(
    bar.render_line(2, size(40, 8)).text().has_prefix("│   New   ctrl-n │"),
    true,
  )
  assert_eq(
    bar
    .render_line(4, size(40, 8))
    .text()
    .has_prefix("├────────────────┤"),
    true,
  )
  assert_eq(
    bar
    .render_line(7, size(40, 8))
    .text()
    .has_prefix("└────────────────┘"),
    true,
  )
  assert_eq(bar.render_line(7, size(40, 8)).cell_length(), 40)
}

///|
test "a menu bar walks along its titles with the list open" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  ignore(press(w, 1, size(40, 8), key(Down)))
  ignore(press(w, 1, size(40, 8), key(Right)))
  assert_eq(bar.opened(), 1)
  // The list drops under its own title, so the second one starts five columns in.
  assert_eq(
    bar.render_line(1, size(40, 8)).text().has_prefix("      ┌"),
    true,
  )
  ignore(press(w, 1, size(40, 8), key(Left)))
  assert_eq(bar.opened(), 0)
}

///|
test "a menu bar opens a title by its first letter and closes on Escape" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  assert_eq(press(w, 1, size(40, 8), key(Char(104))), [@widget.Repaint(id=1)])
  assert_eq(bar.opened(), -1)
  assert_eq(press(w, 1, size(40, 8), key(Enter)), [@widget.Repaint(id=1)])
  assert_eq(bar.opened(), 1)
  assert_eq(press(w, 1, size(40, 8), key(Escape)), [@widget.Repaint(id=1)])
  assert_eq(bar.opened(), -1)
  assert_eq(press(w, 1, size(40, 8), key(Char(122))), [])
}

///|
test "a menu bar takes an item and says which menu it came from" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  ignore(press(w, 5, size(40, 8), key(Down)))
  ignore(press(w, 5, size(40, 8), key(Down)))
  let out = press(w, 5, size(40, 8), key(Enter))
  assert_eq(out, [
    @widget.MenuPicked(id=5, menu=0, index=1),
    @widget.Repaint(id=5),
  ])
  assert_eq(bar.taken(), Some((0, 1)))
  assert_eq(bar.is_open(), false)
}

///|
test "a menu bar opens on a click on a title and closes on a second" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  assert_eq(
    press(
      w,
      5,
      size(40, 8),
      Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=5), @widget.Repaint(id=5)],
  )
  assert_eq(bar.opened(), 0)
  assert_eq(
    press(
      w,
      5,
      size(40, 8),
      Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=5), @widget.Repaint(id=5)],
  )
  assert_eq(bar.opened(), -1)
}

///|
test "a menu bar takes an item clicked in an open list" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  ignore(press(w, 5, size(40, 8), key(Down)))
  let out = press(
    w,
    5,
    size(40, 8),
    Mouse({ kind: Down, button: 0, x: 5, y: 3, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=5),
    @widget.MenuPicked(id=5, menu=0, index=1),
    @widget.Repaint(id=5),
  ])
  assert_eq(bar.taken(), Some((0, 1)))
}

///|
test "a menu bar follows a move along its titles and blurs by closing" {
  let bar = @widget.MenuBar::new()
  bar.add("File", file_items())
  bar.add("Help", [@widget.Item::new("About")])
  let w : &@widget.Widget = bar
  assert_eq(
    press(
      w,
      5,
      size(40, 8),
      Mouse({ kind: Move, button: 0, x: 8, y: 0, mods: @event.none, }),
    ),
    [@widget.Repaint(id=5)],
  )
  assert_eq(
    press(
      w,
      5,
      size(40, 8),
      Mouse({ kind: Move, button: 0, x: 8, y: 4, mods: @event.none, }),
    ),
    [],
  )
  ignore(press(w, 5, size(40, 8), Focus(true)))
  ignore(press(w, 5, size(40, 8), key(Down)))
  ignore(press(w, 5, size(40, 8), Focus(false)))
  assert_eq(bar.is_open(), false)
}

///|
test "an empty menu bar takes nothing" {
  let bar = @widget.MenuBar::new()
  let w : &@widget.Widget = bar
  assert_eq(bar.titles(), [])
  assert_eq(press(w, 1, size(40, 8), key(Down)), [])
  assert_eq(w.hint(size(40, 24)), size(40, 1))
  assert_eq(w.focusable(), true)
}

///|
test "a menu bar's list is clipped to the room it has" {
  let bar = @widget.MenuBar::new()
  bar.add("One", [@widget.Item::new("First")])
  bar.add("Two", [@widget.Item::new("Item"), @widget.Item::new("b")])
  let w : &@widget.Widget = bar
  ignore(press(w, 1, size(14, 5), key(Right)))
  assert_eq(bar.opened(), -1)
  ignore(press(w, 1, size(14, 5), key(Down)))
  assert_eq(bar.opened(), 1)
  // The second title starts four columns in, and the list is as wide as the box
  // lets it be, so it is held against the right edge.
  assert_eq(bar.render_line(1, size(14, 5)).text().has_prefix("    ┌"), true)
  assert_eq(w.hint(size(14, 5)), size(14, 5))
}

///|
test "a menu takes no notice of a click past its items" {
  let menu = @widget.Menu::new(items=[@widget.Item::new("a")])
  let w : &@widget.Widget = menu
  assert_eq(
    press(
      w,
      1,
      size(10, 5),
      Mouse({ kind: Down, button: 0, x: 1, y: 4, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  assert_eq(menu.taken(), None)
  assert_eq(
    press(
      w,
      1,
      size(10, 5),
      Mouse({ kind: Move, button: 0, x: 1, y: 4, mods: @event.none, }),
    ),
    [],
  )
}

///|
test "a menu skips a rule and what is off under the pointer" {
  let menu = @widget.Menu::new(items=[
    @widget.Item::separator(),
    @widget.Item::new("off", enabled=false),
    @widget.Item::new("on"),
  ])
  let w : &@widget.Widget = menu
  assert_eq(menu.highlighted(), 2)
  assert_eq(
    press(
      w,
      1,
      size(10, 5),
      Mouse({ kind: Down, button: 0, x: 1, y: 1, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  assert_eq(menu.taken(), None)
}

///|
test "a menu's hint is capped by the room it is given" {
  let menu = @widget.Menu::new(items=[@widget.Item::new("a very long item")])
  let w : &@widget.Widget = menu
  assert_eq(menu.width_of(), 22)
  assert_eq(w.hint(size(10, 8)), size(10, 3))
  assert_eq(menu.render_line(0, size(1, 3)).text(), " ")
  menu.set_items([@widget.Item::new("b")])
  assert_eq(menu.items().length(), 1)
}

///|
test "a menu bar takes no keys with a modifier and no click below a closed bar" {
  let bar = @widget.MenuBar::new()
  bar.add("File", [@widget.Item::new("New")])
  let w : &@widget.Widget = bar
  assert_eq(
    press(
      w,
      1,
      size(12, 5),
      Key(@event.Key::with_mods(Down, @event.Mods::of_param(5))),
    ),
    [],
  )
  assert_eq(
    press(
      w,
      1,
      size(12, 5),
      Mouse({ kind: Down, button: 0, x: 1, y: 2, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  assert_eq(bar.opened(), -1)
  assert_eq(
    press(
      w,
      1,
      size(12, 5),
      Mouse({ kind: Move, button: 0, x: 40, y: 0, mods: @event.none, }),
    ),
    [],
  )
}

///|
test "a menu bar walks along its titles while closed and opens by Enter" {
  let bar = @widget.MenuBar::new()
  bar.add("File", [@widget.Item::new("New")])
  bar.add("Edit", [@widget.Item::new("Undo")])
  let w : &@widget.Widget = bar
  assert_eq(press(w, 1, size(16, 5), key(Left)), [@widget.Repaint(id=1)])
  assert_eq(bar.opened(), -1)
  assert_eq(press(w, 1, size(16, 5), key(Enter)), [@widget.Repaint(id=1)])
  assert_eq(bar.opened(), 1)
  assert_eq(bar.taken(), None)
  bar.close()
  assert_eq(bar.opened(), -1)
  assert_eq(bar.titles(), ["File", "Edit"])
}

///|
test "a menu bar picks an item clicked outside its list's width" {
  let bar = @widget.MenuBar::new()
  bar.add("File", [@widget.Item::new("New"), @widget.Item::new("Quit")])
  let w : &@widget.Widget = bar
  ignore(press(w, 1, size(20, 6), key(Down)))
  // Past the right edge of the dropped list: no item there to take.
  assert_eq(
    press(
      w,
      1,
      size(20, 6),
      Mouse({ kind: Down, button: 0, x: 19, y: 3, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  assert_eq(bar.taken(), None)
}
