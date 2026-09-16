// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let esc : String = "\u{1b}["

///|
test "render starts from a reset and names every part" {
  assert_eq(@style.render(@style.default), esc + "0;39;49m")
  assert_eq(
    @style.render(@style.Style::new(fg=@style.red, bold=true)),
    esc + "0;1;31;49m",
  )
  assert_eq(
    @style.render(@style.Style::new(bg=@style.bright_red)),
    esc + "0;39;101m",
  )
}

///|
test "the sixteen named colours use the bright range above seven" {
  assert_eq(
    @style.render(@style.Style::new(fg=@style.bright_black)),
    esc + "0;90;49m",
  )
  assert_eq(@style.render(@style.Style::new(fg=@style.white)), esc + "0;37;49m")
}

///|
test "indexed and true colour render as extended parameters" {
  assert_eq(
    @style.render(@style.Style::new(fg=Ansi256(214))),
    esc + "0;38;5;214;49m",
  )
  assert_eq(
    @style.render(@style.Style::new(bg=@style.Color::rgb(10, 20, 30))),
    esc + "0;39;48;2;10;20;30m",
  )
}

///|
test "delta emits nothing when the style has not changed" {
  let s = @style.Style::new(fg=@style.green, underline=true)
  assert_eq(@style.delta(s, s), "")
}

///|
test "delta only names what changed" {
  let plain = @style.default
  let bold = @style.Style::new(bold=true)
  assert_eq(@style.delta(plain, bold), esc + "1m")
  let red_bold = @style.Style::new(fg=@style.red, bold=true)
  assert_eq(@style.delta(bold, red_bold), esc + "31m")
  let red_bold_on_blue = @style.Style::new(
    fg=@style.red,
    bg=@style.blue,
    bold=true,
  )
  assert_eq(@style.delta(red_bold, red_bold_on_blue), esc + "44m")
}

///|
test "dropping an attribute costs a reset" {
  let bold_red = @style.Style::new(fg=@style.red, bold=true)
  let red = @style.Style::new(fg=@style.red)
  // No terminal can switch bold off on its own, so the whole style is resent.
  assert_eq(@style.delta(bold_red, red), esc + "0;31;49m")
  assert_eq(@style.delta(red, bold_red), esc + "1m")
}

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
  // The background is untouched: `over` left it as the terminal default.
  assert_eq(merged.bg, @style.blue)
  assert_eq(merged.attrs.bold, true)
  assert_eq(@style.default.is_default(), true)
  assert_eq(base.swap().fg, @style.blue)
}

///|
test "hex colours parse in both lengths" {
  assert_eq(@style.Color::parse("#abc"), Some(Rgb(170, 187, 204)))
  assert_eq(@style.Color::parse("#FF8800"), Some(Rgb(255, 136, 0)))
  assert_eq(@style.Color::parse("#ff880"), None)
  assert_eq(@style.Color::parse("ff8800"), None)
  assert_eq(@style.Color::parse("#gg0000"), None)
}

///|
test "true colour quantises to the cube and to the named sixteen" {
  assert_eq(@style.Color::rgb(255, 0, 0).to_ansi256(), Ansi256(196))
  // Grey text lands on the ramp rather than the cube, which is closer for it.
  assert_eq(@style.Color::rgb(128, 128, 128).to_ansi256(), Ansi256(244))
  assert_eq(@style.Color::rgb(250, 10, 10).to_ansi16(), @style.bright_red)
  // A named colour is already in every palette; resolving it would throw away
  // whatever the user configured it to be.
  assert_eq(@style.red.to_ansi256(), @style.red)
  assert_eq(@style.Color::Default.to_ansi16(), @style.Color::Default)
}

///|
test "blend mixes channel by channel" {
  let mixed = @style.Color::rgb(0, 0, 0).blend(
    @style.Color::rgb(100, 200, 50),
    50,
  )
  assert_eq(mixed, Rgb(50, 100, 25))
  assert_eq(@style.Color::rgb(1, 2, 3).blend(@style.white, 0), Rgb(1, 2, 3))
  // The terminal owns Default, so it cannot be mixed — the dominant end wins.
  assert_eq(@style.Color::Default.blend(@style.red, 80), @style.red)
  assert_eq(@style.Color::Default.blend(@style.red, 20), @style.Color::Default)
}

///|
test "a style quantises both of its colours" {
  let s = @style.Style::new(
    fg=@style.Color::rgb(255, 0, 0),
    bg=@style.Color::rgb(0, 0, 255),
  )
  assert_eq(s.to_ansi256().fg, Ansi256(196))
  assert_eq(s.to_ansi16().bg, @style.bright_blue)
}
