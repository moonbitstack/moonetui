// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "rule draws a line in every style" {
  let w : &@widget.Widget = @widget.Rule::horizontal()
  assert_eq(rows(w, size(5, 2)), ["─────", "     "])
  assert_eq(w.hint(size(10, 10)), size(10, 1))
  let heavy : &@widget.Widget = @widget.Rule::horizontal(
    kind=@widget.RuleKind::Heavy,
  )
  assert_eq(rows(heavy, size(3, 1)), ["━━━"])
  let dashed : &@widget.Widget = @widget.Rule::horizontal(
    kind=@widget.RuleKind::Dashed,
  )
  assert_eq(rows(dashed, size(2, 1)), ["╍╍"])
  let ascii : &@widget.Widget = @widget.Rule::horizontal(
    kind=@widget.RuleKind::Ascii,
  )
  assert_eq(rows(ascii, size(2, 1)), ["--"])
  let hidden : &@widget.Widget = @widget.Rule::horizontal(
    kind=@widget.RuleKind::None,
  )
  assert_eq(rows(hidden, size(2, 1)), ["  "])
  let vertical : &@widget.Widget = @widget.Rule::vertical()
  assert_eq(rows(vertical, size(3, 2)), ["│  ", "│  "])
  assert_eq(vertical.hint(size(10, 10)), size(1, 10))
  let double : &@widget.Widget = @widget.Rule::vertical(
    kind=@widget.RuleKind::Double,
  )
  assert_eq(rows(double, size(2, 1)), ["║ "])
  assert_eq(vertical.focusable(), false)
}

///|
test "digits draws three rows of glyphs" {
  let digits = @widget.Digits::new(value="12:34")
  assert_eq(@widget.Digits::width_of("12:34"), 15)
  let w : &@widget.Widget = digits
  assert_eq(rows(w, size(15, 3)), [
    "╶╮ ╶─╮   ╶─╮╷ ╷", " │ ┌─┘ :  ─┤╰─┤", "╶┴╴╰─╴   ╶─╯  ╵",
  ])
  assert_eq(w.hint(size(80, 24)), size(15, 3))
  digits.update("20")
  assert_eq(rows(w, size(6, 3)), [
    "╶─╮╭─╮", "┌─┘│ │", "╰─╴╰─╯",
  ])
}

///|
test "digits goes bold and passes strangers through" {
  let bold = @widget.Digits::new(value="0", style=@style.Style::new(bold=true))
  let w : &@widget.Widget = bold
  assert_eq(rows(w, size(3, 3)), ["┏━┓", "┃ ┃", "┗━┛"])
  let mixed = @widget.Digits::new(value="1.5")
  assert_eq(@widget.Digits::width_of("1.5"), 7)
  let m : &@widget.Widget = mixed
  assert_eq(rows(m, size(7, 3)), [
    "╶╮  ╭─╴", " │  ╰─╮", "╶┴╴•╶─╯",
  ])
  assert_eq(rows(m, size(20, 3))[0], "╶╮  ╭─╴             ")
}

///|
test "sparkline bins data into bars" {
  let spark = @widget.Sparkline::new(data=[0.0, 10.0])
  let w : &@widget.Widget = spark
  assert_eq(rows(w, size(4, 1)), ["▁▁██"])
  spark.set([0.0, 5.0, 10.0])
  assert_eq(rows(w, size(3, 1)), ["▁▄█"])
  let median = @widget.Sparkline::new(
    data=[1.0, 2.0, 3.0, 4.0],
    summary=@widget.Summary::Median,
  )
  let m : &@widget.Widget = median
  assert_eq(rows(m, size(2, 1)), ["▂▆"])
}

///|
test "sparkline handles empty and single data" {
  let spark = @widget.Sparkline::new()
  let w : &@widget.Widget = spark
  assert_eq(rows(w, size(3, 2)), ["   ", "▁▁▁"])
  spark.set([42.0])
  assert_eq(rows(w, size(3, 2)), ["███", "███"])
}

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
