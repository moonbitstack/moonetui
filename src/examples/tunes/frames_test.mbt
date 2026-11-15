// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn hex16(text : String) -> String {
  let out = StringBuilder()
  let digit = fn(v : Int32) {
    if v < 10 {
      (48 + v).unsafe_to_char()
    } else {
      (97 + v - 10).unsafe_to_char()
    }
  }
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    out.write_char(digit(unit / 0x1000 % 16))
    out.write_char(digit(unit / 0x100 % 16))
    out.write_char(digit(unit / 0x10 % 16))
    out.write_char(digit(unit % 16))
  }
  out.to_string()
}

///|
fn interop_wanted() -> Bool {
  match @env.get_env_var("MOONETUI_INTEROP") {
    Some(_) => true
    None => false
  }
}

///|
fn announce(
  name : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  if !interop_wanted() {
    return
  }
  let line = StringBuilder()
  line.write_string(
    "interop\t" +
    name +
    "\tpyte,tmux\t" +
    size.width.to_string() +
    "\t" +
    size.height.to_string() +
    "\t" +
    hex16(stream),
  )
  for row in rows {
    line.write_string("\t" + hex16(row))
  }
  println(line.to_string())
}

///|
fn shot(
  ui : @app.App[@driver.Headless],
  driver : @driver.Headless,
  total : StringBuilder,
  name : String,
  size : @geom.Size,
) -> Unit raise {
  driver.clear_output()
  ui.refresh()
  ignore(ui.step())
  total.write_string(driver.output())
  announce(name, size, total.to_string(), ui.screen())
}

///|
test "a needle moves, a pause holds it, and the end of a track is the next" {
  let size = @geom.Size::new(80, 22)
  let screen = @tunes.Screen::new()
  let player = screen.player
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@tunes.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("tunes/00 open", size, total.to_string(), ui.screen())
  assert_true(player.playing())
  assert_eq(player.position(), 161)
  assert_eq(player.title(), "Aerial")
  assert_eq(player.length_of(0), 372)
  // The beat carries the needle on a second at a time. A frame may deliver a
  // tick of its own, so the check is a step rather than a fixed second.
  let was = player.position()
  player.advance(1000)
  assert_eq(player.position(), was + 1)
  shot(ui, driver, total, "tunes/01 running", size)
  // A pause holds it where it is.
  let held = player.position()
  player.toggle()
  player.advance(5000)
  assert_eq(player.position(), held)
  shot(ui, driver, total, "tunes/02 paused", size)
  // Seeking stops at the end of the track, and running off it starts the next
  // one from the top.
  player.toggle()
  player.seek(1000)
  assert_eq(player.position(), player.length_of(0))
  player.advance(1000)
  assert_eq(player.position(), 0)
  assert_eq(player.title(), "Always")
  shot(ui, driver, total, "tunes/03 next", size)
  // The arrows walk the album, and volume stops at its ends.
  player.step(1)
  assert_eq(player.title(), "Rope and Summit")
  player.loudness(30)
  assert_eq(player.volume, 100)
  player.loudness(30)
  assert_eq(player.volume, 100)
  shot(ui, driver, total, "tunes/04 next", size)
  assert_eq(player.total(), 2270)
}
