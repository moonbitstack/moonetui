// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every code point the two references agree on takes the columns they give it.
/// The vector is the whole of Unicode, run-length encoded, so this catches a
/// table that drifts as well as one that was wrong from the start.
test "code points take the columns wcwidth and UAX #11 agree on" {
  let mut checked = 0
  for (first, last, want) in width_runs {
    if want < 0 {
      continue
    }
    for cp in first..<=last {
      assert_eq(cell_width(cp), want)
      checked = checked + 1
    }
  }
  // The runs cover the whole of Unicode; the ones left out are surrogates and
  // the code points assigned after the references' Unicode version. This floor
  // catches a vector that was cut short, not a table that drifted: drift shows
  // up above as a failed comparison.
  assert_eq(checked > 290_000, true)
}
