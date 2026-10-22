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
