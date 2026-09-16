// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let plain : @style.Style = @style.default

///|
let red : @style.Style = @style.Style::new(fg=@style.red)

///|
/// Every widget draws its own letter across eight columns, which is wider than
/// any of them is placed — a widget renders its own line and the compositor
/// crops it to the piece the widget owns.
fn letters(node : Int, _line : Int) -> @strip.Strip {
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
test "columns carry wide characters as a pair" {
  let columns = @comp.cells(@strip.Strip::of("a中b", plain))
  assert_eq(columns.length(), 4)
  assert_eq(columns[0].text, "a")
  assert_eq(columns[1].text, "中")
  assert_eq(columns[2].continuation, true)
  assert_eq(columns[3].text, "b")
}

///|
test "a combining mark rides along with the column before it" {
  let columns = @comp.cells(@strip.Strip::of("e\u{301}x", plain))
  assert_eq(columns.length(), 2)
  assert_eq(columns[0].text, "e\u{301}")
  assert_eq(columns[1].text, "x")
}

///|
test "rebuilding a range substitutes a space for a halved character" {
  let columns = @comp.cells(@strip.Strip::of("中文", plain))
  assert_eq(@comp.line_of(columns[0:4], plain).text(), "中文")
  // Starting on the second half of 中: only a space can be shown.
  assert_eq(@comp.line_of(columns[1:4], plain).text(), " 文")
  // Ending before the second half of 文: likewise.
  assert_eq(@comp.line_of(columns[0:3], plain).text(), "中 ")
}

///|
test "cuts are the screen edges plus every visible widget edge" {
  let scene = @comp.Scene::new(@geom.Size::new(10, 3))
  let screen = @geom.Region::new(0, 0, 10, 3)
  scene.place(1, @geom.Region::new(2, 0, 3, 1), screen)
  scene.place(2, @geom.Region::new(6, 0, 2, 3), screen)
  assert_eq(scene.cuts(0), [0, 2, 5, 6, 8, 10])
  // The first widget is one row tall, so it leaves no edge on the second row.
  assert_eq(scene.cuts(1), [0, 6, 8, 10])
}

///|
test "the front widget wins the columns it covers" {
  let scene = @comp.Scene::new(@geom.Size::new(8, 1))
  let screen = @geom.Region::new(0, 0, 8, 1)
  // Placed front to back: the second is partly hidden by the first.
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
  // The clip covers the first two columns; the widget starts after them.
  scene.place(1, @geom.Region::new(3, 0, 3, 1), @geom.Region::new(0, 0, 2, 1))
  assert_eq(scene.compose_line(0, letters, plain).text(), "      ")
}

///|
test "one changed column produces one span" {
  let before = [@strip.Strip::of("hello", plain)]
  let after = [@strip.Strip::of("hEllo", plain)]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].y, 0)
  assert_eq(spans[0].x, 1)
  assert_eq(spans[0].line.text(), "E")
}

///|
test "identical screens produce no spans" {
  let rows = [@strip.Strip::of("same", plain), @strip.Strip::of("rows", plain)]
  assert_eq(@comp.diff(rows, rows).length(), 0)
}

///|
test "a style change alone is a difference" {
  let before = [@strip.Strip::of("ab", plain)]
  let after = [
    @strip.Strip::join([
      @strip.Strip::of("a", plain),
      @strip.Strip::of("b", red),
    ]),
  ]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].x, 1)
  assert_eq(spans[0].line.segs[0].style, red)
}

///|
test "a row that got shorter has its tail cleared" {
  let before = [@strip.Strip::of("longer", plain)]
  let after = [@strip.Strip::of("longer", plain).crop(0, 4)]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].x, 4)
  // The columns past the end of the new row are repainted as blanks.
  assert_eq(spans[0].line.text(), "  ")
}

///|
test "a wide character drags both of its columns into the span" {
  let before = [@strip.Strip::of("ab中", plain)]
  let after = [@strip.Strip::of("ab文", plain)]
  let spans = @comp.diff(before, after)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].x, 2)
  assert_eq(spans[0].line.text(), "文")
}

///|
test "a full repaint is one span per row" {
  let rows = [@strip.Strip::of("ab", plain), @strip.Strip::of("cd", plain)]
  let spans = @comp.full(rows)
  assert_eq(spans.length(), 2)
  assert_eq(spans[1].y, 1)
  assert_eq(spans[1].x, 0)
}

///|
test "encoding moves the cursor and emits only the style changes" {
  let spans : Array[@comp.Span] = [
    { y: 0, x: 2, line: @strip.Strip::of("hi", plain), },
    { y: 1, x: 0, line: @strip.Strip::of("x", red), },
  ]
  let text = @comp.encode(spans, plain)
  // Reset, jump to row one column three, the text, jump to row two column one,
  // turn the foreground red, the text, and back to the base style.
  assert_eq(
    text, "\u{1b}[0;39;49m\u{1b}[1;3Hhi\u{1b}[2;1H\u{1b}[31mx\u{1b}[39m",
  )
}

///|
test "encoding nothing writes nothing" {
  let empty : Array[@comp.Span] = []
  assert_eq(@comp.encode(empty, plain), "")
}

///|
test "cursor and screen control sequences" {
  assert_eq(@comp.cursor_to(0, 0), "\u{1b}[1;1H")
  assert_eq(@comp.cursor_to(23, 79), "\u{1b}[24;80H")
  assert_eq(@comp.show_cursor(false), "\u{1b}[?25l")
  assert_eq(@comp.clear, "\u{1b}[2J\u{1b}[H")
}
