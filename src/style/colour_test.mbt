// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "hex colours parse in both lengths" {
  assert_eq(@style.Colour::parse("#abc"), Some(Rgb(170, 187, 204)))
  assert_eq(@style.Colour::parse("#FF8800"), Some(Rgb(255, 136, 0)))
  assert_eq(@style.Colour::parse("#ff880"), None)
  assert_eq(@style.Colour::parse("ff8800"), None)
  assert_eq(@style.Colour::parse("#gg0000"), None)
}

///|
test "true colour quantises to the cube and to the named sixteen" {
  assert_eq(@style.Colour::rgb(255, 0, 0).to_ansi256(), Ansi256(196))
  assert_eq(@style.Colour::rgb(128, 128, 128).to_ansi256(), Ansi256(244))
  assert_eq(@style.Colour::rgb(250, 10, 10).to_ansi16(), @style.bright_red)
  assert_eq(@style.red.to_ansi256(), @style.red)
  assert_eq(@style.Colour::Default.to_ansi16(), @style.Colour::Default)
}

///|
test "blend mixes channel by channel" {
  let mixed = @style.Colour::rgb(0, 0, 0).blend(
    @style.Colour::rgb(100, 200, 50),
    50,
  )
  assert_eq(mixed, Rgb(50, 100, 25))
  assert_eq(@style.Colour::rgb(1, 2, 3).blend(@style.white, 0), Rgb(1, 2, 3))
  assert_eq(@style.Colour::Default.blend(@style.red, 80), @style.red)
  assert_eq(
    @style.Colour::Default.blend(@style.red, 20),
    @style.Colour::Default,
  )
}
