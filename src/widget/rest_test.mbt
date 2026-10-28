// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a clock reads the time and counts itself forward" {
  let clock = @widget.Clock::new(hour=9, minute=8, second=7)
  assert_eq(clock.text(), "09:08:07")
  assert_eq(clock.hour(), 9)
  assert_eq(clock.minute(), 8)
  assert_eq(clock.second(), 7)
  assert_eq(clock.seconds(), 9 * 3600 + 8 * 60 + 7)
  assert_eq(clock.advance(500), false)
  assert_eq(clock.text(), "09:08:07")
  assert_eq(clock.advance(500), true)
  assert_eq(clock.text(), "09:08:08")
}

///|
test "a clock wraps at midnight and takes no step backwards" {
  let clock = @widget.Clock::new(hour=23, minute=59, second=59)
  assert_eq(clock.advance(1000), true)
  assert_eq(clock.text(), "00:00:00")
  assert_eq(clock.advance(0), false)
  assert_eq(clock.advance(-5), false)
  clock.set(hour=25, minute=70, second=-1)
  assert_eq(clock.text(), "01:10:59")
  assert_eq(clock.advance(3600_000), true)
  assert_eq(clock.text(), "02:10:59")
}

///|
test "a header keeps a clock beside its note" {
  let head = @widget.Header::new(
    "moonetui",
    note="v1",
    clock=Some(@widget.Clock::new(hour=12, minute=34, second=56)),
  )
  let w : &@widget.Widget = head
  assert_eq(w.render_line(0, size(20, 1)).text(), "moonetui 12:34:56 v1")
  assert_eq(head.time(), Some("12:34:56"))
  assert_eq(press(w, 1, size(20, 1), Tick(1000)), [@widget.Repaint(id=1)])
  assert_eq(head.time(), Some("12:34:57"))
  assert_eq(press(w, 1, size(20, 1), Tick(100)), [])
  head.set_clock(None)
  assert_eq(head.time(), None)
  assert_eq(press(w, 1, size(20, 1), Tick(1000)), [])
}

///|
test "a header without a clock is the bar it always was" {
  let head = @widget.Header::new("moonetui", note="v0")
  let w : &@widget.Widget = head
  assert_eq(w.render_line(0, size(14, 1)).text(), "  moonetui  v0")
  assert_eq(head.time(), None)
  assert_eq(w.render_line(1, size(14, 2)).text(), "              ")
}

///|
test "a content switcher shows one child and gives it the input" {
  let first = @widget.Button::new("one")
  let second = @widget.Button::new("two")
  let switcher = @widget.ContentSwitcher::new(children=[first, second])
  let w : &@widget.Widget = switcher
  assert_eq(switcher.current(), 0)
  assert_eq(switcher.count(), 2)
  assert_eq(rows(w, size(10, 1)), ["   one    "])
  switcher.switch_to(1)
  assert_eq(rows(w, size(10, 1)), ["   two    "])
  let out = press(w, 3, size(10, 1), key(Enter))
  assert_eq(out, [@widget.Pressed(id=3)])
}

///|
test "a content switcher is focusable as the child it shows" {
  let off : &@widget.Widget = @widget.Static::new("read only")
  let on : &@widget.Widget = @widget.Button::new("go")
  let switcher = @widget.ContentSwitcher::new(children=[off, on])
  let w : &@widget.Widget = switcher
  assert_eq(w.focusable(), false)
  switcher.switch_to(1)
  assert_eq(w.focusable(), true)
  assert_eq(press(w, 1, size(10, 1), Focus(true)) |> ignore, ())
  switcher.switch_to(-1)
  assert_eq(switcher.current(), 0)
}

///|
test "a content switcher with nothing in it is empty" {
  let switcher = @widget.ContentSwitcher::new()
  let w : &@widget.Widget = switcher
  assert_eq(switcher.current(), -1)
  assert_eq(w.focusable(), false)
  assert_eq(rows(w, size(6, 1)), ["      "])
  assert_eq(w.hint(size(6, 1)), size(6, 0))
  switcher.add(@widget.Static::new("later"))
  assert_eq(switcher.count(), 1)
  assert_eq(switcher.current(), 0)
  switcher.switch_to(4)
  assert_eq(switcher.current(), 0)
}

///|
test "a pretty prints a value with an indent and colours" {
  let pretty = @widget.Pretty::new(
    value=VObj([
      ("n", VStr("a")),
      ("t", VArr([VStr("aa"), VStr("bb"), VStr("cc")])),
    ]),
  )
  let w : &@widget.Widget = pretty
  let lines = rows(w, size(14, 8))
  assert_eq(lines[0].trim_end(), "{")
  assert_eq(lines[1].trim_end(), "  n: \"a\",")
  assert_eq(lines[2].trim_end(), "  t: [")
  assert_eq(lines[3].trim_end(), "    \"aa\",")
  assert_eq(lines[4].trim_end(), "    \"bb\",")
  assert_eq(lines[5].trim_end(), "    \"cc\"")
  assert_eq(lines[6].trim_end(), "  ]")
  assert_eq(lines[7].trim_end(), "}")
  assert_eq(w.hint(size(14, 20)), size(14, 8))
}

///|
test "a pretty prints on one line when the value fits" {
  let pretty = @widget.Pretty::new(value=VArr([VInt(1), VInt(2)]))
  let w : &@widget.Widget = pretty
  assert_eq(rows(w, size(22, 1))[0].trim_end(), "[1, 2]")
  assert_eq(w.hint(size(22, 20)), size(22, 1))
  pretty.set(VNil)
  assert_eq(pretty.value(), VNil)
  assert_eq(rows(w, size(22, 1))[0].trim_end(), "nil")
}

///|
test "a pretty scrolls a value taller than its box" {
  let items : Array[@widget.Value] = []
  for i in 0..<10 {
    items.push(VInt(i))
  }
  let pretty = @widget.Pretty::new(value=VArr(items))
  let w : &@widget.Widget = pretty
  assert_eq(w.hint(size(12, 20)), size(12, 12))
  assert_eq(press(w, 2, size(12, 4), key(Down)), [@widget.Repaint(id=2)])
  assert_eq(pretty.offset(), 1)
  assert_eq(pretty.render_line(0, size(12, 4)).text().contains("0,"), true)
  ignore(press(w, 2, size(12, 4), key(End)))
  assert_eq(pretty.offset(), 8)
  assert_eq(press(w, 2, size(12, 4), key(Down)), [])
  ignore(press(w, 2, size(12, 4), key(Home)))
  assert_eq(pretty.offset(), 0)
  assert_eq(
    press(
      w,
      2,
      size(12, 4),
      Mouse({ kind: ScrollDown, button: 0, x: 1, y: 1, mods: @event.none, }),
    ),
    [@widget.Repaint(id=2)],
  )
  assert_eq(w.focusable(), true)
}

///|
test "a masked input takes what its mask allows" {
  let field = @widget.MaskedInput::new("(###) ###-####")
  let w : &@widget.Widget = field
  assert_eq(field.text(), "(___) ___-____")
  assert_eq(field.is_complete(), false)
  let out = press(w, 1, size(16, 1), key(Char(53)))
  assert_eq(out, [
    @widget.Changed(id=1, value="(5__) ___-____"),
    @widget.Repaint(id=1),
  ])
  assert_eq(
    press(w, 1, size(16, 1), key(Char(97))),
    [],
    msg="a letter has no place",
  )
  assert_eq(field.values().length(), 10)
}

///|
test "a masked input is filled from a whole value" {
  let field = @widget.MaskedInput::new("####-####")
  field.set("1234-5678")
  assert_eq(field.text(), "1234-5678")
  assert_eq(field.is_complete(), true)
  field.clear()
  assert_eq(field.text(), "____-____")
  assert_eq(field.is_complete(), false)
}

///|
test "a masked input moves over its places and empties one" {
  let field = @widget.MaskedInput::new("##:##")
  let w : &@widget.Widget = field
  field.set("12:34")
  assert_eq(field.cursor(), 3)
  ignore(press(w, 1, size(8, 1), key(Left)))
  assert_eq(field.cursor(), 2)
  ignore(press(w, 1, size(8, 1), key(Backspace)))
  assert_eq(field.text(), "12:_4")
  ignore(press(w, 1, size(8, 1), key(Backspace)))
  assert_eq(field.text(), "1_:_4")
  ignore(press(w, 1, size(8, 1), key(Home)))
  assert_eq(field.cursor(), 0)
  ignore(press(w, 1, size(8, 1), key(End)))
  assert_eq(field.cursor(), 3)
  assert_eq(press(w, 1, size(8, 1), key(Delete)) |> ignore, ())
}

///|
test "a masked input submits what it holds and takes a click" {
  let field = @widget.MaskedInput::new("##", placeholder="-")
  let w : &@widget.Widget = field
  let out = press(w, 2, size(6, 1), key(Enter))
  assert_eq(out, [
    @widget.Changed(id=2, value="--"),
    @widget.Submitted(id=2, value="--"),
  ])
  let click = press(
    w,
    2,
    size(6, 1),
    Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
  )
  assert_eq(click, [@widget.TakeFocus(id=2), @widget.Repaint(id=2)])
  assert_eq(field.cursor(), 1)
  assert_eq(w.hint(size(20, 2)), size(2, 1))
  assert_eq(w.focusable(), true)
}

///|
test "a link is taken by Enter and by a click, and remembers it" {
  let link = @widget.Link::new("docs", target="https://moonbitlang.com")
  let w : &@widget.Widget = link
  assert_eq(rows(w, size(10, 1)), ["docs      "])
  assert_eq(link.target(), "https://moonbitlang.com")
  assert_eq(link.is_visited(), false)
  assert_eq(w.render_line(0, size(10, 1)).segs[0].style.attrs.underline, true)
  let out = press(w, 4, size(10, 1), key(Enter))
  assert_eq(out, [
    @widget.Pressed(id=4),
    @widget.Selected(id=4, index=0),
    @widget.Repaint(id=4),
  ])
  assert_eq(link.is_visited(), true)
  assert_eq(w.render_line(0, size(10, 1)).segs[0].style.attrs.dim, true)
}

///|
test "a link takes a click, keeps focus and falls back to its own words" {
  let link = @widget.Link::new("home")
  let w : &@widget.Widget = link
  assert_eq(link.target(), "home")
  assert_eq(w.hint(size(20, 2)), size(4, 1))
  assert_eq(w.focusable(), true)
  assert_eq(
    press(
      w,
      4,
      size(10, 1),
      Mouse({ kind: Down, button: 0, x: 1, y: 0, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=4),
      @widget.Pressed(id=4),
      @widget.Selected(id=4, index=0),
      @widget.Repaint(id=4),
    ],
  )
  assert_eq(press(w, 4, size(10, 1), Focus(true)), [@widget.Repaint(id=4)])
  assert_eq(w.render_line(0, size(10, 1)).segs[0].style.attrs.reverse, true)
  link.set("away")
  link.set_target("elsewhere")
  assert_eq(link.text(), "away")
  assert_eq(link.target(), "elsewhere")
  link.visit(visited=false)
  assert_eq(link.is_visited(), false)
}

///|
test "a mask with no places in it takes nothing" {
  let field = @widget.MaskedInput::new("abc")
  let w : &@widget.Widget = field
  assert_eq(field.text(), "abc")
  assert_eq(field.is_complete(), false)
  assert_eq(press(w, 1, size(6, 1), key(Char(49))), [])
  assert_eq(press(w, 1, size(6, 1), key(Left)), [])
  assert_eq(press(w, 1, size(6, 1), key(Backspace)), [])
  assert_eq(press(w, 1, size(6, 1), key(Delete)), [])
  assert_eq(field.cursor(), -1)
  assert_eq(w.hint(size(20, 1)), size(3, 1))
}

///|
test "each kind of place takes only what it says" {
  assert_eq(@widget.Slot::of("#"), Some(@widget.Digit))
  assert_eq(@widget.Slot::of("A"), Some(@widget.Letter))
  assert_eq(@widget.Slot::of("?"), Some(@widget.Either))
  assert_eq(@widget.Slot::of("*"), Some(@widget.Any))
  assert_eq(@widget.Slot::of("-"), None)
  assert_eq(@widget.Slot::of(""), None)
  assert_eq(@widget.Digit.takes("7"), true)
  assert_eq(@widget.Digit.takes("a"), false)
  assert_eq(@widget.Letter.takes("a"), true)
  assert_eq(@widget.Letter.takes("7"), false)
  assert_eq(@widget.Either.takes("7"), true)
  assert_eq(@widget.Either.takes("a"), true)
  assert_eq(@widget.Either.takes("-"), false)
  assert_eq(@widget.Any.takes("-"), true)
  assert_eq(@widget.Any.takes(""), false)
  assert_eq(
    @widget.Digit.glyph() +
    @widget.Letter.glyph() +
    @widget.Either.glyph() +
    @widget.Any.glyph(),
    "#A?*",
  )
}

///|
test "a character a place will not take goes to the next that will" {
  let field = @widget.MaskedInput::new("A###")
  let w : &@widget.Widget = field
  let out = press(w, 1, size(8, 1), key(Char(122)))
  assert_eq(out, [@widget.Changed(id=1, value="z___"), @widget.Repaint(id=1)])
  ignore(press(w, 1, size(8, 1), key(Char(53))))
  assert_eq(field.text(), "z5__")
  assert_eq(field.is_complete(), false)
  ignore(press(w, 1, size(8, 1), key(Char(49))))
  ignore(press(w, 1, size(8, 1), key(Char(50))))
  assert_eq(field.text(), "z512")
  assert_eq(field.is_complete(), true)
  assert_eq(field.cursor(), 3)
  assert_eq(press(w, 1, size(8, 1), key(Char(51))), [
    @widget.Changed(id=1, value="z513"),
    @widget.Repaint(id=1),
  ])
}

///|
test "a value is read into the places with the literals left out" {
  let field = @widget.MaskedInput::new("(###) ###")
  field.set("555123")
  assert_eq(field.text(), "(555) 123")
  assert_eq(field.is_complete(), true)
  field.set("nope")
  assert_eq(
    field.text(),
    "(555) 123",
    msg="a value with no digits changes nothing",
  )
  field.set("12ab34cd56")
  assert_eq(field.text(), "(123) 456")
  field.clear()
  assert_eq(field.values(), ["", "", "", "", "", ""])
}

///|
test "a click past the end of a mask moves nothing" {
  let field = @widget.MaskedInput::new("##")
  let w : &@widget.Widget = field
  assert_eq(
    press(
      w,
      1,
      size(10, 1),
      Mouse({ kind: Down, button: 0, x: 8, y: 0, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  assert_eq(field.cursor(), 0)
}

///|
test "an empty list and an empty record print as they read" {
  let pretty = @widget.Pretty::new(value=VArr([]))
  let w : &@widget.Widget = pretty
  assert_eq(rows(w, size(10, 1))[0].trim_end(), "[]")
  pretty.set(VObj([]))
  assert_eq(rows(w, size(10, 1))[0].trim_end(), "{}")
  pretty.set(VBool(true))
  assert_eq(rows(w, size(10, 1))[0].trim_end(), "true")
  pretty.set(VNum(1.5))
  assert_eq(rows(w, size(10, 1))[0].trim_end(), "1.5")
}

///|
test "every kind of value prints in its own colour" {
  let pretty = @widget.Pretty::new(
    value=VArr([VNil, VBool(false), VInt(2), VNum(3.0), VStr("s")]),
  )
  let line = pretty.render_line(0, size(40, 1))
  assert_eq(line.text().trim_end(), "[nil, false, 2, 3, \"s\"]")
  // brackets and separators are punctuation (dim)
  assert_eq(
    line.segs
    .iter()
    .any(fn(s) {
      s.style == @style.Style::new(dim=true) && s.text.contains("[")
    }),
    true,
  )
  // integers are the number colour
  assert_eq(
    line.segs
    .iter()
    .any(fn(s) {
      s.style == @style.Style::new(fg=@style.yellow) && s.text.contains("2")
    }),
    true,
  )
  // strings are the text colour
  assert_eq(
    line.segs
    .iter()
    .any(fn(s) {
      s.style == @style.Style::new(fg=@style.green) && s.text.contains("\"s\"")
    }),
    true,
  )
}

///|
test "a pretty takes page keys, a click and a focus" {
  let items : Array[@widget.Value] = []
  for i in 0..<20 {
    items.push(VStr("word" + i.to_string()))
  }
  let pretty = @widget.Pretty::new(value=VArr(items))
  let w : &@widget.Widget = pretty
  assert_eq(press(w, 1, size(30, 4), key(PageDown)), [@widget.Repaint(id=1)])
  assert_eq(pretty.offset(), 3)
  assert_eq(press(w, 1, size(30, 4), key(PageUp)), [@widget.Repaint(id=1)])
  assert_eq(pretty.offset(), 0)
  assert_eq(
    press(
      w,
      1,
      size(30, 4),
      Mouse({ kind: Down, button: 0, x: 1, y: 1, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=1)],
  )
  assert_eq(press(w, 1, size(30, 4), Focus(true)), [@widget.Repaint(id=1)])
  assert_eq(
    press(
      w,
      1,
      size(30, 4),
      Mouse({ kind: ScrollUp, button: 0, x: 1, y: 1, mods: @event.none, }),
    ),
    [],
  )
}

///|
test "a pretty clips a value too wide for its box" {
  let pretty = @widget.Pretty::new(value=VStr("a very long string indeed"))
  let w : &@widget.Widget = pretty
  assert_eq(pretty.render_line(0, size(10, 1)).text(), "\"a very lo")
  assert_eq(w.hint(size(10, 4)), size(10, 1))
}
