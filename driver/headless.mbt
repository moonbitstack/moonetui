// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A terminal that exists only in memory: input comes from a script, output
/// goes to a buffer, and the clock advances a fixed amount per poll.
///
/// This is what makes the rest of the library testable. A real terminal cannot
/// be asked what it received, cannot be driven deterministically, and is not
/// available at all on the backend the tests run on.
pub struct Headless {
  mut size : @geom.Size
  script : Array[Bytes]
  mut next : Int
  out : StringBuilder
  mut clock : Int
  tick : Int
  mut started : Bool
  mut stopped : Bool
}

///|
/// A headless terminal of this size, which will hand out the scripted chunks
/// one per poll and advance its clock by `tick` milliseconds each time.
pub fn Headless::new(
  size : @geom.Size,
  script? : Array[Bytes] = [],
  tick? : Int = 16,
) -> Headless {
  {
    size,
    script,
    next: 0,
    out: StringBuilder(),
    clock: 0,
    tick,
    started: false,
    stopped: false,
  }
}

///|
/// Everything written so far, escape sequences included.
pub fn Headless::output(self : Headless) -> String {
  self.out.to_string()
}

///|
/// Forget what has been written, so a test can talk about one frame at a time.
pub fn Headless::clear_output(self : Headless) -> Unit {
  self.out.reset()
}

///|
/// Change the size the driver reports, the way a window manager would.
pub fn Headless::set_size(self : Headless, size : @geom.Size) -> Unit {
  self.size = size
}

///|
/// Queue more input.
pub fn Headless::push(self : Headless, data : Bytes) -> Unit {
  self.script.push(data)
}

///|
/// True once `start` has run and `stop` has not.
pub fn Headless::is_running(self : Headless) -> Bool {
  self.started && not_stopped(self)
}

///|
fn not_stopped(driver : Headless) -> Bool {
  !driver.stopped
}

///|
pub impl Driver for Headless with fn start(self) {
  self.started = true
  self.stopped = false
}

///|
pub impl Driver for Headless with fn stop(self) {
  self.stopped = true
}

///|
pub impl Driver for Headless with fn write(self, text) {
  if self.stopped {
    raise Io("write after stop")
  }
  self.out.write_string(text)
}

///|
pub impl Driver for Headless with fn flush(_self) {

}

///|
pub impl Driver for Headless with fn size(self) {
  self.size
}

///|
pub impl Driver for Headless with fn poll(self, _timeout) {
  self.clock = self.clock + self.tick
  if self.next >= self.script.length() {
    return b""
  }
  let chunk = self.script[self.next]
  self.next = self.next + 1
  chunk
}

///|
pub impl Driver for Headless with fn now(self) {
  self.clock
}
