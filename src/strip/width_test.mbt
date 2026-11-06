// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "code points come back whole, surrogate pairs included" {
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
  assert_eq(@strip.cell_width(0x0301), 0)
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
test "a grapheme cluster takes the cells terminals give it" {
  // Woman, ZWJ, laptop: one emoji, two cells, not four.
  assert_eq(@strip.str_cells("\u{1F469}\u{200D}\u{1F4BB}"), 2)
  // A heart in text style is one cell; Variation Selector 16 asks for the emoji, two.
  assert_eq(@strip.str_cells("\u{2764}"), 1)
  assert_eq(@strip.str_cells("\u{2764}\u{FE0F}"), 2)
  assert_eq(@strip.str_cells("e\u{301}"), 1)
  // Two regional indicators are one flag.
  assert_eq(@strip.str_cells("\u{1F1EF}\u{1F1F5}"), 2)
}

///|
test "cutting and stepping never split a cluster" {
  let coder = "\u{1F469}\u{200D}\u{1F4BB}"
  let text = coder + "ab"
  assert_eq(@strip.cut_at(text, 1), 0)
  assert_eq(@strip.cut_at(text, 2), coder.length())
  assert_eq(@strip.next_cluster(text, 0), coder.length())
  assert_eq(@strip.prev_cluster(text, coder.length()), 0)
  assert_eq(@strip.cells_before(text, coder.length() + 1), 3)
}
