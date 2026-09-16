// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let plain : @style.Style = @style.default

///|
let red : @style.Style = @style.Style::new(fg=@style.red)

///|
test "code points come back whole, surrogate pairs included" {
  // A grinning face is one character but two code units.
  let emoji = "😀"
  assert_eq(emoji.length(), 2)
  assert_eq(@strip.code_at(emoji, 0), (0x1F600, 2))
  assert_eq(@strip.code_at("a", 0), (97, 1))
  assert_eq(@strip.code_at("中", 0), (0x4E2D, 1))
}

///|
test "column widths follow the character database" {
  assert_eq(@strip.cell_width(97), 1)
  assert_eq(@strip.cell_width(0x4E2D), 2)
  assert_eq(@strip.cell_width(0x1F600), 2)
  // A combining acute accent sits on the character before it.
  assert_eq(@strip.cell_width(0x0301), 0)
  // A zero width joiner holds an emoji sequence together and takes no column.
  assert_eq(@strip.cell_width(0x200D), 0)
  assert_eq(@strip.cell_width(9), 0)
}

///|
test "string width adds up per column, not per character" {
  assert_eq(@strip.str_cells("abc"), 3)
  assert_eq(@strip.str_cells("中文"), 4)
  assert_eq(@strip.str_cells("a😀b"), 4)
  assert_eq(@strip.str_cells("e\u{301}"), 1)
  assert_eq(@strip.str_cells(""), 0)
}

///|
test "cut_at never splits a wide character" {
  // Three columns fit one wide character; the second would need a fourth.
  assert_eq(@strip.cut_at("中文", 3), 1)
  assert_eq(@strip.cut_at("中文", 4), 2)
  assert_eq(@strip.cut_at("中文", 1), 0)
  assert_eq(@strip.cut_at("abcd", 2), 2)
  assert_eq(@strip.cut_at("abcd", 99), 4)
  assert_eq(@strip.cut_at("abcd", 0), 0)
}

///|
test "cells_before measures a prefix" {
  assert_eq(@strip.cells_before("中a", 0), 0)
  assert_eq(@strip.cells_before("中a", 1), 2)
  assert_eq(@strip.cells_before("中a", 2), 3)
  assert_eq(@strip.cells_before("中a", 99), 3)
}

///|
test "a strip knows its width without re-measuring" {
  let s = @strip.Strip::of("中文abc", plain)
  assert_eq(s.cell_length(), 7)
  assert_eq(s.text(), "中文abc")
  assert_eq(@strip.Strip::empty().is_empty(), true)
  assert_eq(@strip.Strip::blank(4, plain).text(), "    ")
  assert_eq(@strip.Strip::blank(-2, plain).is_empty(), true)
}

///|
test "crop keeps the requested columns" {
  let s = @strip.Strip::of("hello", plain)
  assert_eq(s.crop(1, 4).text(), "ell")
  assert_eq(s.crop(0, 5), s)
  assert_eq(s.crop(4, 2).is_empty(), true)
  assert_eq(s.crop(-3, 2).text(), "he")
  assert_eq(s.crop(2, 99).text(), "llo")
}

///|
test "a wide character cut in half becomes a space" {
  let s = @strip.Strip::of("中文", plain)
  // One column of a two column character cannot be shown, so the half that
  // survives is blank — exactly what a terminal displays in that situation.
  assert_eq(s.crop(0, 1).text(), " ")
  assert_eq(s.crop(1, 4).text(), " 文")
  assert_eq(s.crop(0, 2).text(), "中")
  assert_eq(s.crop(1, 3).text(), "  ")
  assert_eq(s.crop(1, 4).cell_length(), 3)
}

///|
test "divide covers the line exactly and join puts it back" {
  let s = @strip.Strip::join([
    @strip.Strip::of("abc", plain),
    @strip.Strip::of("de", red),
  ])
  assert_eq(s.cell_length(), 5)
  let parts = s.divide([2, 4])
  assert_eq(parts.length(), 3)
  assert_eq(parts[0].text(), "ab")
  assert_eq(parts[1].text(), "cd")
  assert_eq(parts[2].text(), "e")
  let mut total = 0
  for part in parts {
    total = total + part.cell_length()
  }
  assert_eq(total, s.cell_length())
  assert_eq(@strip.Strip::join(parts).text(), s.text())
}

///|
test "divide tolerates cuts outside the line" {
  let s = @strip.Strip::of("abc", plain)
  let parts = s.divide([0, 99])
  assert_eq(parts.length(), 3)
  assert_eq(parts[0].is_empty(), true)
  assert_eq(parts[1].text(), "abc")
  assert_eq(parts[2].is_empty(), true)
}

///|
test "pad_to extends with spaces and crops when too long" {
  let s = @strip.Strip::of("ab", plain)
  assert_eq(s.pad_to(5, plain).text(), "ab   ")
  assert_eq(s.pad_to(5, plain).cell_length(), 5)
  assert_eq(s.pad_to(1, plain).text(), "a")
  assert_eq(s.pad_to(2, plain), s)
}

///|
test "apply layers a style under the segments" {
  let s = @strip.Strip::join([
    @strip.Strip::of("ab", red),
    @strip.Strip::of("cd", plain),
  ])
  let on_blue = s.apply(@style.Style::new(bg=@style.blue))
  // The red segment keeps its foreground and gains the background.
  assert_eq(on_blue.segs[0].style.fg, @style.red)
  assert_eq(on_blue.segs[0].style.bg, @style.blue)
  assert_eq(on_blue.segs[1].style.fg, @style.Color::Default)
  assert_eq(on_blue.segs[1].style.bg, @style.blue)
  assert_eq(on_blue.cell_length(), s.cell_length())
}

///|
test "simplify merges neighbours that share a style" {
  let s = @strip.Strip::from_segs([
    @strip.Seg::new("ab", plain),
    @strip.Seg::new("cd", plain),
    @strip.Seg::new("", plain),
    @strip.Seg::new("ef", red),
  ])
  let merged = s.simplify()
  assert_eq(merged.segs.length(), 2)
  assert_eq(merged.segs[0].text, "abcd")
  assert_eq(merged.segs[1].text, "ef")
  assert_eq(merged.cell_length(), 6)
  assert_eq(merged.text(), s.text())
}
