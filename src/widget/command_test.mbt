// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn commands() -> Array[@widget.Command] {
  [
    @widget.Command::new("Open file", hint="read one in", key="ctrl-o"),
    @widget.Command::new("Save file", hint="write it out", key="ctrl-s"),
    @widget.Command::new("Quit", key="ctrl-q"),
  ]
}

///|
test "a palette shows its field and every command" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  let lines = rows(w, size(40, 8))
  assert_eq(lines[0], "┌" + "─".repeat(38) + "┐")
  assert_eq(lines[1].has_prefix("│>"), true)
  assert_eq(lines[2], "├" + "─".repeat(38) + "┤")
  assert_eq(lines[3].has_prefix("│ Open file  read one in"), true)
  assert_eq(lines[3].trim_end().has_suffix("ctrl-o │"), true)
  assert_eq(lines[5].trim_end().has_suffix("ctrl-q │"), true)
  assert_eq(lines[3].length(), 40)
  assert_eq(lines[6].has_prefix("│ "), true)
  assert_eq(lines[6].has_suffix(" │"), true)
  assert_eq(lines[7], "└" + "─".repeat(38) + "┘")
  assert_eq(w.hint(size(40, 24)), size(40, 8))
}

///|
test "typing narrows the list to what matches in order" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  let out = press(w, 2, size(30, 8), key(Char(111)))
  assert_eq(out, [@widget.Changed(id=2, value="o"), @widget.Repaint(id=2)])
  assert_eq(palette.matches().length(), 1)
  ignore(press(w, 2, size(30, 8), key(Char(112))))
  assert_eq(palette.query(), "op")
  assert_eq(palette.matches(), [0])
  ignore(press(w, 2, size(30, 8), key(Backspace)))
  assert_eq(palette.query(), "o")
  assert_eq(palette.matches().length(), 1)
  assert_eq(press(w, 2, size(30, 8), key(Backspace)), [
    @widget.Changed(id=2, value=""),
    @widget.Repaint(id=2),
  ])
}

///|
test "a query that is not there leaves the list empty" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  ignore(press(w, 2, size(30, 8), key(Char(122))))
  ignore(press(w, 2, size(30, 8), key(Char(122))))
  assert_eq(palette.matches(), [])
  assert_eq(press(w, 2, size(30, 8), key(Enter)), [])
  assert_eq(press(w, 2, size(30, 8), key(Down)), [])
  assert_eq(w.hint(size(40, 24)), size(40, 5))
}

///|
test "a palette runs the command highlighted and remembers it" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  ignore(press(w, 3, size(30, 8), key(Down)))
  let out = press(w, 3, size(30, 8), key(Enter))
  assert_eq(out, [@widget.Selected(id=3, index=1), @widget.Repaint(id=3)])
  assert_eq(palette.run(), Some(1))
  assert_eq(press(w, 3, size(30, 8), key(Escape)), [@widget.Dismissed(id=3)])
}

///|
test "a palette moves to either end of the matches and by a page" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  ignore(press(w, 3, size(30, 8), key(End)))
  assert_eq(palette.run(), None)
  ignore(press(w, 3, size(30, 8), key(Enter)))
  assert_eq(palette.run(), Some(2))
  ignore(press(w, 3, size(30, 8), key(Home)))
  ignore(press(w, 3, size(30, 8), key(Enter)))
  assert_eq(palette.run(), Some(0))
  assert_eq(press(w, 3, size(30, 8), key(Up)), [])
  ignore(press(w, 3, size(30, 8), key(PageDown)))
  ignore(press(w, 3, size(30, 8), key(Enter)))
  assert_eq(palette.run(), Some(2))
}

///|
test "a palette takes a click on a command and a paste into the field" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  // The list starts three rows down: the frame, the field and the rule.
  assert_eq(
    press(
      w,
      4,
      size(30, 8),
      Mouse({ kind: Down, button: 0, x: 5, y: 4, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=4),
      @widget.Selected(id=4, index=1),
      @widget.Repaint(id=4),
    ],
  )
  let other = @widget.CommandPalette::new(commands=commands())
  let w2 : &@widget.Widget = other
  let pasted = press(w2, 4, size(30, 8), Paste("save"))
  assert_eq(pasted, [@widget.Changed(id=4, value="save"), @widget.Repaint(id=4)])
  assert_eq(other.matches(), [1])
}

///|
test "the wheel scrolls a list longer than the window" {
  let palette = @widget.CommandPalette::new()
  for i in 0..<12 {
    palette.add("Command " + i.to_string())
  }
  let w : &@widget.Widget = palette
  assert_eq(w.hint(size(30, 24)), size(30, 15))
  assert_eq(
    press(
      w,
      4,
      size(30, 8),
      Mouse({ kind: ScrollDown, button: 0, x: 5, y: 4, mods: @event.none, }),
    ),
    [@widget.Repaint(id=4)],
  )
  assert_eq(
    palette.render_line(3, size(30, 8)).text().contains("Command 1"),
    true,
  )
  assert_eq(
    press(
      w,
      4,
      size(30, 8),
      Mouse({ kind: ScrollUp, button: 0, x: 5, y: 4, mods: @event.none, }),
    ),
    [@widget.Repaint(id=4)],
  )
  assert_eq(
    palette.render_line(3, size(30, 8)).text().contains("Command 0"),
    true,
  )
}

///|
test "a focused palette marks the row it is on" {
  let palette = @widget.CommandPalette::new(commands=commands())
  let w : &@widget.Widget = palette
  ignore(press(w, 1, size(30, 8), Focus(true)))
  assert_eq(
    palette.render_line(3, size(30, 8)).segs[1].style,
    @style.Style::new(reverse=true),
  )
  ignore(press(w, 1, size(30, 8), Focus(false)))
  assert_eq(
    palette.render_line(3, size(30, 8)).segs[1].style,
    @style.Style::new(dim=true, reverse=true),
  )
}

///|
test "a palette with nothing to show is an empty list" {
  let palette = @widget.CommandPalette::new()
  let w : &@widget.Widget = palette
  assert_eq(palette.matches(), [])
  assert_eq(palette.query(), "")
  assert_eq(palette.commands().length(), 0)
  assert_eq(w.hint(size(30, 24)), size(30, 5))
  assert_eq(palette.render_line(0, size(1, 8)).text(), " ")
  palette.set_query("q")
  assert_eq(palette.query(), "q")
}

///|
test "a score reads the query out of the name in order" {
  let palette = @widget.CommandPalette::new(commands=[
    @widget.Command::new("Open file"),
    @widget.Command::new("Save file"),
    @widget.Command::new("Close"),
  ])
  palette.set_query("op")
  assert_eq(palette.matches(), [0])
  palette.set_query("oe")
  assert_eq(
    palette.matches(),
    [0, 2],
    msg="oe reads out of Open file and Close",
  )
  palette.set_query("sf")
  assert_eq(palette.matches(), [1])
  palette.set_query("file")
  assert_eq(palette.matches(), [0, 1])
  palette.set_query("close")
  assert_eq(palette.matches(), [2])
  palette.set_query("zz")
  assert_eq(palette.matches(), [])
}
