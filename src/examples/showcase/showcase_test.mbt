// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "every demo starts, draws something and has a name of its own" {
  let names : Array[String] = []
  for demo in @showcase.demos() {
    assert_eq(names.contains(demo.name), false)
    names.push(demo.name)
    let tty = @driver.Headless::new(@geom.Size::new(60, demo.rows))
    let ui = @app.App::new(tty, demo.tree, sheet=demo.sheet)
    for id in demo.disabled {
      ui.disable(id)
    }
    ui.start()
    let screen = @vt.Grid::new(60, demo.rows)
    screen.write(tty.output())
    let mut drawn = false
    for y in 0..<demo.rows {
      for x in 0..<60 {
        let cell = screen.at(x, y)
        drawn = drawn || cell.text.trim() != "" || cell.style != @style.default
      }
    }
    assert_eq(drawn, true, msg=demo.name)
  }
  assert_eq(@showcase.find("Button").map(demo => demo.group), Some(Navigation))
}
