// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Headless {
  mut size : @geom.Size
  script : Array[Bytes]
  mut next : Int32
  out : StringBuilder
  mut clock : Int32
  tick : Int32
  mut started : Bool
  mut stopped : Bool
}

///|
pub fn Headless::new(
  size : @geom.Size,
  script~ : Array[Bytes] = [],
  tick~ : Int32 = 16,
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
pub fn Headless::output(self : Headless) -> String {
  self.out.to_string()
}

///|
pub fn Headless::clear_output(self : Headless) -> Unit {
  self.out.reset()
}

///|
pub fn Headless::set_size(self : Headless, size : @geom.Size) -> Unit {
  self.size = size
}

///|
pub fn Headless::push(self : Headless, data : Bytes) -> Unit {
  self.script.push(data)
}

///|
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

///|
pub extend Headless with Driver::{flush, start, now, stop, size, poll, write}
