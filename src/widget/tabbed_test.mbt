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
