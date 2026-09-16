// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "entering and leaving unwind the same capabilities" {
  let on = @driver.enter()
  let off = @driver.leave()
  assert_eq(on.length() > 0, true)
  // The alternate screen is the first thing entered and the last thing left, so
  // nothing is drawn on the shell's screen in between.
  assert_eq(on[0:8].to_owned(), @driver.enter_alt)
  assert_eq(off[off.length() - 8:].to_owned(), @driver.leave_alt)
  // The cursor is hidden while the application owns the screen.
  assert_eq(on[on.length() - 6:].to_owned(), "\u{1b}[?25l")
}

///|
test "each capability can be left out" {
  let bare = @driver.enter(mouse=false, paste=false, focus=false, resize=false)
  assert_eq(bare, @driver.enter_alt + "\u{1b}[?25l")
  let nothing = @driver.leave(
    alt=false,
    mouse=false,
    paste=false,
    focus=false,
    resize=false,
  )
  assert_eq(nothing, "\u{1b}[?25h")
}

///|
test "a headless terminal records what was written" {
  let tty = @driver.Headless::new(@geom.Size::new(20, 5))
  tty.start()
  tty.write("hello")
  tty.write(" there")
  tty.flush()
  assert_eq(tty.output(), "hello there")
  tty.clear_output()
  assert_eq(tty.output(), "")
  assert_eq(tty.size(), @geom.Size::new(20, 5))
  assert_eq(tty.is_running(), true)
}

///|
test "polling hands out the script one chunk at a time" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 2), script=[b"ab", b"cd"])
  tty.start()
  assert_eq(tty.poll(10), b"ab")
  assert_eq(tty.poll(10), b"cd")
  // Once the script runs out the terminal simply has nothing to say, which is
  // what a real one does between key presses.
  assert_eq(tty.poll(10), b"")
}

///|
test "the clock advances by one tick per poll" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 2), tick=20)
  tty.start()
  assert_eq(tty.now(), 0)
  tty.poll(0) |> ignore
  tty.poll(0) |> ignore
  assert_eq(tty.now(), 40)
}

///|
test "the reported size can change under the application" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 2))
  tty.start()
  tty.set_size(@geom.Size::new(80, 24))
  assert_eq(tty.size(), @geom.Size::new(80, 24))
}

///|
test "writing after stop is an error, not a silent no-op" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 2))
  tty.start()
  tty.stop()
  assert_eq(tty.is_running(), false)
  let failed = try {
    tty.write("x")
    false
  } catch {
    Io(_) => true
  }
  assert_eq(failed, true)
}
