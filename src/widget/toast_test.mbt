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

///|
test "a toast is dismissed once, and a passing pointer leaves it be" {
  let toast = @widget.Toast::new("saved", duration=100)
  let w : &@widget.Widget = toast
  let at = size(20, 1)
  let pass = @widget.Msg::Mouse({
    kind: Move,
    button: 0,
    x: 1,
    y: 0,
    mods: @event.none,
  })
  assert_eq(press(w, 9, at, pass), [])
  assert_eq(toast.expired(), false)
  assert_eq(press(w, 9, at, Tick(150)), [Dismissed(id=9)])
  assert_eq(press(w, 9, at, Tick(16)), [])
}

///|
test "the level bar colours are the caller's to choose" {
  let toast = @widget.Toast::new(
    "careful",
    level=Warning,
    bar_warning=@style.Style::new(fg=@style.magenta),
  )
  assert_eq(toast.bar_style().fg, @style.magenta)
}
