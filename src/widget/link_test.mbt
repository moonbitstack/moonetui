// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a link shows its text and goes on Enter and on a click" {
  let link = @widget.Link::new("docs")
  assert_eq(link.render_line(0, size(20, 1)).text().trim_end(), "docs")
  assert_eq(link.focusable(), true)
  assert_eq(link.target(), "docs")
  let by_key = press(link, 1, size(20, 1), key(Enter))
  assert_eq(by_key.contains(@widget.Pressed(id=1)), true)
  assert_eq(by_key.contains(@widget.Selected(id=1, index=0)), true)
  assert_eq(link.is_visited(), true)
  link.visit(visited=false)
  assert_eq(link.is_visited(), false)
  let by_click = press(link, 1, size(20, 1), mouse(Down, 1, 0))
  assert_eq(by_click.contains(@widget.TakeFocus(id=1)), true)
  assert_eq(by_click.contains(@widget.Pressed(id=1)), true)
  assert_eq(link.is_visited(), true)
}

///|
test "a link can point somewhere other than what it says" {
  let link = @widget.Link::new("home", target="https://example.com")
  assert_eq(link.text(), "home")
  assert_eq(link.target(), "https://example.com")
  link.set("about")
  link.set_target("https://example.com/about")
  assert_eq(link.text(), "about")
  assert_eq(link.target(), "https://example.com/about")
}
