// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "markdown lays out headings lists quotes code rules and tables" {
  let doc = "# Title\nword one two\n\n- first\n- second\n\n> quoted line\n\n```\nlet x = 1\n```\n\n---\n\n| A | B |\n|---|:-:|\n| 1 | 22 |\n"
  let md : &@widget.Widget = @widget.Markdown::new(doc)
  assert_eq(rows(md, size(20, 16)), [
    "Title               ", "                    ", "word one two        ", "                    ",
    "• first             ", "• second            ", "                    ", "▌ quoted line       ",
    "                    ", "let x = 1           ", "                    ", "────────────────────",
    "                    ", " A │ B              ", "───┼────            ",
    " 1 │ 22             ",
  ])
}

///|
test "markdown styles inline bold italic code and links" {
  let doc = "plain **bold** and *lean* plus `code` with [MoonBit](https://moonbitlang.com) here"
  let md = @widget.Markdown::new(doc)
  let w : &@widget.Widget = md
  let line = w.render_line(0, size(60, 1))
  let style_of = (word : String) => {
    guard line.segs.iter().find_first(seg => seg.text == word) is Some(seg) else {
      abort("no segment reads " + word)
    }
    seg.style
  }
  assert_eq(style_of("plain").attrs.bold, false)
  assert_eq(style_of("bold").attrs.bold, true)
  assert_eq(style_of("lean").attrs.italic, true)
  assert_eq(style_of("code").fg, @style.cyan)
  assert_eq(style_of("MoonBit").attrs.underline, true)
}

///|
test "markdown scrolls through long documents" {
  let parts : Array[String] = []
  for i in 0..<12 {
    parts.push("line \{i}")
  }
  ignore(parts)
  let mut doc = ""
  for i in 0..<12 {
    if i > 0 {
      doc = doc + "\n\n"
    }
    doc = doc + "para \{i}"
  }
  let md : &@widget.Widget = @widget.Markdown::new(doc)
  let at = size(10, 3)
  assert_eq(press(md, 8, at, key(Down)), [
    @widget.Scrolled(id=8, x=0, y=1),
    @widget.Repaint(id=8),
  ])
  assert_eq(press(md, 8, at, key(PageDown)), [
    @widget.Scrolled(id=8, x=0, y=3),
    @widget.Repaint(id=8),
  ])
  assert_eq(rows(md, at), ["          ", "para 2    ", "          "])
  assert_eq(md.hint(size(10, 24)).height, 23)
}

///|
test "markdown wraps paragraphs at spaces and keeps styles across the break" {
  let md = @widget.Markdown::new("one **two three four** five")
  let w : &@widget.Widget = md
  let at = size(12, 3)
  assert_eq(rows(w, at), ["one two     ", "three four  ", "five        "])
  let second = w.render_line(1, at)
  assert_eq(second.segs[0].text, "three")
  assert_eq(second.segs[0].style.attrs.bold, true)
}

///|
test "a fenced block keeps its lines together and apart" {
  let md = @widget.Markdown::new("```\nlet x = 1\nlet y = 2\n```")
  let w : &@widget.Widget = md
  assert_eq(rows(w, size(10, 2)), ["let x = 1 ", "let y = 2 "])
}
