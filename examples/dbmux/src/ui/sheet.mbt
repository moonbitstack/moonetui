// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The stylesheet: words in the look's text colour. Everything else is drawn
/// by the rows in `look.mbt`, which carry their own colours.
pub fn sheet() -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(@design.Sel::new(), @design.Styles::new(text=body))
  sheet
}
