// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the house look is these twelve colours and no others" {
  let look = @design.studio
  assert_eq(look.name, "studio")
  assert_eq(look.colour(@design.Primary), @style.Colour::rgb(0x7A, 0xA2, 0xF7))
  assert_eq(
    look.colour(@design.Secondary),
    @style.Colour::rgb(0xBB, 0x9A, 0xF7),
  )
  assert_eq(look.colour(@design.Accent), @style.Colour::rgb(0x7D, 0xDF, 0xFF))
  assert_eq(look.colour(@design.Surface), @style.Colour::rgb(0x16, 0x1B, 0x27))
  assert_eq(look.colour(@design.Panel), @style.Colour::rgb(0x1E, 0x27, 0x3B))
  assert_eq(look.colour(@design.Text), @style.Colour::rgb(0xDC, 0xE3, 0xF1))
  assert_eq(look.colour(@design.Muted), @style.Colour::rgb(0x8B, 0x96, 0xAB))
  assert_eq(look.colour(@design.Success), @style.Colour::rgb(0x9E, 0xCE, 0x6A))
  assert_eq(look.colour(@design.Warning), @style.Colour::rgb(0xE0, 0xAF, 0x68))
  assert_eq(look.colour(@design.Error), @style.Colour::rgb(0xF7, 0x76, 0x8E))
  assert_eq(look.colour(@design.Border), @style.Colour::rgb(0x2C, 0x35, 0x48))
  // The step below the note colour carries no role, so it is a field of its
  // own: it is there, and it is not the note colour.
  assert_eq(look.faint, @style.Colour::rgb(0x5C, 0x67, 0x78))
  assert_eq(look.faint == look.colour(@design.Muted), false)
}

///|
test "the house look is found by name and is not one a screen switches to" {
  assert_eq(
    @design.Theme::of("studio").map(theme => theme.name),
    Some("studio"),
  )
  assert_eq(@design.themes().map(theme => theme.name), ["dark", "light", "nord"])
  // Every theme has a faint step, so a screen that dims words can do it
  // whatever look it wears.
  for theme in @design.themes() {
    assert_eq(theme.faint == theme.muted, false, msg=theme.name)
  }
}

///|
test "a band puts the name on the left, the note on the right, on the surface" {
  let look = @design.studio
  let strip = look.band("demo", subject="orders", note="5 tables", width=40)
  assert_eq(@strip.str_cells(strip.text()), 40)
  assert_eq(strip.text(), " demo  orders" + " ".repeat(17) + "5 tables  ")
  assert_eq(
    strip.segs[0].style,
    @style.Style::new(
      fg=look.colour(@design.Primary),
      bg=look.colour(@design.Surface),
      bold=true,
    ),
  )
}

///|
test "a band takes its colours from the theme it is given" {
  let tinted = @design.studio.set(@design.Primary, @style.red)
  let strip = tinted.band("demo", width=20)
  assert_eq(strip.segs[0].style.fg, @style.red)
  assert_eq(strip.segs[0].style.bg, tinted.colour(@design.Surface))
}

///|
test "a key bar draws each key in its cap and the meaning beside it" {
  let look = @design.studio
  let strip = look.keys([("q", "quit"), ("tab", "next")], width=30)
  assert_eq(@strip.str_cells(strip.text()), 30)
  assert_eq(strip.text(), "  q  quit   tab  next" + " ".repeat(9))
  assert_eq(strip.segs[1].text, " q ")
  assert_eq(
    strip.segs[1].style,
    @style.Style::new(
      fg=look.colour(@design.Surface),
      bg=look.colour(@design.Muted),
    ),
  )
}

///|
test "a panel head runs a rule to the edge and marks the panel with the keys" {
  let look = @design.studio
  let idle = look.panel_head("tables", count="5", width=30)
  assert_eq(@strip.str_cells(idle.text()), 30)
  assert_eq(idle.text(), " TABLES" + "─".repeat(20) + " 5 ")
  assert_eq(idle.segs[0].style, look.quiet())
  let live = look.panel_head("tables", count="5", width=30, active=true)
  assert_eq(live.segs[0].style, look.live())
  assert_eq(live.segs[0].style.fg, look.colour(@design.Primary))
  // A head that has something urgent to say says it in its own colour.
  let alarm = look.panel_head(
    "confirm",
    width=20,
    active=true,
    tone=Some(look.colour(@design.Error)),
  )
  assert_eq(alarm.segs[0].style.fg, look.colour(@design.Error))
}

///|
test "a rule and a divider are one glyph per cell" {
  let look = @design.studio
  assert_eq(look.rule(width=5).text(), "─────")
  assert_eq(look.divider(height=3).text(), "│││")
  assert_eq(look.rule(width=4).segs[0].style, look.edge())
}

///|
test "the named styles are the theme's roles at a weight" {
  let look = @design.studio
  assert_eq(
    look.mark(),
    @style.Style::new(fg=look.colour(@design.Primary), bold=true),
  )
  assert_eq(look.live(), look.mark())
  assert_eq(look.quiet(), @style.Style::new(fg=look.colour(@design.Muted)))
  assert_eq(look.dim(), @style.Style::new(fg=look.faint))
  assert_eq(look.edge(), @style.Style::new(fg=look.colour(@design.Border)))
  assert_eq(
    look.cursor(),
    @style.Style::new(
      fg=look.colour(@design.Text),
      bg=look.colour(@design.Panel),
      bold=true,
    ),
  )
  assert_eq(
    look.marker(),
    @style.Style::new(
      fg=look.colour(@design.Primary),
      bg=look.colour(@design.Panel),
      bold=true,
    ),
  )
}
