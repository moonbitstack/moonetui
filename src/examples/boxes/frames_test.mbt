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
test "a restart cycles, a stop greys a box, and the tail can be paused" {
  let size = @geom.Size::new(80, 22)
  let screen = @boxes.Screen::new()
  let host = screen.host
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@boxes.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("boxes/00 open", size, total.to_string(), ui.screen())
  assert_eq(host.running(), 6)
  assert_eq(host.pick(), 0)
  assert_eq(host.name_of(0), "api-gateway")
  // The arrows walk the list.
  host.shift(1)
  assert_eq(host.name_of(host.pick()), "postgres")
  shot(ui, driver, total, "boxes/01 second", size)
  // A restart takes the box out of running, and the next beat brings it back
  // with its uptime at zero.
  host.restart()
  assert_true(host.state_of(1) == @boxes.Restarting)
  assert_eq(host.running(), 5)
  shot(ui, driver, total, "boxes/02 restarting", size)
  host.advance()
  assert_true(host.state_of(1) == @boxes.Running)
  assert_eq(host.running(), 6)
  shot(ui, driver, total, "boxes/03 back", size)
  // A stop leaves the box grey, and its arrows still select it.
  host.stop()
  assert_true(host.state_of(1) == @boxes.Exited)
  assert_eq(host.running(), 5)
  shot(ui, driver, total, "boxes/04 stopped", size)
  // A paused tail stops writing new lines.
  host.pause()
  let before = host.logs_of(1)
  host.advance()
  host.advance()
  assert_eq(host.logs_of(1), before)
  shot(ui, driver, total, "boxes/05 paused", size)
}
