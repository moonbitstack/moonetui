// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "merge replaces what is set and keeps what is not" {
  let lower = @design.Styles::new(
    border=Some(@design.Thin),
    padding=Some(@geom.Spacing::all(1)),
  )
  let upper = @design.Styles::new(border=Some(@design.Heavy))
  let merged = lower.merge(upper)
  assert_eq(merged.border, Some(@design.Heavy))
  assert_eq(merged.padding, Some(@geom.Spacing::all(1)))
  assert_eq(merged.margin, None)
}

///|
test "merge layers a set text style field by field" {
  let lower = @design.Styles::new(
    text=Some(@style.Style::new(fg=@style.white, bg=@style.blue)),
  )
  let upper = @design.Styles::new(text=Some(@style.Style::new(bg=@style.green)))
  let merged = lower.merge(upper)
  let text = match merged.text {
    Some(text) => text
    None => @style.default
  }
  assert_eq(text.fg, @style.white)
  assert_eq(text.bg, @style.green)
}

///|
test "an id outweighs classes, a class outweighs a name" {
  let id = @design.Sel::new(id=7).specificity()
  let classes = @design.Sel::new(classes=["a", "b", "c"]).specificity()
  let one_class = @design.Sel::new(classes=["a"]).specificity()
  let name = @design.Sel::new(name="Panel").specificity()
  let focus = @design.Sel::new(focus=true).specificity()
  let any = @design.Sel::new().specificity()
  assert_eq(id > classes, true)
  assert_eq(one_class > name, true)
  assert_eq(focus > any, true)
}

///|
test "a selector that names nothing matches every node" {
  let sel = @design.Sel::new()
  assert_eq(sel.matches("anything", 42, [], false, false, false), true)
}

///|
test "a selector must find every class it names" {
  let sel = @design.Sel::new(classes=["primary", "tall"])
  assert_eq(
    sel.matches("Button", 3, ["tall", "primary"], false, false, false),
    true,
  )
  assert_eq(sel.matches("Button", 3, ["primary"], false, false, false), false)
}

///|
test "a focus selector matches only the focused node" {
  let sel = @design.Sel::new(focus=true)
  assert_eq(sel.matches("", 1, [], true, false, false), true)
  assert_eq(sel.matches("", 1, [], false, false, false), false)
}

///|
test "the most specific rule wins regardless of order" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(id=1),
    @design.Styles::new(padding=Some(@geom.Spacing::all(1))),
  )
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(padding=Some(@geom.Spacing::all(9))),
  )
  let picked = sheet.pick("", 1, [], false)
  assert_eq(picked.padding, Some(@geom.Spacing::all(1)))
}

///|
test "rules of equal weight are settled by which was written later" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Panel"),
    @design.Styles::new(border=Some(@design.Thin)),
  )
  sheet.add(
    @design.Sel::new(name="Panel"),
    @design.Styles::new(border=Some(@design.Round)),
  )
  let picked = sheet.pick("Panel", -1, [], false)
  assert_eq(picked.border, Some(@design.Round))
}

///|
test "a class rule overrides the name rule it is more specific than" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["tall"]),
    @design.Styles::new(border=Some(@design.Double)),
  )
  sheet.add(
    @design.Sel::new(name="Panel"),
    @design.Styles::new(border=Some(@design.Ascii)),
  )
  let picked = sheet.pick("Panel", -1, ["tall"], false)
  assert_eq(picked.border, Some(@design.Double))
}

///|
test "resolving inherits the container's text style under the node's own" {
  let inherited = @style.Style::new(bg=@style.blue)
  let own = @design.Styles::new(text=Some(@style.Style::new(fg=@style.white)))
  let resolved = @design.Resolved::of(own, inherited)
  assert_eq(resolved.text.fg, @style.white)
  assert_eq(resolved.text.bg, @style.blue)
  assert_eq(@design.Resolved::of(@design.empty, inherited).text, inherited)
}

///|
test "a hidden display hides, a block display does not" {
  let hidden = @design.Resolved::of(
    @design.Styles::new(display=Some(@design.Hidden)),
    @style.default,
  )
  assert_eq(hidden.hidden, true)
  let shown = @design.Resolved::of(
    @design.Styles::new(display=Some(@design.Block)),
    @style.default,
  )
  assert_eq(shown.hidden, false)
  assert_eq(@design.Resolved::of(@design.empty, @style.default).hidden, false)
}

///|
test "a resolved box overrides the axis the stack is stacking along" {
  let base = @layout.Box::new(extent=Frac(1), min=1, max=4)
  let resolved = @design.Resolved::of(
    @design.Styles::new(
      height=Some(Cells(2)),
      width=Some(Cells(9)),
      max_height=Some(8),
    ),
    @style.default,
  )
  let vertical = resolved.box(Vertical, base)
  assert_eq(vertical.extent, Cells(2))
  assert_eq(vertical.max, 8)
  assert_eq(vertical.min, 1)
  let horizontal = resolved.box(Horizontal, base)
  assert_eq(horizontal.extent, Cells(9))
  assert_eq(horizontal.max, 4)
}

///|
test "a border and a padding both take from the content region" {
  let outer = @geom.Region::new(0, 0, 10, 6)
  let plain = @design.Resolved::of(@design.empty, @style.default)
  assert_eq(plain.content_region(outer), outer)
  let framed = @design.Resolved::of(
    @design.Styles::new(
      border=Some(@design.Thin),
      padding=Some(@geom.Spacing::all(1)),
    ),
    @style.default,
  )
  assert_eq(framed.content_region(outer), @geom.Region::new(2, 2, 6, 2))
}

///|
test "chrome is drawn for borders, padding, and styled text, not for bare text" {
  let bare_node = @design.Resolved::of(@design.empty, @style.default)
  assert_eq(bare_node.has_chrome(), false)
  let borderless = @design.Resolved::of(
    @design.Styles::new(text=Some(@style.Style::new(bg=@style.blue))),
    @style.default,
  )
  assert_eq(borderless.has_chrome(), true)
  let framed = @design.Resolved::of(
    @design.Styles::new(border=Some(@design.Ascii)),
    @style.default,
  )
  assert_eq(framed.has_chrome(), true)
}

///|
test "a decor without a border fills its row with the background" {
  let decor : @design.Decor = {
    border: @design.Off,
    style: @style.Style::new(bg=@style.blue),
    size: @geom.Size::new(4, 2),
  }
  assert_eq(
    decor.line(0),
    @strip.Strip::blank(4, @style.Style::new(bg=@style.blue)),
  )
}

///|
test "a decor with a border draws the ring and the background inside it" {
  let decor : @design.Decor = {
    border: @design.Thin,
    style: @style.default,
    size: @geom.Size::new(4, 3),
  }
  assert_eq(decor.line(0).text(), "┌──┐")
  assert_eq(decor.line(1).text(), "│  │")
  assert_eq(decor.line(2).text(), "└──┘")
}

///|
test "align divides the slack along the stacking axis" {
  let top_left = @design.Align::new()
  let centred = @design.Align::new(h=@design.Centre, v=@design.Middle)
  assert_eq(top_left.main_offset(Vertical, 6), 0)
  assert_eq(centred.main_offset(Vertical, 6), 3)
  assert_eq(centred.main_offset(Vertical, 5), 2)
  assert_eq(top_left.main_offset(Horizontal, 6), 0)
  assert_eq(centred.main_offset(Horizontal, 6), 3)
  let bottom = @design.Align::new(v=@design.Bottom)
  assert_eq(bottom.main_offset(Vertical, -4), 0)
}

///|
test "the pseudo-classes weigh like a class each" {
  let plain = @design.Sel::new(name="Go")
  let hot = @design.Sel::new(name="Go", hover=true)
  let off = @design.Sel::new(name="Go", disabled=true)
  assert_eq(hot.specificity() > plain.specificity(), true)
  assert_eq(off.specificity() > plain.specificity(), true)
  let plain_class = @design.Sel::new(classes=["a"]).specificity()
  let hot_class = @design.Sel::new(classes=["a"], hover=true).specificity()
  assert_eq(hot_class > plain_class, true)
  assert_eq(hot.matches("Go", 1, [], false, false, false), false)
  assert_eq(hot.matches("Go", 1, [], false, true, false), true)
  assert_eq(off.matches("Go", 1, [], false, false, true), true)
}

///|
test "a disabled rule stacks over the plain one in the cascade" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Go"),
    @design.Styles::new(border=Some(@design.Thin)),
  )
  sheet.add(
    @design.Sel::new(name="Go", disabled=true),
    @design.Styles::new(border=Some(@design.Ascii)),
  )
  let styles = sheet.pick("Go", 1, [], false, disabled=true)
  assert_eq(styles.border, Some(@design.Ascii))
}

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

///|
test "offset and scrollbar styles merge like the rest" {
  let under = @design.Styles::new(offset_x=Some(1))
  let over = @design.Styles::new(offset_y=Some(2), transition=Some(50))
  let merged = under.merge(over)
  assert_eq(merged.offset_x, Some(1))
  assert_eq(merged.offset_y, Some(2))
  assert_eq(merged.transition, Some(50))
  let res = @design.Resolved::of(merged, @style.default)
  assert_eq(res.offset_x, 1)
  assert_eq(res.offset_y, 2)
  assert_eq(res.transition, 50)
}
