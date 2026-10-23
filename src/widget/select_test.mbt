// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "select shows the current choice and expands in flow" {
  let select = @widget.Select::new(
    options=[("Apple", "apple"), ("Banana", "banana"), ("Cherry", "cherry")],
    value="banana",
  )
  let w : &@widget.Widget = select
  let at = size(12, 6)
  assert_eq(rows(w, size(12, 1)), [" Banana    ▼"])
  assert_eq(w.hint(at), size(12, 1))
  let out = press(w, 1, at, key(Enter))
  assert_eq(out, [@widget.Repaint(id=1)])
  assert_eq(select.expanded(), true)
  assert_eq(w.hint(at), size(12, 4))
  assert_eq(rows(w, size(12, 4)), [
    " Banana    ▲", " Apple      ", " Banana     ", " Cherry     ",
  ])
}

///|
test "select chooses, escapes and searches" {
  let select = @widget.Select::new(options=[
    ("Apple", "apple"),
    ("Banana", "banana"),
    ("Cherry", "cherry"),
  ])
  let w : &@widget.Widget = select
  let at = size(12, 6)
  ignore(press(w, 1, at, key(Char(32))))
  assert_eq(select.expanded(), true)
  ignore(press(w, 1, at, key(Char(98))))
  ignore(press(w, 1, at, key(Char(97))))
  let out = press(w, 1, at, key(Enter))
  assert_eq(out, [
    @widget.Selected(id=1, index=1),
    @widget.Changed(id=1, value="banana"),
    @widget.Repaint(id=1),
  ])
  assert_eq(select.value(), Some("banana"))
  assert_eq(select.expanded(), false)
  assert_eq(rows(w, size(12, 1)), [" Banana    ▼"])
  ignore(press(w, 1, at, key(Down)))
  assert_eq(select.expanded(), true)
  assert_eq(press(w, 1, at, key(Escape)), [@widget.Repaint(id=1)])
  assert_eq(select.expanded(), false)
}

///|
test "select picks from clicks and blanks when allowed" {
  let select = @widget.Select::new(options=[("One", "one"), ("Two", "two")])
  let w : &@widget.Widget = select
  let at = size(8, 4)
  assert_eq(rows(w, size(8, 1)), [" Select▼"])
  let out = press(
    w,
    1,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [@widget.TakeFocus(id=1), @widget.Repaint(id=1)])
  let out = press(
    w,
    1,
    at,
    Mouse({ kind: Down, button: 0, x: 0, y: 2, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=1),
    @widget.Selected(id=1, index=1),
    @widget.Changed(id=1, value="two"),
    @widget.Repaint(id=1),
  ])
  select.clear()
  assert_eq(select.is_blank(), true)
  let strict = @widget.Select::new(options=[("One", "one")], allow_blank=false)
  assert_eq(strict.value(), Some("one"))
}

///|
test "the wheel scrolls an open select past its highlight" {
  let pick = @widget.Select::new(options=[
    ("a", "a"),
    ("b", "b"),
    ("c", "c"),
    ("d", "d"),
    ("e", "e"),
  ])
  let w : &@widget.Widget = pick
  let at = size(10, 3)
  ignore(press(w, 1, at, key(Enter)))
  let wheel = @widget.Msg::Mouse({
    kind: ScrollDown,
    button: 0,
    x: 1,
    y: 1,
    mods: @event.none,
  })
  ignore(press(w, 1, at, wheel))
  ignore(press(w, 1, at, wheel))
  assert_eq(rows(w, at).map(r => r.trim().to_owned()), ["Select  ▲", "c", "d"])
  ignore(press(w, 1, at, key(Down)))
  assert_eq(rows(w, at).map(r => r.trim().to_owned()), ["Select  ▲", "b", "c"])
}

///|
fn letters(count : Int32, value? : String) -> @widget.Select {
  @widget.Select::new(
    options=Array::makei(count, i => {
      let c = (97 + i).unsafe_to_char().to_string()
      (c.to_upper(), c)
    }),
    value?,
  )
}

///|
test "an open select walks with up, home, end and the page keys" {
  let pick = letters(10, value="e")
  let w : &@widget.Widget = pick
  let at = size(8, 5)
  ignore(press(w, 1, at, key(Enter)))
  ignore(rows(w, at))
  ignore(press(w, 1, at, key(Up)))
  ignore(press(w, 1, at, key(Enter)))
  assert_eq(pick.value(), Some("d"))
  ignore(press(w, 1, at, key(Enter)))
  ignore(rows(w, at))
  // Four options show under the closed line, so a page is three.
  ignore(press(w, 1, at, key(End)))
  ignore(press(w, 1, at, key(PageUp)))
  ignore(press(w, 1, at, key(Enter)))
  assert_eq(pick.value(), Some("g"))
  ignore(press(w, 1, at, key(Enter)))
  ignore(rows(w, at))
  ignore(press(w, 1, at, key(Home)))
  ignore(press(w, 1, at, key(PageDown)))
  ignore(press(w, 1, at, key(Enter)))
  assert_eq(pick.value(), Some("d"))
}

///|
test "a closed select leaves the paging keys, modified keys and letters to others" {
  let w : &@widget.Widget = letters(3)
  let at = size(8, 4)
  let codes : Array[@event.KeyCode] = [
    Home,
    End,
    PageUp,
    PageDown,
    Escape,
    Char(97),
  ]
  for code in codes {
    assert_eq(feed(w, at, key(code)), (false, []))
  }
  let ctrl = @event.Mods::of_param(5)
  assert_eq(feed(w, at, Key(@event.Key::with_mods(Enter, ctrl))), (false, []))
  assert_eq(feed(w, at, mouse(ScrollDown, 0, 0)), (false, []))
  assert_eq(feed(w, at, mouse(Move, 0, 0)), (false, []))
  assert_eq(feed(w, at, Paste("a")), (false, []))
}

///|
test "choosing the option already chosen closes the select and reports nothing" {
  let pick = letters(3, value="b")
  let w : &@widget.Widget = pick
  let at = size(8, 4)
  ignore(press(w, 1, at, key(Enter)))
  assert_eq(press(w, 1, at, key(Enter)), [Repaint(id=1)])
  assert_eq(pick.expanded(), false)
  assert_eq(pick.value(), Some("b"))
}

///|
test "losing focus closes an open select and forgets the search" {
  let pick = letters(3)
  let w : &@widget.Widget = pick
  let at = size(8, 4)
  ignore(press(w, 1, at, key(Enter)))
  ignore(press(w, 1, at, key(Char(99))))
  ignore(press(w, 1, at, Focus(false)))
  assert_eq(pick.expanded(), false)
  // A fresh search starts from nothing: "a" finds A, not "ca".
  ignore(press(w, 1, at, key(Enter)))
  ignore(press(w, 1, at, key(Char(97))))
  ignore(press(w, 1, at, key(Enter)))
  assert_eq(pick.value(), Some("a"))
}

///|
test "a search with no match leaves the highlight where it was" {
  let pick = letters(3, value="b")
  let w : &@widget.Widget = pick
  let at = size(8, 4)
  ignore(press(w, 1, at, key(Enter)))
  ignore(press(w, 1, at, key(Char(122))))
  ignore(press(w, 1, at, key(Enter)))
  assert_eq(pick.value(), Some("b"))
}

///|
test "an open select closes on a click on its own line and ignores clicks below its options" {
  let pick = letters(2)
  let w : &@widget.Widget = pick
  let at = size(8, 6)
  ignore(press(w, 1, at, mouse(Down, 0, 0)))
  assert_eq(pick.expanded(), true)
  ignore(press(w, 1, at, mouse(Down, 0, 5)))
  assert_eq(pick.expanded(), true)
  assert_eq(pick.is_blank(), true)
  ignore(press(w, 1, at, mouse(Down, 0, 0)))
  assert_eq(pick.expanded(), false)
}

///|
test "the wheel scrolls an open select back up" {
  let pick = letters(6)
  let w : &@widget.Widget = pick
  let at = size(8, 3)
  ignore(press(w, 1, at, key(Enter)))
  ignore(press(w, 1, at, mouse(ScrollDown, 0, 1)))
  ignore(press(w, 1, at, mouse(ScrollDown, 0, 1)))
  assert_eq(rows(w, at)[1].trim(), "C")
  ignore(press(w, 1, at, mouse(ScrollUp, 0, 1)))
  assert_eq(rows(w, at)[1].trim(), "B")
}

///|
test "a select draws nothing in no room, and nothing below itself when closed" {
  let w : &@widget.Widget = letters(3)
  assert_eq(rows(w, size(0, 1)), [""])
  assert_eq(rows(w, size(8, 3))[1], "        ")
}
