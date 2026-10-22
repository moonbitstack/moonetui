// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "tabs render labels and highlight the active underline" {
  let tabs = @widget.Tabs::new(labels=["one", "two"])
  let w : &@widget.Widget = tabs
  assert_eq(rows(w, size(12, 2)), [
    " one  two   ", "━━━━━━━━━━━━",
  ])
  assert_eq(w.hint(size(12, 24)), size(12, 2))
  let bar = tabs.render_line(1, size(12, 1))
  assert_eq(bar.segs.length(), 2)
  assert_eq(bar.segs[0].text, "━━━━━")
  assert_eq(bar.segs[0].style, @style.Style::new(reverse=true))
  assert_eq(bar.segs[1].text, "━━━━━━━")
  ignore(press(w, 1, size(12, 2), key(Right)))
  let moved = tabs.render_line(1, size(12, 1))
  assert_eq(moved.segs.length(), 3)
  assert_eq(moved.segs[1].text, "━━━━━")
  assert_eq(moved.segs[1].style, @style.Style::new(reverse=true))
}

///|
test "tabs move with wraparound and skip disabled tabs" {
  let tabs = @widget.Tabs::new(labels=["a", "b", "c"], active=2)
  tabs.set_disabled(1, true)
  let w : &@widget.Widget = tabs
  let out = press(w, 7, size(20, 2), key(Right))
  assert_eq(tabs.active(), 0)
  assert_eq(out, [@widget.Selected(id=7, index=0), @widget.Repaint(id=7)])
  ignore(press(w, 7, size(20, 2), key(Left)))
  assert_eq(tabs.active(), 2)
  tabs.set_disabled(2, true)
  assert_eq(tabs.active(), 0)
}

///|
test "tabs activate by click and hover by pointer move" {
  let tabs = @widget.Tabs::new(labels=["one", "two"])
  let w : &@widget.Widget = tabs
  let out = press(
    w,
    4,
    size(12, 2),
    Mouse({ kind: Down, button: 0, x: 6, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=4),
    @widget.Selected(id=4, index=1),
    @widget.Repaint(id=4),
  ])
  assert_eq(tabs.active(), 1)
  assert_eq(
    press(
      w,
      4,
      size(12, 2),
      Mouse({ kind: Move, button: 0, x: 1, y: 0, mods: @event.none, }),
    ),
    [],
  )
}
