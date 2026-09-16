// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let plain : @style.Style = @style.default

///|
fn size(width : Int, height : Int) -> @geom.Size {
  @geom.Size::new(width, height)
}

///|
/// Render a widget's rows as text, which is what a test can read.
fn rows(w : &@widget.Widget, at : @geom.Size) -> Array[String] {
  let out : Array[String] = []
  for y in 0..<at.height {
    out.push(w.render_line(y, at).text())
  }
  out
}

///|
fn key(code : @event.KeyCode) -> @widget.Msg {
  Key(@event.Key::of(code))
}

///|
fn press(
  w : &@widget.Widget,
  id : Int,
  at : @geom.Size,
  msg : @widget.Msg,
) -> Array[@widget.Out] {
  let ctx = @widget.Ctx::new(id, at)
  w.handle(ctx, msg) |> ignore
  ctx.asked()
}

///|
test "static text renders one line per line of text" {
  let s : &@widget.Widget = @widget.Static::new("one\ntwo")
  assert_eq(rows(s, size(5, 3)), ["one  ", "two  ", "     "])
  assert_eq(s.hint(size(80, 24)), size(3, 2))
  assert_eq(s.focusable(), false)
}

///|
test "alignment puts the slack where it was asked for" {
  let left : &@widget.Widget = @widget.Static::new("ab")
  let middle : &@widget.Widget = @widget.Static::new("ab", align=Center)
  let right : &@widget.Widget = @widget.Static::new("ab", align=Right)
  assert_eq(left.render_line(0, size(6, 1)).text(), "ab    ")
  assert_eq(middle.render_line(0, size(6, 1)).text(), "  ab  ")
  assert_eq(right.render_line(0, size(6, 1)).text(), "    ab")
}

///|
test "text wider than the widget is cut at a character boundary" {
  let s : &@widget.Widget = @widget.Static::new("中文字")
  // Five columns hold two wide characters and leave one column over.
  assert_eq(s.render_line(0, size(5, 1)).text(), "中文 ")
}

///|
test "a frame draws its own edges and wraps the row it is given" {
  let inner = @strip.Strip::of("ab", plain)
  let at = size(6, 3)
  assert_eq(
    @widget.frame(@widget.thin, 0, at, plain, inner).text(),
    "┌────┐",
  )
  assert_eq(
    @widget.frame(@widget.thin, 1, at, plain, inner).text(),
    "│ab  │",
  )
  assert_eq(
    @widget.frame(@widget.thin, 2, at, plain, inner).text(),
    "└────┘",
  )
}

///|
test "a button centres its label and asks for room around it" {
  let b = @widget.Button::new("Save")
  let w : &@widget.Widget = b
  assert_eq(w.hint(size(80, 24)), size(8, 1))
  assert_eq(w.render_line(0, size(8, 1)).text(), "  Save  ")
  assert_eq(w.focusable(), true)
}

///|
test "enter and space press a button, other keys do not" {
  let b = @widget.Button::new("Go")
  let w : &@widget.Widget = b
  assert_eq(press(w, 7, size(6, 1), key(Enter)), [Pressed(id=7)])
  assert_eq(press(w, 7, size(6, 1), @widget.Msg::Key(@event.Key::char(32))), [
    Pressed(id=7),
  ])
  assert_eq(press(w, 7, size(6, 1), key(Down)), [])
}

///|
test "clicking a button takes focus and presses it" {
  let b = @widget.Button::new("Go")
  let w : &@widget.Widget = b
  let clicked = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 1,
    y: 0,
    mods: @event.none,
  })
  assert_eq(press(w, 3, size(6, 1), clicked), [TakeFocus(id=3), Pressed(id=3)])
}

///|
test "a disabled button neither takes focus nor presses" {
  let b = @widget.Button::new("Go")
  b.disable(true)
  let w : &@widget.Widget = b
  assert_eq(w.focusable(), false)
  assert_eq(press(w, 1, size(6, 1), key(Enter)), [])
  assert_eq(b.is_disabled(), true)
}

///|
test "focus reaches a widget as a message it can act on" {
  let b = @widget.Button::new("Go")
  let w : &@widget.Widget = b
  assert_eq(press(w, 2, size(6, 1), @widget.Msg::Focus(true)), [Repaint(id=2)])
  assert_eq(b.has_focus(), true)
}

///|
test "typing into an input edits it and reports the new value" {
  let input = @widget.Input::new()
  let w : &@widget.Widget = input
  let at = size(10, 1)
  assert_eq(press(w, 5, at, @widget.Msg::Key(@event.Key::char(104))), [
    Changed(id=5, value="h"),
    Repaint(id=5),
  ])
  w.handle(@widget.Ctx::new(5, at), @widget.Msg::Key(@event.Key::char(105)))
  |> ignore
  assert_eq(input.text(), "hi")
  assert_eq(input.cursor(), 2)
}

///|
test "backspace and delete take whole characters, surrogate pairs included" {
  let input = @widget.Input::new()
  input.set("a😀b")
  let w : &@widget.Widget = input
  let at = size(10, 1)
  // The cursor is at the end; one backspace removes the b, the next removes
  // both code units of the emoji.
  w.handle(@widget.Ctx::new(1, at), key(Backspace)) |> ignore
  assert_eq(input.text(), "a😀")
  w.handle(@widget.Ctx::new(1, at), key(Backspace)) |> ignore
  assert_eq(input.text(), "a")
  input.set("xy")
  w.handle(@widget.Ctx::new(1, at), key(Home)) |> ignore
  w.handle(@widget.Ctx::new(1, at), key(Delete)) |> ignore
  assert_eq(input.text(), "y")
}

///|
test "the arrows move the cursor and home and end jump" {
  let input = @widget.Input::new()
  input.set("abc")
  let w : &@widget.Widget = input
  let at = size(10, 1)
  w.handle(@widget.Ctx::new(1, at), key(Left)) |> ignore
  assert_eq(input.cursor(), 2)
  w.handle(@widget.Ctx::new(1, at), key(Home)) |> ignore
  assert_eq(input.cursor(), 0)
  w.handle(@widget.Ctx::new(1, at), key(Right)) |> ignore
  assert_eq(input.cursor(), 1)
  w.handle(@widget.Ctx::new(1, at), key(End)) |> ignore
  assert_eq(input.cursor(), 3)
}

///|
test "a paste lands in the input in one piece" {
  let input = @widget.Input::new()
  let w : &@widget.Widget = input
  let asked = press(w, 9, size(10, 1), @widget.Msg::Paste("hello"))
  assert_eq(input.text(), "hello")
  assert_eq(asked[0], Changed(id=9, value="hello"))
}

///|
test "an empty unfocused input shows its placeholder" {
  let input = @widget.Input::new(placeholder="name")
  let w : &@widget.Widget = input
  assert_eq(w.render_line(0, size(8, 1)).text(), "name    ")
  w.handle(@widget.Ctx::new(1, size(8, 1)), @widget.Msg::Focus(true)) |> ignore
  // Focused, the placeholder gives way to the cursor.
  assert_eq(w.render_line(0, size(8, 1)).text(), "        ")
}

///|
test "a long input scrolls to keep the cursor visible" {
  let input = @widget.Input::new()
  input.set("abcdefghij")
  let w : &@widget.Widget = input
  // Five columns cannot show ten characters, and the cursor sits past the last
  // one, so the view ends with a column for it to occupy.
  assert_eq(w.render_line(0, size(5, 1)).text(), "ghij ")
  assert_eq(input.cursor_column(5), 4)
}

///|
test "a list moves its highlight and reports what was chosen" {
  let list = @widget.ListView::new(["one", "two", "three"])
  let w : &@widget.Widget = list
  let at = size(8, 3)
  assert_eq(rows(w, at), ["one     ", "two     ", "three   "])
  w.handle(@widget.Ctx::new(4, at), key(Down)) |> ignore
  assert_eq(list.index(), 1)
  assert_eq(press(w, 4, at, key(Enter)), [Selected(id=4, index=1)])
  w.handle(@widget.Ctx::new(4, at), key(End)) |> ignore
  assert_eq(list.index(), 2)
  w.handle(@widget.Ctx::new(4, at), key(Home)) |> ignore
  assert_eq(list.index(), 0)
}

///|
test "a list scrolls so the highlight stays on screen" {
  let list = @widget.ListView::new(["a", "b", "c", "d", "e"])
  let w : &@widget.Widget = list
  let at = size(4, 2)
  list.select(4)
  assert_eq(rows(w, at), ["d   ", "e   "])
  assert_eq(list.offset(), 3)
}

///|
test "an empty list has no selection and ignores the keys" {
  let list = @widget.ListView::new([])
  let w : &@widget.Widget = list
  assert_eq(list.index(), -1)
  assert_eq(press(w, 1, size(4, 2), key(Enter)), [])
  assert_eq(rows(w, size(4, 2)), ["    ", "    "])
}

///|
test "clicking a row takes focus and highlights it" {
  let list = @widget.ListView::new(["a", "b", "c"])
  let w : &@widget.Widget = list
  let clicked = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 0,
    y: 2,
    mods: @event.none,
  })
  let asked = press(w, 6, size(4, 3), clicked)
  assert_eq(asked[0], TakeFocus(id=6))
  assert_eq(list.index(), 2)
}

///|
test "a progress bar fills in eighths and prints its percentage" {
  let bar = @widget.Progress::new(total=8)
  let w : &@widget.Widget = bar
  bar.set(4)
  assert_eq(bar.percent(), 50)
  // Eight columns less the four the label takes leaves four for the bar.
  assert_eq(w.render_line(0, size(8, 1)).text(), "██   50%")
  bar.advance(4)
  assert_eq(bar.percent(), 100)
  assert_eq(w.render_line(0, size(9, 1)).text(), "████ 100%")
}

///|
test "a bar clamps rather than overflowing" {
  let bar = @widget.Progress::new(total=10)
  bar.set(99)
  assert_eq(bar.percent(), 100)
  bar.set(-5)
  assert_eq(bar.percent(), 0)
  bar.set_total(0)
  assert_eq(bar.percent(), 0)
}

///|
test "the header centres its title and keeps the note on the right" {
  let head = @widget.Header::new("moonetui", note="v0")
  let w : &@widget.Widget = head
  // The title is centred in what the note leaves it, not in the whole width.
  assert_eq(w.render_line(0, size(14, 1)).text(), "  moonetui  v0")
  head.set("short")
  head.set_note("")
  assert_eq(w.render_line(0, size(11, 1)).text(), "   short   ")
}

///|
test "the footer lists what it can fit and drops the rest" {
  let foot = @widget.Footer::new([("q", "quit"), ("?", "help")])
  let w : &@widget.Widget = foot
  assert_eq(w.render_line(0, size(20, 1)).text(), " q quit  ? help     ")
  // Eight columns hold the first binding only.
  assert_eq(w.render_line(0, size(8, 1)).text(), " q quit ")
}
