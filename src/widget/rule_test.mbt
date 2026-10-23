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
test "every rule kind draws its own character, both ways" {
  let kinds : Array[(@widget.RuleKind, String, String)] = [
    (Ascii, "-", "|"),
    (Blank, " ", " "),
    (Dashed, "╍", "╏"),
    (Double, "═", "║"),
    (Heavy, "━", "┃"),
    (Hidden, " ", " "),
    (None, " ", " "),
    (Solid, "─", "│"),
    (Thick, "█", "█"),
  ]
  for k in kinds {
    let across : &@widget.Widget = @widget.Rule::horizontal(kind=k.0)
    assert_eq(rows(across, size(3, 1)), [k.1 + k.1 + k.1])
    let down : &@widget.Widget = @widget.Rule::vertical(kind=k.0)
    assert_eq(rows(down, size(1, 2)), [k.2, k.2])
  }
}

///|
test "a rule changes kind, takes no input, and draws nothing in no room" {
  let rule = @widget.Rule::horizontal()
  rule.set_kind(Double)
  let w : &@widget.Widget = rule
  assert_eq(rows(w, size(2, 1)), ["══"])
  assert_eq(rows(w, size(0, 1)), [""])
  assert_eq(feed(w, size(2, 1), key(Enter)), (false, []))
}
