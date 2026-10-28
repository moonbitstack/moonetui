// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn button_style(line : @strip.Strip, label : String) -> @style.Style? {
  for seg in line.segs {
    if seg.text == label {
      return Some(seg.style)
    }
  }
  None
}

///|
test "a message box frames its question and its buttons" {
  let box = @widget.MessageBox::new(
    title="Quit",
    message="Discard unsaved work?",
    kind=Question,
    buttons=@widget.yes_no,
  )
  let w : &@widget.Widget = box
  assert_eq(rows(w, size(30, 6)), [
    "┌─────────── Quit ───────────┐",
    "│? Discard unsaved work?     │", "│                            │", "│                            │",
    "│         Yes    No          │", "└────────────────────────────┘",
  ])
}

///|
test "a message box wraps long text and asks for the room it needs" {
  let box = @widget.MessageBox::new(
    title="Note",
    message="one two three four five six seven eight nine ten",
    kind=Info,
  )
  let w : &@widget.Widget = box
  assert_eq(rows(w, size(20, 8)), [
    "┌────── Note ──────┐", "│i one two three   │",
    "│  four five six   │", "│  seven eight nine│", "│  ten             │",
    "│                  │", "│        OK        │", "└──────────────────┘",
  ])
  assert_eq(w.hint(size(60, 24)), size(54, 5))
  assert_eq(w.hint(size(20, 24)), size(20, 8))
}

///|
test "a message box takes a button by Enter and says which" {
  let box = @widget.MessageBox::new(
    title="Quit",
    message="Sure?",
    buttons=@widget.ok_cancel,
  )
  let w : &@widget.Widget = box
  ignore(press(w, 3, size(30, 5), key(Right)))
  assert_eq(box.highlighted(), 1)
  let out = press(w, 3, size(30, 5), key(Enter))
  assert_eq(out, [
    @widget.Selected(id=3, index=1),
    @widget.Dismissed(id=3),
    @widget.Repaint(id=3),
  ])
  assert_eq(box.chosen(), Some(1))
  assert_eq(box.label(), Some("Cancel"))
  assert_eq(box.is_answered(), true)
}

///|
test "a message box takes a button by its first letter, and Escape closes" {
  let box = @widget.MessageBox::new(
    message="Sure?",
    buttons=@widget.yes_no_cancel,
  )
  let w : &@widget.Widget = box
  let out = press(w, 3, size(40, 5), key(Char(110)))
  assert_eq(out, [
    @widget.Selected(id=3, index=1),
    @widget.Dismissed(id=3),
    @widget.Repaint(id=3),
  ])
  assert_eq(box.label(), Some("No"))
  assert_eq(press(w, 3, size(40, 5), key(Escape)), [@widget.Dismissed(id=3)])
  assert_eq(press(w, 3, size(40, 5), key(Char(122))), [])
}

///|
test "a message box takes a click on a button and focus on the rest" {
  let box = @widget.MessageBox::new(message="Sure?", buttons=@widget.ok_cancel)
  let w : &@widget.Widget = box
  // The buttons are centred on the row above the bottom edge, one column in.
  let out = press(
    w,
    5,
    size(30, 5),
    Mouse({ kind: Down, button: 0, x: 8, y: 3, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=5),
    @widget.Selected(id=5, index=0),
    @widget.Dismissed(id=5),
    @widget.Repaint(id=5),
  ])
  let missed = @widget.MessageBox::new(
    message="Sure?",
    buttons=@widget.ok_cancel,
  )
  let w2 : &@widget.Widget = missed
  assert_eq(
    press(
      w2,
      5,
      size(30, 5),
      Mouse({ kind: Down, button: 0, x: 25, y: 3, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=5)],
  )
  assert_eq(
    press(
      w2,
      5,
      size(30, 5),
      Mouse({ kind: Move, button: 0, x: 8, y: 3, mods: @event.none, }),
    ),
    [],
  )
}

///|
test "a message box with no buttons takes no keys but keeps focus" {
  let box = @widget.MessageBox::new(title="Wait", message="Wait", buttons=[])
  let w : &@widget.Widget = box
  assert_eq(box.highlighted(), -1)
  assert_eq(press(w, 1, size(20, 5), key(Right)), [])
  assert_eq(w.focusable(), true)
  ignore(press(w, 1, size(20, 5), Focus(true)))
  assert_eq(
    box.render_line(0, size(20, 5)).text(),
    "┌────── Wait ──────┐",
  )
}

///|
test "a message box too small to draw is blank" {
  let box = @widget.MessageBox::new(title="Wait", message="Wait")
  assert_eq(box.render_line(0, size(1, 4)).text(), " ")
  assert_eq(box.render_line(0, size(20, 1)).text(), "                    ")
}

///|
test "an input box shows the prompt, the field and the buttons" {
  let box = @widget.InputBox::new(
    title="Rename",
    prompt="New name",
    value="draft",
    buttons=@widget.ok_cancel,
  )
  let w : &@widget.Widget = box
  assert_eq(rows(w, size(30, 5)), [
    "┌────────── Rename ──────────┐",
    "│New name                    │", "│draft                       │", "│        OK    Cancel        │",
    "└────────────────────────────┘",
  ])
  assert_eq(w.hint(size(60, 24)), size(40, 5))
}

///|
test "an input box takes typing into the field and reports the draft" {
  let box = @widget.InputBox::new(prompt="Name")
  let w : &@widget.Widget = box
  let out = press(w, 2, size(30, 5), key(Char(104)))
  assert_eq(out, [@widget.Changed(id=2, value="h"), @widget.Repaint(id=2)])
  ignore(press(w, 2, size(30, 5), key(Char(105))))
  assert_eq(box.text(), "hi")
  assert_eq(press(w, 2, size(30, 5), key(Tab)), [@widget.Repaint(id=2)])
  assert_eq(press(w, 2, size(30, 5), key(Up)), [@widget.Repaint(id=2)])
}

///|
test "an input box answers with the button it was given" {
  let box = @widget.InputBox::new(prompt="Name", value="moon")
  let w : &@widget.Widget = box
  ignore(press(w, 4, size(30, 5), Focus(true)))
  let out = press(w, 4, size(30, 5), key(Enter))
  assert_eq(out, [
    @widget.Selected(id=4, index=0),
    @widget.Dismissed(id=4),
    @widget.Repaint(id=4),
  ])
  assert_eq(box.label(), Some("OK"))
  assert_eq(box.text(), "moon")
  assert_eq(box.is_answered(), true)
}

///|
test "Escape takes the last button of an input box" {
  let box = @widget.InputBox::new(prompt="Name")
  let w : &@widget.Widget = box
  let out = press(w, 4, size(30, 5), key(Escape))
  assert_eq(out, [
    @widget.Selected(id=4, index=1),
    @widget.Dismissed(id=4),
    @widget.Repaint(id=4),
  ])
  assert_eq(box.label(), Some("Cancel"))
}

///|
test "an input box moves between its buttons in a ring" {
  let box = @widget.InputBox::new(prompt="Name", buttons=@widget.yes_no_cancel)
  let w : &@widget.Widget = box
  let line = () => box.render_line(3, size(30, 5))
  assert_eq(
    button_style(line(), " Yes "),
    Some(@style.Style::new(reverse=true)),
  )
  ignore(press(w, 4, size(30, 5), key(Right)))
  assert_eq(button_style(line(), " No "), Some(@style.Style::new(reverse=true)))
  assert_eq(button_style(line(), " Yes "), Some(@style.Style::new()))
  ignore(press(w, 4, size(30, 5), key(Left)))
  ignore(press(w, 4, size(30, 5), key(Left)))
  assert_eq(
    button_style(line(), " Cancel "),
    Some(@style.Style::new(reverse=true)),
  )
}

///|
test "an input box takes a click on a button and a paste into the field" {
  let box = @widget.InputBox::new(prompt="Name")
  let w : &@widget.Widget = box
  assert_eq(
    press(
      w,
      6,
      size(30, 5),
      Mouse({ kind: Down, button: 0, x: 8, y: 3, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=6),
      @widget.Selected(id=6, index=0),
      @widget.Dismissed(id=6),
      @widget.Repaint(id=6),
    ],
  )
  let other = @widget.InputBox::new(prompt="Name")
  let w2 : &@widget.Widget = other
  ignore(press(w2, 6, size(30, 5), Paste("moon")))
  assert_eq(other.text(), "moon")
  assert_eq(
    press(
      w2,
      6,
      size(30, 5),
      Mouse({ kind: Down, button: 0, x: 5, y: 1, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=6), @widget.Repaint(id=6)],
  )
}

///|
test "an input box keeps the caret in the field it draws" {
  let box = @widget.InputBox::new(prompt="Name", value="moon")
  let w : &@widget.Widget = box
  ignore(press(w, 1, size(30, 5), Focus(true)))
  let line = box.render_line(2, size(30, 5))
  assert_eq(line.text().contains("moon"), true)
  box.set("etui")
  assert_eq(box.text(), "etui")
  box.set_prompt("File")
  box.set_title("Open")
  assert_eq(box.render_line(1, size(30, 5)).text().has_prefix("│File"), true)
}
