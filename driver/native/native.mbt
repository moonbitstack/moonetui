// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The terminal this process was started from.
pub struct NativeTty {
  buffer : FixedArray[Byte]
  scratch : FixedArray[Int]
  mut started : Bool
  mut raw : Bool
}

///|
/// A driver over the standard streams.
///
/// The read buffer is allocated once: a terminal hands over a few bytes at a
/// time, thousands of times a second, and allocating for each of them would be
/// the only garbage this library produces per frame.
pub fn NativeTty::new(buffer_size? : Int = 4096) -> NativeTty {
  {
    buffer: FixedArray::make(
      if buffer_size < 64 {
        64
      } else {
        buffer_size
      },
      b'\x00',
    ),
    scratch: FixedArray::make(2, 0),
    started: false,
    raw: false,
  }
}

///|
pub impl @driver.Driver for NativeTty with fn start(self) {
  // Raw mode fails when the program is not attached to a terminal — piped into
  // a file, run from a test harness. That is not an error: the application
  // still draws, and the output is exactly what a terminal would have shown.
  self.raw = tty_raw(true) == 0
  self.started = true
}

///|
pub impl @driver.Driver for NativeTty with fn stop(self) {
  self.started = false
  if self.raw && tty_raw(false) != 0 {
    raise @driver.Io("cannot restore the terminal")
  }
  self.raw = false
}

///|
pub impl @driver.Driver for NativeTty with fn write(self, text) {
  if !self.started {
    raise @driver.Io("write before start")
  }
  let bytes = @utf8.encode(text[:])
  if bytes.length() == 0 {
    return
  }
  if tty_write(bytes, bytes.length()) < 0 {
    raise @driver.Io("cannot write to the terminal")
  }
}

///|
pub impl @driver.Driver for NativeTty with fn flush(_self) {
  // Writes go straight to the file descriptor, so there is nothing held back.
}

///|
pub impl @driver.Driver for NativeTty with fn size(self) {
  if tty_size(self.scratch) != 0 {
    // A terminal that will not say how big it is — a pipe, a CI log — still has
    // to be drawn on, and the classic default is what everything else assumes.
    return @geom.Size::new(80, 24)
  }
  @geom.Size::new(self.scratch[0], self.scratch[1])
}

///|
pub impl @driver.Driver for NativeTty with fn poll(self, timeout) {
  let got = tty_read(self.buffer, self.buffer.length(), timeout)
  if got < 0 {
    raise @driver.Io("cannot read from the terminal")
  }
  if got == 0 {
    return b""
  }
  Bytes::from_array(self.buffer[0:got])
}

///|
pub impl @driver.Driver for NativeTty with fn now(_self) {
  tty_now()
}

///|
/// Whether the terminal is in raw mode. False means the program is not attached
/// to one, which a caller may want to report rather than discover later.
pub fn NativeTty::is_raw(self : NativeTty) -> Bool {
  self.raw
}

///|
/// Run an application to completion on the terminal.
///
/// A native program can block, so the frame loop is a loop. The browser and
/// Node drivers cannot, which is why the loop lives here rather than in `app`.
pub fn run(step : () -> Bool raise) -> Unit raise {
  while step() {

  }
}

///|
extern "C" fn tty_raw(on : Bool) -> Int = "moonetui_tty_raw"

///|
#borrow(text)
extern "C" fn tty_write(text : Bytes, len : Int) -> Int = "moonetui_tty_write"

///|
#borrow(buf)
extern "C" fn tty_read(buf : FixedArray[Byte], len : Int, timeout : Int) -> Int = "moonetui_tty_read"

///|
#borrow(out)
extern "C" fn tty_size(out : FixedArray[Int]) -> Int = "moonetui_tty_size"

///|
extern "C" fn tty_now() -> Int = "moonetui_tty_now"
