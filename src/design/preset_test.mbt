// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the presets carry a base style and a sheet of rules" {
  let dark = @design.Preset::dark()
  assert_eq(dark.base.fg, @style.bright_white)
  assert_eq(dark.sheet.is_empty(), false)
  let head = dark.sheet.pick("Header", 1, [], false)
  assert_eq(head.text, Some(@style.Style::new(bold=true, fg=@style.cyan)))
  let light = @design.Preset::light()
  assert_eq(light.base.fg, @style.black)
  assert_eq(light.base.bg, @style.white)
}
