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

///|
fn shown(doc : String, width : Int32, height : Int32) -> Array[String] {
  let md : &@widget.Widget = @widget.Markdown::new(doc)
  rows(md, size(width, height)).map(r => r.trim_end().to_owned())
}

///|
test "markdown numbers ordered lists, nested by indent" {
  assert_eq(shown("1. one\n2) two\n  10. ten\n", 16, 3), [
    "1. one", "2. two", "  10. ten",
  ])
}

///|
test "markdown reads what only looks like a list, heading or fence as text" {
  assert_eq(shown("1.x\n\n#nope\n\n``\n\n-", 12, 7), [
    "1.x", "", "#nope", "", "``", "", "•",
  ])
}

///|
test "a block closes the paragraph and the quote before it" {
  let doc = "para\n# Head\n> q\n- item\n> r\n1. n\n> s\n```\ncode\n```\n> t\n---\n> u\n| A |\n|--:|\n| 1 |"
  let out = shown(doc, 12, 30).filter(r => r != "")
  assert_eq(out, [
    "para", "Head", "▌ q", "• item", "▌ r", "1. n", "▌ s", "code", "▌ t",
    "────────────", "▌ u", " A", "───", " 1",
  ])
}

///|
test "markdown joins the lines of a quote, and a plain line after a quote starts a paragraph" {
  assert_eq(shown("> one\n> two\nthree", 16, 3), ["▌ one two", "", "three"])
}

///|
test "markdown escapes, and an underscore inside a word is just a character" {
  let md = @widget.Markdown::new("\\*not\\* snake_case _lean_")
  let w : &@widget.Widget = md
  let line = w.render_line(0, size(30, 1))
  assert_eq(line.text().trim_end(), "*not* snake_case lean")
  guard line.segs.iter().find_first(seg => seg.text == "lean") is Some(seg) else {
    abort("no segment reads lean")
  }
  assert_eq(seg.style.attrs.italic, true)
}

///|
test "markdown leaves a link without its target as text" {
  assert_eq(shown("[a] and [b](", 16, 1), ["[a] and [b]("])
}

///|
test "markdown tables keep an escaped pipe inside a cell" {
  assert_eq(shown("| a\\|b | c |\n|---|---|\n| 1 | 2 |", 16, 3), [
    " a|b │ c", "─────┼───", " 1   │ 2",
  ])
}

///|
test "markdown code spans keep their insides literal, and a lone star is a star" {
  let md = @widget.Markdown::new("`a*b*c` and ``x ` y`` but 2 * 3 * 4")
  let w : &@widget.Widget = md
  let line = w.render_line(0, size(40, 1))
  assert_eq(line.text().trim_end(), "a*b*c and x ` y but 2 * 3 * 4")
  assert_eq(line.segs.iter().all(seg => !seg.style.attrs.italic), true)
}
