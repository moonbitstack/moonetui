// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn area_key(
  code : Int32,
  ctrl~ : Bool = false,
  alt~ : Bool = false,
  shift~ : Bool = false,
) -> @widget.Msg {
  Key({ code: Char(code), mods: { ctrl, alt, shift, }, })
}

///|
fn mod_key(
  code : @event.KeyCode,
  ctrl~ : Bool = false,
  alt~ : Bool = false,
  shift~ : Bool = false,
) -> @widget.Msg {
  Key({ code, mods: { ctrl, alt, shift, }, })
}

///|
fn area_press(
  w : &@widget.Widget,
  id : Int32,
  at : @geom.Size,
  msg : @widget.Msg,
) -> Bool {
  let ctx = @widget.Ctx::new(id, at)
  let held = w.handle(ctx, msg)
  for out in ctx.asked() {
    ignore(out)
  }
  held
}

///|
test "text area loads text and renders a gutter" {
  let area = @widget.TextArea::new(text="one\ntwo")
  assert_eq(area.text(), "one\ntwo")
  assert_eq(area.line_count(), 2)
  assert_eq(area.cursor(), (0, 0))
  let w : &@widget.Widget = area
  assert_eq(rows(w, size(8, 3)), [" 1 one  ", " 2 two  ", "        "])
}

///|
test "text area types, splits and joins lines" {
  let area = @widget.TextArea::new()
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, key(Char(97))))
  ignore(area_press(w, 1, at, key(Char(98))))
  assert_eq(area.text(), "ab")
  ignore(area_press(w, 1, at, key(Enter)))
  ignore(area_press(w, 1, at, key(Char(99))))
  ignore(area_press(w, 1, at, key(Char(100))))
  assert_eq(area.text(), "ab\ncd")
  assert_eq(area.cursor(), (1, 2))
  ignore(area_press(w, 1, at, key(Home)))
  assert_eq(area.cursor(), (1, 0))
  ignore(area_press(w, 1, at, key(Backspace)))
  assert_eq(area.text(), "abcd")
  assert_eq(area.cursor(), (0, 2))
}

///|
test "text area reports changes as messages" {
  let area = @widget.TextArea::new()
  let w : &@widget.Widget = area
  let out = press(w, 3, size(20, 4), key(Char(97)))
  assert_eq(out, [@widget.Changed(id=3, value="a"), @widget.Repaint(id=3)])
}

///|
test "text area smart home toggles between indent and column zero" {
  let area = @widget.TextArea::new(text="  ab")
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, key(End)))
  assert_eq(area.cursor(), (0, 4))
  ignore(area_press(w, 1, at, key(Home)))
  assert_eq(area.cursor(), (0, 2))
  ignore(area_press(w, 1, at, key(Home)))
  assert_eq(area.cursor(), (0, 0))
  ignore(area_press(w, 1, at, key(Home)))
  assert_eq(area.cursor(), (0, 2))
  ignore(area_press(w, 1, at, area_key(97, ctrl=true)))
  assert_eq(area.cursor(), (0, 0))
}

///|
test "text area walks words" {
  let area = @widget.TextArea::new(text="hello world")
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, key(End)))
  assert_eq(area.cursor(), (0, 11))
  ignore(area_press(w, 1, at, mod_key(Left, ctrl=true)))
  assert_eq(area.cursor(), (0, 6))
  ignore(area_press(w, 1, at, mod_key(Left, ctrl=true)))
  assert_eq(area.cursor(), (0, 0))
  ignore(area_press(w, 1, at, mod_key(Right, ctrl=true)))
  assert_eq(area.cursor(), (0, 5))
  ignore(area_press(w, 1, at, mod_key(Right, ctrl=true)))
  assert_eq(area.cursor(), (0, 11))
}

///|
test "text area selects with shift and replaces on typing" {
  let area = @widget.TextArea::new(text="hello world")
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, mod_key(Right, shift=true)))
  ignore(area_press(w, 1, at, mod_key(Right, shift=true)))
  ignore(area_press(w, 1, at, mod_key(Right, shift=true)))
  assert_eq(area.selected_text(), "hel")
  assert_eq(area.cursor(), (0, 3))
  ignore(area_press(w, 1, at, key(Char(74))))
  assert_eq(area.text(), "Jlo world")
  assert_eq(area.has_selection(), false)
}

///|
test "text area selects all, cuts and pastes through its own clipboard" {
  let area = @widget.TextArea::new(text="ab\ncd")
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, key(F(7))))
  assert_eq(area.selected_text(), "ab\ncd")
  ignore(area_press(w, 1, at, area_key(120, ctrl=true)))
  assert_eq(area.text(), "")
  ignore(area_press(w, 1, at, area_key(118, ctrl=true)))
  assert_eq(area.text(), "ab\ncd")
}

///|
test "text area deletes words, line halves and whole lines" {
  let area = @widget.TextArea::new(text="one two three")
  let w : &@widget.Widget = area
  let at = size(30, 4)
  ignore(area_press(w, 1, at, key(End)))
  ignore(area_press(w, 1, at, area_key(119, ctrl=true)))
  assert_eq(area.text(), "one two ")
  ignore(area_press(w, 1, at, area_key(117, ctrl=true)))
  assert_eq(area.text(), "")
  area.load_text("drop me")
  ignore(area_press(w, 1, at, area_key(107, ctrl=true)))
  assert_eq(area.text(), "")
  area.load_text("keep\ndrop\nthis")
  ignore(area_press(w, 1, at, key(Down)))
  ignore(area_press(w, 1, at, area_key(107, ctrl=true, shift=true)))
  assert_eq(area.text(), "keep\nthis")
}

///|
test "text area undoes a run of edits and redoes it back" {
  let area = @widget.TextArea::new()
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, key(Char(97))))
  ignore(area_press(w, 1, at, key(Char(98))))
  ignore(area_press(w, 1, at, key(Char(99))))
  assert_eq(area.text(), "abc")
  ignore(area_press(w, 1, at, area_key(122, ctrl=true)))
  assert_eq(area.text(), "")
  assert_eq(area.cursor(), (0, 0))
  ignore(area_press(w, 1, at, area_key(121, ctrl=true)))
  assert_eq(area.text(), "abc")
  assert_eq(area.cursor(), (0, 3))
  ignore(area_press(w, 1, at, area_key(122, ctrl=true)))
  ignore(area_press(w, 1, at, key(Char(120))))
  ignore(area_press(w, 1, at, key(Char(121))))
  assert_eq(area.text(), "xy")
  ignore(area_press(w, 1, at, key(Left)))
  ignore(area_press(w, 1, at, key(Char(33))))
  assert_eq(area.text(), "x!y")
  ignore(area_press(w, 1, at, area_key(122, ctrl=true)))
  assert_eq(area.text(), "xy")
}

///|
test "text area indents on tab when told to" {
  let area = @widget.TextArea::new(tab_indents=true)
  let w : &@widget.Widget = area
  let at = size(20, 4)
  assert_eq(area_press(w, 1, at, key(Tab)), true)
  assert_eq(area.text(), "    ")
  let plain : &@widget.Widget = @widget.TextArea::new()
  assert_eq(plain.handle(@widget.Ctx::new(1, at), key(Tab)), false)
}

///|
test "text area moves the caret by click and drag" {
  let area = @widget.TextArea::new(text="hello\nworld")
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(
    area_press(
      w,
      1,
      at,
      Mouse({ kind: Down, button: 0, x: 6, y: 1, mods: @event.none, }),
    ),
  )
  assert_eq(area.cursor(), (1, 3))
  ignore(
    area_press(
      w,
      1,
      at,
      Mouse({ kind: Move, button: 0, x: 7, y: 1, mods: @event.none, }),
    ),
  )
  assert_eq(area.cursor(), (1, 4))
  assert_eq(area.selected_text(), "l")
  ignore(
    area_press(
      w,
      1,
      at,
      Mouse({ kind: Up, button: 0, x: 7, y: 1, mods: @event.none, }),
    ),
  )
  assert_eq(area.has_selection(), true)
}

///|
test "text area keeps the caret on screen" {
  let area = @widget.TextArea::new(text="a\nb\nc\nd\ne")
  let w : &@widget.Widget = area
  let at = size(6, 2)
  ignore(area_press(w, 1, at, key(Down)))
  ignore(area_press(w, 1, at, key(Down)))
  ignore(area_press(w, 1, at, key(Down)))
  assert_eq(area.cursor(), (3, 0))
  assert_eq(rows(w, size(6, 2)), [" 3 c  ", " 4 d  "])
  ignore(area_press(w, 1, at, key(PageDown)))
  assert_eq(area.cursor(), (4, 0))
  assert_eq(rows(w, size(6, 2)), [" 4 d  ", " 5 e  "])
  ignore(area_press(w, 1, at, key(PageUp)))
  assert_eq(area.cursor(), (3, 0))
  assert_eq(rows(w, size(6, 2)), [" 4 d  ", " 5 e  "])
}

///|
test "text area scrolls sideways by columns, wide characters included" {
  let area = @widget.TextArea::new(
    text="中文中文中文",
    show_line_numbers=false,
  )
  let w : &@widget.Widget = area
  let at = size(6, 1)
  ignore(area_press(w, 1, at, key(End)))
  assert_eq(@strip.str_cells(w.render_line(0, at).text()), 6)
  assert_eq(area.offset(), (7, 0))
}

///|
test "text area pastes lines, whatever ends them, and reports the change" {
  let area = @widget.TextArea::new(text="ab")
  let w : &@widget.Widget = area
  let at = size(20, 6)
  ignore(press(w, 1, at, key(End)))
  let out = press(w, 1, at, Paste("1\r\n2\r3\n4"))
  assert_eq(area.text(), "ab1\n2\n3\n4")
  assert_eq(out, [Changed(id=1, value="ab1\n2\n3\n4"), Repaint(id=1)])
  // One paste is one undo.
  ignore(area.undo())
  assert_eq(area.text(), "ab")
}

///|
test "text area deletes forward, joining lines at an end" {
  let area = @widget.TextArea::new(text="ab\ncd")
  let w : &@widget.Widget = area
  let at = size(20, 4)
  ignore(area_press(w, 1, at, key(Delete)))
  assert_eq(area.text(), "b\ncd")
  ignore(area_press(w, 1, at, key(End)))
  ignore(area_press(w, 1, at, key(Delete)))
  assert_eq(area.text(), "bcd")
  ignore(area_press(w, 1, at, key(End)))
  ignore(area_press(w, 1, at, key(Delete)))
  assert_eq(area.text(), "bcd")
  ignore(area_press(w, 1, at, area_key(0x61, ctrl=true)))
  ignore(area_press(w, 1, at, area_key(0x64, ctrl=true)))
  assert_eq(area.text(), "cd")
}

///|
test "text area alt deletes whole words either side" {
  let area = @widget.TextArea::new(text="one two three")
  let w : &@widget.Widget = area
  let at = size(20, 3)
  for _ in 0..<4 {
    ignore(area_press(w, 1, at, key(Right)))
  }
  ignore(area_press(w, 1, at, mod_key(Delete, alt=true)))
  assert_eq(area.text(), "one  three")
  ignore(area_press(w, 1, at, mod_key(Backspace, alt=true)))
  assert_eq(area.text(), " three")
  assert_eq(area_press(w, 1, at, mod_key(Left, alt=true)), false)
}

///|
test "text area moves up and pages by the rows it shows" {
  let area = @widget.TextArea::new(
    text=Array::makei(10, i => "l\{i}").join("\n"),
  )
  let w : &@widget.Widget = area
  let at = size(10, 4)
  ignore(rows(w, at))
  ignore(area_press(w, 1, at, key(PageDown)))
  assert_eq(area.cursor(), (3, 0))
  ignore(area_press(w, 1, at, key(PageDown)))
  ignore(area_press(w, 1, at, key(PageDown)))
  ignore(area_press(w, 1, at, key(PageDown)))
  assert_eq(area.cursor(), (9, 0))
  ignore(area_press(w, 1, at, key(Up)))
  assert_eq(area.cursor(), (8, 0))
  ignore(area_press(w, 1, at, key(PageUp)))
  assert_eq(area.cursor(), (5, 0))
  ignore(area_press(w, 1, at, mod_key(PageUp, shift=true)))
  assert_eq(area.selected_text(), "l2\nl3\nl4\n")
}

///|
test "text area selects a line with F6 and everything with F7" {
  let area = @widget.TextArea::new(text="ab\ncd")
  let w : &@widget.Widget = area
  let at = size(10, 3)
  ignore(area_press(w, 1, at, key(F(6))))
  assert_eq(area.selected_text(), "ab")
  ignore(area_press(w, 1, at, key(F(7))))
  assert_eq(area.selected_text(), "ab\ncd")
  area.clear_selection()
  assert_eq(area.has_selection(), false)
}

///|
test "text area control keys edit by line and word" {
  let area = @widget.TextArea::new(text="alpha beta gamma\nnext")
  let w : &@widget.Widget = area
  let at = size(24, 3)
  ignore(area_press(w, 1, at, area_key(0x65, ctrl=true)))
  assert_eq(area.cursor(), (0, 16))
  ignore(area_press(w, 1, at, area_key(0x77, ctrl=true)))
  assert_eq(area.text(), "alpha beta \nnext")
  ignore(area_press(w, 1, at, mod_key(Backspace, ctrl=true)))
  assert_eq(area.text(), "alpha \nnext")
  ignore(area_press(w, 1, at, area_key(0x75, ctrl=true)))
  assert_eq(area.text(), "\nnext")
  ignore(area_press(w, 1, at, key(Down)))
  ignore(area_press(w, 1, at, area_key(0x6B, ctrl=true, shift=true)))
  assert_eq(area.text(), "")
}

///|
test "text area copies, and cut and paste need something to work on" {
  let area = @widget.TextArea::new(text="abc")
  let w : &@widget.Widget = area
  let at = size(10, 3)
  assert_eq(area_press(w, 1, at, area_key(0x63, ctrl=true)), false)
  assert_eq(area_press(w, 1, at, area_key(0x78, ctrl=true)), false)
  assert_eq(area_press(w, 1, at, area_key(0x76, ctrl=true)), false)
  ignore(area_press(w, 1, at, mod_key(Right, shift=true)))
  ignore(area_press(w, 1, at, area_key(0x63, ctrl=true)))
  ignore(area_press(w, 1, at, key(End)))
  ignore(area_press(w, 1, at, area_key(0x76, ctrl=true)))
  assert_eq(area.text(), "abca")
  let fresh : &@widget.Widget = @widget.TextArea::new()
  assert_eq(feed(fresh, at, area_key(0x79, ctrl=true)), (true, []))
  assert_eq(feed(fresh, at, area_key(0x7A, ctrl=true)), (true, []))
  assert_eq(feed(fresh, at, area_key(0x71, ctrl=true)), (false, []))
}

///|
test "text area keeps only so many undo steps" {
  let area = @widget.TextArea::new(history=2)
  let w : &@widget.Widget = area
  let at = size(10, 3)
  for code in [0x61, 0x62, 0x63] {
    ignore(area_press(w, 1, at, area_key(code)))
    ignore(area_press(w, 1, at, key(Left)))
    ignore(area_press(w, 1, at, key(Right)))
  }
  assert_eq(area.text(), "abc")
  assert_eq(area.undo(), true)
  assert_eq(area.undo(), true)
  assert_eq(area.undo(), false)
  assert_eq(area.text(), "a")
  assert_eq(area.redo(), true)
  assert_eq(area.text(), "ab")
}

///|
test "text area inserts by call and reads a selection across lines" {
  let area = @widget.TextArea::new(text="ab\ncd\nef")
  area.insert("X")
  assert_eq(area.text(), "Xab\ncd\nef")
  area.select_all()
  assert_eq(area.selected_text(), "Xab\ncd\nef")
  let w : &@widget.Widget = area
  let at = size(10, 3)
  let plain = @widget.TextArea::new(text="Xab\ncd\nef")
  let p : &@widget.Widget = plain
  assert_eq(rows(w, at), rows(p, at))
  assert_eq(w.render_line(1, at) != p.render_line(1, at), true)
}

///|
test "text area mouse: other buttons, stray releases and moves are not its business" {
  let area = @widget.TextArea::new(
    text=Array::makei(10, i => "l\{i}").join("\n"),
  )
  let w : &@widget.Widget = area
  let at = size(10, 3)
  let right = @widget.Msg::Mouse({
    kind: Down,
    button: 2,
    x: 0,
    y: 0,
    mods: @event.none,
  })
  assert_eq(feed(w, at, right), (false, []))
  assert_eq(feed(w, at, mouse(Up, 0, 0)), (false, []))
  assert_eq(feed(w, at, mouse(Move, 0, 0)), (false, []))
  ignore(rows(w, at))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  assert_eq(area.offset(), (0, 2))
  ignore(feed(w, at, mouse(ScrollUp, 0, 0)))
  ignore(rows(w, at))
  assert_eq(area.offset(), (0, 1))
  assert_eq(feed(w, at, Tick(16)), (false, []))
}

///|
test "text area: the wheel moves the view off the caret until the caret moves" {
  let area = @widget.TextArea::new(
    text=Array::makei(10, i => "l\{i}").join("\n"),
  )
  let w : &@widget.Widget = area
  let at = size(10, 3)
  ignore(rows(w, at))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  ignore(rows(w, at))
  assert_eq(area.offset(), (0, 2))
  assert_eq(area.cursor(), (0, 0))
  for _ in 0..<20 {
    ignore(feed(w, at, mouse(ScrollDown, 0, 0)))
  }
  ignore(rows(w, at))
  assert_eq(area.offset(), (0, 7))
  ignore(area_press(w, 1, at, key(Right)))
  ignore(rows(w, at))
  assert_eq(area.offset(), (0, 0))
}
