// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "tabbed content renders and switches its active pane" {
  let box = @widget.TabbedContent::new(labels=["one", "two"], panes=[
    @widget.Static::new("AAA"),
    @widget.Static::new("BBB"),
  ])
  let w : &@widget.Widget = box
  assert_eq(rows(w, size(10, 4)), [
    " one  two ", "━━━━━━━━━━", "AAA       ", "          ",
  ])
  assert_eq(w.hint(size(10, 24)), size(10, 3))
  let out = press(w, 8, size(10, 4), key(Right))
  assert_eq(out, [@widget.Selected(id=8, index=1), @widget.Repaint(id=8)])
  assert_eq(box.active(), 1)
  assert_eq(w.render_line(2, size(10, 1)).text(), "BBB       ")
}

///|
fn tabbed_list() -> (@widget.TabbedContent, @widget.ListView) {
  let list = @widget.ListView::new(["a", "b", "c"])
  let box = @widget.TabbedContent::new(labels=["one", "two"], panes=[
    list,
    @widget.Static::new("BBB"),
  ])
  (box, list)
}

///|
test "a click in the pane reaches the pane, not the tabs" {
  let (box, list) = tabbed_list()
  let w : &@widget.Widget = box
  let click = @widget.Msg::Mouse({
    kind: Down,
    button: 0,
    x: 6,
    y: 3,
    mods: @event.none,
  })
  let out = press(w, 5, size(10, 5), click)
  assert_eq(box.active(), 0)
  assert_eq(list.index(), 1)
  assert_eq(out.contains(Selected(id=5, index=1)), true)
}

///|
test "keys go to the pane first and switch tabs when it passes" {
  let (box, list) = tabbed_list()
  let w : &@widget.Widget = box
  ignore(press(w, 5, size(10, 5), key(Down)))
  assert_eq(list.index(), 1)
  assert_eq(box.active(), 0)
  let out = press(w, 5, size(10, 5), key(Right))
  assert_eq(box.active(), 1)
  assert_eq(out.contains(Selected(id=5, index=1)), true)
}

///|
test "focus reaches the active pane and follows a tab switch" {
  let (box, list) = tabbed_list()
  let w : &@widget.Widget = box
  ignore(press(w, 5, size(10, 5), Focus(true)))
  let focused = w.render_line(2, size(10, 5))
  ignore(press(w, 5, size(10, 5), Focus(false)))
  let blurred = w.render_line(2, size(10, 5))
  assert_eq(focused.segs[0].style != blurred.segs[0].style, true)
  ignore(list)
}

///|
test "tabbed content switches by call and by a click on the tab bar" {
  let box = @widget.TabbedContent::new(labels=["one", "two", "three"], panes=[
    @widget.Static::new("AAA"),
    @widget.Static::new("BBB"),
  ])
  let w : &@widget.Widget = box
  let at = size(16, 4)
  box.activate(1)
  assert_eq(box.active(), 1)
  assert_eq(rows(w, at)[2].trim(), "BBB")
  box.set_disabled(0, true)
  ignore(press(w, 1, at, mouse(Down, 1, 0)))
  assert_eq(box.active(), 1)
  box.activate(2)
  assert_eq(rows(w, at)[2], "                ")
  assert_eq(w.hint(at), size(16, 2))
  assert_eq(feed(w, at, Key(@event.Key::of(Down))).0, false)
}

///|
test "a focused tabbed content hands focus to the pane a click switches to" {
  let first = @widget.Checkbox::new("a")
  let second = @widget.Checkbox::new("b")
  let box = @widget.TabbedContent::new(labels=["one", "two"], panes=[
    first, second,
  ])
  let w : &@widget.Widget = box
  let at = size(12, 4)
  ignore(press(w, 1, at, Focus(true)))
  let focused_a = rows(w, at)[2]
  ignore(press(w, 1, at, mouse(Down, 7, 0)))
  assert_eq(box.active(), 1)
  let b_line : &@widget.Widget = second
  assert_eq(rows(w, at)[2], b_line.render_line(0, size(12, 1)).text())
  ignore(press(w, 1, at, mouse(Down, 1, 0)))
  assert_eq(rows(w, at)[2], focused_a)
}
