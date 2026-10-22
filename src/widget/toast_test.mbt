// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "toast renders a bar a title and a message" {
  let toast : &@widget.Widget = @widget.Toast::new(
    "saved to disk",
    title="Done",
    level=Warning,
  )
  assert_eq(rows(toast, size(18, 2)), [
    "▌ Done            ", "▌ saved to disk   ",
  ])
  assert_eq(toast.hint(size(80, 24)), size(17, 2))
  assert_eq(toast.focusable(), false)
}

///|
test "toast expires after its duration and retires on a click" {
  let toast : &@widget.Widget = @widget.Toast::new("gone soon", duration=100)
  let at = size(14, 2)
  assert_eq(press(toast, 5, at, Tick(50)), [])
  assert_eq(press(toast, 5, at, Tick(60)), [@widget.Dismissed(id=5)])
  let steady : &@widget.Widget = @widget.Toast::new("stays", duration=0)
  assert_eq(press(steady, 6, at, Tick(5000)), [])
  assert_eq(
    press(
      steady,
      6,
      at,
      Mouse({ kind: Down, button: 0, x: 2, y: 0, mods: @event.none, }),
    ),
    [@widget.Dismissed(id=6)],
  )
}
