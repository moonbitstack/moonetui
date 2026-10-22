// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "attribute sets union and report drops" {
  let bold = @style.Style::new(bold=true).attrs
  let italic = @style.Style::new(italic=true).attrs
  let both = bold.union(italic)
  assert_eq(both.bold && both.italic, true)
  assert_eq(both.drops_from(bold), true)
  assert_eq(bold.drops_from(both), false)
  assert_eq(@style.plain.is_plain(), true)
}

///|
test "merge layers one style over another" {
  let base = @style.Style::new(fg=@style.white, bg=@style.blue)
  let over = @style.Style::new(fg=@style.yellow, bold=true)
  let merged = base.merge(over)
  assert_eq(merged.fg, @style.yellow)
  assert_eq(merged.bg, @style.blue)
  assert_eq(merged.attrs.bold, true)
  assert_eq(@style.default.is_default(), true)
  assert_eq(base.swap().fg, @style.blue)
}

///|
test "a style quantises both of its colours" {
  let s = @style.Style::new(
    fg=@style.Colour::rgb(255, 0, 0),
    bg=@style.Colour::rgb(0, 0, 255),
  )
  assert_eq(s.to_ansi256().fg, Ansi256(196))
  assert_eq(s.to_ansi16().bg, @style.bright_blue)
}
