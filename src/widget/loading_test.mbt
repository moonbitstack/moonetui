// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "loading indicator pulses on ticks" {
  let spin = @widget.LoadingIndicator::new()
  let w : &@widget.Widget = spin
  assert_eq(rows(w, size(9, 1)), ["● ● ● ● ●"])
  let out = press(w, 4, size(9, 1), @widget.Msg::Tick(1))
  assert_eq(out, [@widget.Repaint(id=4)])
  assert_eq(spin.frame(), 1)
  assert_eq(rows(w, size(11, 1)), [" ● ● ● ● ● "])
  assert_eq(spin.handle(@widget.Ctx::new(4, size(9, 1)), key(Char(97))), true)
}
