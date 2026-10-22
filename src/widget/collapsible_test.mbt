// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "collapsible toggles by key and click" {
  let box = @widget.Collapsible::new(
    title="Details",
    contents=@widget.Static::new("body text"),
  )
  let w : &@widget.Widget = box
  assert_eq(rows(w, size(12, 3)), [
    "────────────", " ▶ Details  ", "            ",
  ])
  assert_eq(w.hint(size(12, 24)), size(12, 3))
  let out = press(w, 9, size(12, 8), key(Enter))
  assert_eq(out, [@widget.Toggled(id=9, on=true), @widget.Repaint(id=9)])
  assert_eq(rows(w, size(12, 5)), [
    "────────────", " ▼ Details  ", "            ", "   body text",
    "            ",
  ])
  assert_eq(w.hint(size(12, 24)), size(12, 5))
  assert_eq(
    press(
      w,
      9,
      size(12, 8),
      Mouse({ kind: Down, button: 0, x: 2, y: 1, mods: @event.none, }),
    ),
    [
      @widget.TakeFocus(id=9),
      @widget.Toggled(id=9, on=false),
      @widget.Repaint(id=9),
    ],
  )
  assert_eq(box.is_collapsed(), true)
}

///|
test "collapsible forwards keys and clicks to its contents when expanded" {
  let box = @widget.Collapsible::new(
    title="T",
    contents=@widget.Button::new("Go"),
    collapsed=false,
  )
  let w : &@widget.Widget = box
  assert_eq(press(w, 6, size(10, 8), key(Char(32))), [@widget.Pressed(id=6)])
  assert_eq(
    press(
      w,
      6,
      size(10, 8),
      Mouse({ kind: Down, button: 0, x: 4, y: 3, mods: @event.none, }),
    ),
    [@widget.TakeFocus(id=6), @widget.Pressed(id=6)],
  )
  box.set_collapsed(true)
  assert_eq(press(w, 6, size(10, 8), key(Char(32))), [])
}

///|
test "an expanded collapsible lends its focus to its contents" {
  let list = @widget.ListView::new(["a", "b"])
  let fold = @widget.Collapsible::new(title="t", contents=list, collapsed=false)
  let w : &@widget.Widget = fold
  let blurred = w.render_line(3, size(10, 6))
  ignore(press(w, 1, size(10, 6), Focus(true)))
  let focused = w.render_line(3, size(10, 6))
  assert_eq(focused.text(), blurred.text())
  assert_eq(focused != blurred, true)
}
