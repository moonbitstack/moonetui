// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a switch is a four-wide strip with the thumb on the side of its value" {
  let off : &@widget.Widget = @widget.Switch::new()
  assert_eq(off.hint(size(80, 24)), size(4, 1))
  let on = @widget.Switch::new(value=true)
  let off_thumb = @strip.Strip::blank(
    2,
    @style.Style::new(
      fg=@style.bright_black,
      bg=@style.Colour::rgb(85, 85, 85),
      reverse=true,
    ),
  )
  assert_eq(
    off.render_line(0, size(4, 1)),
    @strip.Strip::join([
      off_thumb,
      @strip.Strip::blank(
        2,
        @style.Style::new(bg=@style.Colour::rgb(85, 85, 85)),
      ),
    ]),
  )
  ignore(on)
}

///|
test "space and a click toggle a switch and report it" {
  let sw = @widget.Switch::new()
  let out = press(sw, 3, size(4, 1), key(Enter))
  assert_eq(out, [@widget.Toggled(id=3, on=true), Repaint(id=3)])
  assert_true(sw.value())
  let out = press(sw, 3, size(4, 1), key(Enter))
  assert_eq(out, [@widget.Toggled(id=3, on=false), Repaint(id=3)])
  assert_false(sw.value())
}
