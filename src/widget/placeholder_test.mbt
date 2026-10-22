// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "placeholder centres its variants and cycles on click" {
  let ph = @widget.Placeholder::new()
  let w : &@widget.Widget = ph
  assert_eq(rows(w, size(11, 3)), ["           ", "Placeholder", "           "])
  let out = press(
    w,
    1,
    size(11, 3),
    Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
  )
  assert_eq(out, [@widget.Repaint(id=1)])
  assert_eq(ph.variant(), @widget.PlaceholderVariant::Size)
  assert_eq(rows(w, size(11, 3))[1], "  11 x 3   ")
  ignore(
    press(
      w,
      1,
      size(11, 3),
      Mouse({ kind: Down, button: 0, x: 0, y: 0, mods: @event.none, }),
    ),
  )
  assert_eq(ph.variant(), @widget.PlaceholderVariant::Text)
  assert_eq(w.hint(size(20, 6)), size(20, 6))
  let tinted = @widget.Placeholder::new(colour=1)
  assert_eq(tinted.style.bg, @style.Colour::rgb(0xAA, 0x33, 0x55))
}
