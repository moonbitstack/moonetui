// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a theme holds one colour for every role" {
  assert_eq(@design.roles().length(), 11)
  for role in @design.roles() {
    assert_eq(
      @design.light.colour(role) == @design.dark.colour(role),
      false,
      msg=role.name(),
    )
    assert_eq(role.name().length() > 0, true)
    assert_eq(role.note().length() > 0, true)
  }
  assert_eq(@design.dark.colour(@design.Primary), @style.cyan)
  assert_eq(@design.dark.colour(@design.Error), @style.red)
  assert_eq(
    @design.dark.colour(@design.Border),
    @style.Colour::rgb(70, 84, 110),
  )
}

///|
test "every theme this library carries has a name of its own" {
  assert_eq(@design.themes().length(), 3)
  assert_eq(@design.themes().map(theme => theme.name), ["dark", "light", "nord"])
  assert_eq(@design.Theme::of("nord").map(theme => theme.name), Some("nord"))
  assert_eq(@design.Theme::of("blue"), None)
  assert_eq(@design.dark.name, "dark")
}

///|
test "a role is changed without touching the rest" {
  let tinted = @design.dark.set(@design.Accent, @style.magenta)
  assert_eq(tinted.colour(@design.Accent), @style.magenta)
  assert_eq(
    tinted.colour(@design.Primary),
    @design.dark.colour(@design.Primary),
  )
  assert_eq(tinted.name, @design.dark.name)
  for role in @design.roles() {
    let own = @design.light.set(role, @style.black)
    assert_eq(own.colour(role), @style.black)
  }
}

///|
test "a theme hands out styles as well as colours" {
  assert_eq(@design.dark.fg(@design.Error), @style.Style::new(fg=@style.red))
  assert_eq(
    @design.dark.fill(@design.Panel),
    @style.Style::new(bg=@design.dark.colour(@design.Panel)),
  )
  assert_eq(
    @design.dark.base(),
    @style.Style::new(
      fg=@design.dark.colour(@design.Text),
      bg=@design.dark.colour(@design.Surface),
    ),
  )
}

///|
test "a theme becomes rules the stylesheet understands" {
  let sheet = @design.dark.sheet()
  assert_eq(sheet.list().length(), 22)
  assert_eq(
    sheet.pick("", 1, ["error"], false).text,
    Some(@style.Style::new(fg=@style.red)),
  )
  assert_eq(
    sheet.pick("", 1, ["panel-fill"], false).text,
    Some(@style.Style::new(bg=@design.dark.colour(@design.Panel))),
  )
}

///|
test "one sheet carries a theme and whatever is added after it" {
  let sheet = @design.dark.sheet()
  sheet.append(@design.Theme::new(name="one", primary=@style.black).sheet())
  // The rules added last win, so the second theme's colour is the one picked.
  assert_eq(
    sheet.pick("", 1, ["primary"], false).text,
    Some(@style.Style::new(fg=@style.black)),
  )
  assert_eq(
    sheet.pick("", 1, ["muted"], false).text,
    Some(@style.Style::new(fg=@design.dark.colour(@design.Muted))),
  )
}

///|
test "the light theme reads as words on paper" {
  assert_eq(@design.light.colour(@design.Text), @style.Colour::rgb(28, 32, 40))
  assert_eq(
    @design.light.colour(@design.Surface),
    @style.Colour::rgb(250, 250, 252),
  )
  assert_eq(@design.light.base().is_default(), false)
  assert_eq(
    @design.nord.colour(@design.Primary),
    @style.Colour::rgb(136, 192, 208),
  )
  assert_eq(
    @design.nord.colour(@design.Surface),
    @style.Colour::rgb(46, 52, 64),
  )
}

///|
test "an anchor and a pivot are style properties like any other" {
  let styles = @design.Styles::new(
    anchor=@layout.stretch,
    pivot=@layout.Middle,
    width=Cells(10),
    border=@design.Round,
  )
  let resolved = @design.Resolved::of(styles, @style.default)
  assert_eq(resolved.anchor, Some(@layout.stretch))
  assert_eq(resolved.pivot, @layout.Middle)
  assert_eq(resolved.width, Some(Cells(10)))
  assert_eq(@design.bare.anchor, None)
  assert_eq(@design.bare.pivot, @layout.TopLeft)
  let merged = @design.Styles::new(anchor=@layout.free).merge(
    @design.Styles::new(pivot=@layout.BottomRight),
  )
  assert_eq(merged.anchor, Some(@layout.free))
  assert_eq(merged.pivot, Some(@layout.BottomRight))
  assert_eq(@design.Styles::new(anchor=@layout.free).is_empty(), false)
}

///|
test "a resolved style keeps an anchored box to the size it names" {
  let resolved = @design.Resolved::of(
    @design.Styles::new(width=Cells(8), height=Cells(3)),
    @style.default,
  )
  assert_eq(resolved.box(Vertical, @layout.Box::new()).extent, Cells(3))
  assert_eq(resolved.box(Horizontal, @layout.Box::new()).extent, Cells(8))
}
