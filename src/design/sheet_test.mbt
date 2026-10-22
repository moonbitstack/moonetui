// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

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
