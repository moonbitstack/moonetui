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
test "the window slides, and holding it stops the world" {
  let size = @geom.Size::new(80, 24)
  let screen = @pulse.Screen::new()
  let pulse = screen.pulse
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@pulse.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("pulse/00 open", size, total.to_string(), ui.screen())
  // Sixty samples already arrived: the window is full on the first frame, in
  // the climb that the shape ends on.
  let first = pulse.latest()
  assert_true(first >= 8)
  // Eight more: the waveform walks, the oldest samples leave.
  for _ in 0..<8 {
    pulse.tick()
  }
  shot(ui, driver, total, "pulse/01 running", size)
  assert_true(pulse.latest() != first)
  // Held: a tick changes nothing, and the screen says so.
  pulse.toggle()
  let held = pulse.latest()
  pulse.tick()
  shot(ui, driver, total, "pulse/02 held", size)
  assert_eq(pulse.latest(), held)
}
