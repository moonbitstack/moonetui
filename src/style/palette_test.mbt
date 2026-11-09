///|
test "the preset resolves the named colours as the standard table does" {
  for i in 0..<16 {
    let colour = @style.Colour::Ansi(i)
    assert_eq(@style.palette.rgb(colour), colour.to_rgb())
  }
}

///|
test "a palette repaints the sixteen named colours, and only those" {
  let theme : @style.Palette = { named: [(0, 0, 0), (255, 0, 0)], }
  assert_eq(theme.rgb(@style.red), Some((255, 0, 0)))
  assert_eq(theme.rgb(@style.Colour::Ansi256(1)), Some((255, 0, 0)))
  assert_eq(theme.rgb(@style.Colour::Ansi(2)), @style.Colour::Ansi(2).to_rgb())
  assert_eq(
    theme.rgb(@style.Colour::Ansi256(196)),
    @style.Colour::Ansi256(196).to_rgb(),
  )
  assert_eq(theme.rgb(@style.Colour::Rgb(1, 2, 3)), Some((1, 2, 3)))
  assert_eq(theme.rgb(@style.Colour::Default), None)
}
