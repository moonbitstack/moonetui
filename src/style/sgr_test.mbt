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
    @style.render(@style.Style::new(bg=@style.Colour::rgb(10, 20, 30))),
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
  assert_eq(@style.delta(bold_red, red), esc + "0;31;49m")
  assert_eq(@style.delta(red, bold_red), esc + "1m")
}

///|
/// Every attribute reaches the terminal as its own parameter, whether it is
/// rendered whole or added to a style that lacked it.
test "each attribute names its own parameter" {
  let plain = @style.default
  assert_eq(@style.delta(plain, @style.Style::new(underline=true)), esc + "4m")
  assert_eq(@style.delta(plain, @style.Style::new(italic=true)), esc + "3m")
  assert_eq(@style.delta(plain, @style.Style::new(blink=true)), esc + "5m")
  assert_eq(@style.delta(plain, @style.Style::new(reverse=true)), esc + "7m")
  assert_eq(@style.delta(plain, @style.Style::new(strike=true)), esc + "9m")
  assert_eq(@style.delta(plain, @style.Style::new(dim=true)), esc + "2m")
  let all = @style.Style::new(
    bold=true,
    dim=true,
    italic=true,
    underline=true,
    blink=true,
    reverse=true,
    strike=true,
  )
  assert_eq(@style.render(all), esc + "0;1;2;3;4;5;7;9;39;49m")
}
