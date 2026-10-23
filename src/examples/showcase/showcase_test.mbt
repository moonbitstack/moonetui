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

///|
test "the gallery puts each demo on the stage as the menu moves to it" {
  let gallery = @showcase.Gallery::new()
  let tty = @driver.Headless::new(@geom.Size::new(100, 32))
  let ui = @app.App::new(tty, gallery.tree(), sheet=gallery.sheet())
  gallery.attach(ui)
  ui.start()
  // One screen for the whole run: each frame writes only what changed.
  let screen = @vt.Grid::new(100, 32)
  let demos = @showcase.demos()
  for i in 1..<demos.length() {
    tty.push(b"\x1b[B")
    ignore(ui.step())
    for out in ui.drain() {
      gallery.react(ui, out)
    }
    ignore(ui.step())
    screen.write(tty.output())
    tty.clear_output()
    assert_eq(gallery.at, i, msg=demos[i].name)
    let text = Array::makei(32, y => {
      Array::makei(100, x => screen.at(x, y).text).join("")
    }).join("\n")
    assert_eq(
      text.contains(demos[i].note.view(end_offset=20)),
      true,
      msg=demos[i].name,
    )
  }
}
