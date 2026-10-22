// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn letters(node : Int32, _line : Int32) -> @strip.Strip {
  let letter = match node {
    1 => "a"
    2 => "b"
    _ => "c"
  }
  let out = StringBuilder()
  for _ in 0..<8 {
    out.write_string(letter)
  }
  @strip.Strip::of(out.to_string(), plain)
}

///|
fn text_of(rows : Array[@strip.Strip]) -> String {
  let out = StringBuilder()
  for i in 0..<rows.length() {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(rows[i].text())
  }
  out.to_string()
}

///|
test "cuts are the screen edges plus every visible widget edge" {
  let scene = @comp.Scene::new(@geom.Size::new(10, 3))
  let screen = @geom.Region::new(0, 0, 10, 3)
  scene.place(1, @geom.Region::new(2, 0, 3, 1), screen)
  scene.place(2, @geom.Region::new(6, 0, 2, 3), screen)
  assert_eq(scene.cuts(0), [0, 2, 5, 6, 8, 10])
  assert_eq(scene.cuts(1), [0, 6, 8, 10])
}

///|
test "the front widget wins the columns it covers" {
  let scene = @comp.Scene::new(@geom.Size::new(8, 1))
  let screen = @geom.Region::new(0, 0, 8, 1)
  scene.place(1, @geom.Region::new(2, 0, 4, 1), screen)
  scene.place(2, @geom.Region::new(0, 0, 8, 1), screen)
  assert_eq(scene.compose_line(0, letters, plain).text(), "bbaaaabb")
}

///|
test "uncovered columns are blank in the base style" {
  let scene = @comp.Scene::new(@geom.Size::new(6, 2))
  let screen = @geom.Region::new(0, 0, 6, 2)
  scene.place(1, @geom.Region::new(1, 0, 2, 1), screen)
  assert_eq(text_of(scene.compose(letters, plain)), " aa   \n      ")
}

///|
test "a widget outside its clip draws nothing" {
  let scene = @comp.Scene::new(@geom.Size::new(6, 1))
  scene.place(1, @geom.Region::new(3, 0, 3, 1), @geom.Region::new(0, 0, 2, 1))
  assert_eq(scene.compose_line(0, letters, plain).text(), "      ")
}
