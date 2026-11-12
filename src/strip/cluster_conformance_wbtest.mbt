// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Text splits where two implementations of UAX #29 split it, and the whole of
/// it takes the columns wcwidth counts. The boundary each cluster starts at is
/// what a cursor steps over, so a miss here moves a caret, not just a number.
///
/// Where the vector gives -1 it holds back the columns and keeps the
/// boundaries: a spacing vowel sign takes a cell in wcwidth and none here, and
/// the two readings are both defensible.
test "text splits and measures as two references do" {
  for (text, starts, cells) in cluster_vectors {
    let got : Array[Int32] = []
    let mut total = 0
    for (start, _, width) in clusters(text) {
      got.push(start)
      total = total + width
    }
    assert_eq(got, starts)
    if cells >= 0 {
      assert_eq(total, cells)
    }
  }
}
