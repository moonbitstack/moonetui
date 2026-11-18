// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

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
  @frames.announce(name, size, total.to_string(), ui.screen())
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
  @frames.announce("pulse/00 open", size, total.to_string(), ui.screen())
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
