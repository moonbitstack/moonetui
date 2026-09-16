// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The terminal a Node process is attached to.
pub struct NodeTty {
  mut started : Bool
}

///|
/// A driver over Node's standard input and output.
pub fn NodeTty::new() -> NodeTty {
  { started: false, }
}

///|
pub impl @driver.Driver for NodeTty with fn start(self) {
  js_start()
  self.started = true
}

///|
pub impl @driver.Driver for NodeTty with fn stop(self) {
  js_stop()
  self.started = false
}

///|
pub impl @driver.Driver for NodeTty with fn write(self, text) {
  if !self.started {
    raise @driver.Io("write before start")
  }
  js_write(text)
}

///|
pub impl @driver.Driver for NodeTty with fn flush(_self) {

}

///|
pub impl @driver.Driver for NodeTty with fn size(_self) {
  let wide = js_columns()
  let high = js_rows()
  @geom.Size::new(wide, high)
}

///|
pub impl @driver.Driver for NodeTty with fn poll(_self, _timeout) {
  // Node cannot block: whatever the data handler has queued is what there is.
  js_drain()
}

///|
pub impl @driver.Driver for NodeTty with fn now(_self) {
  js_now()
}

///|
/// Put stdin into raw mode and start collecting what arrives. The queue lives on
/// the global object rather than in a closure so that a reload — a test runner
/// importing the module twice — does not end up with two of them.
extern "js" fn js_start() -> Unit =
  #| () => {
  #|   const g = globalThis;
  #|   if (!g.__moonetui) {
  #|     g.__moonetui = { queue: [], on: null };
  #|   }
  #|   const s = g.__moonetui;
  #|   if (s.on) return;
  #|   s.on = (chunk) => { s.queue.push(new Uint8Array(chunk)); };
  #|   if (process.stdin.isTTY) process.stdin.setRawMode(true);
  #|   process.stdin.resume();
  #|   process.stdin.on("data", s.on);
  #| }

///|
extern "js" fn js_stop() -> Unit =
  #| () => {
  #|   const s = globalThis.__moonetui;
  #|   if (!s || !s.on) return;
  #|   process.stdin.off("data", s.on);
  #|   if (process.stdin.isTTY) process.stdin.setRawMode(false);
  #|   process.stdin.pause();
  #|   s.on = null;
  #| }

///|
extern "js" fn js_write(text : String) -> Unit =
  #| (text) => { process.stdout.write(text); }

///|
/// Everything queued since the last call, in one piece.
extern "js" fn js_drain() -> Bytes =
  #| () => {
  #|   const s = globalThis.__moonetui;
  #|   if (!s || s.queue.length === 0) return new Uint8Array(0);
  #|   let total = 0;
  #|   for (const c of s.queue) total += c.length;
  #|   const out = new Uint8Array(total);
  #|   let at = 0;
  #|   for (const c of s.queue) { out.set(c, at); at += c.length; }
  #|   s.queue.length = 0;
  #|   return out;
  #| }

///|
extern "js" fn js_columns() -> Int =
  #| () => (process.stdout.columns || 80)

///|
extern "js" fn js_rows() -> Int =
  #| () => (process.stdout.rows || 24)

///|
/// Milliseconds since the process started. `Date.now()` would be the obvious
/// choice, but it does not fit in an `Int`: truncating it to 32 bits turns the
/// clock into an arbitrary number that can be negative, which makes every
/// elapsed-time comparison meaningless.
extern "js" fn js_now() -> Int =
  #| () => (performance.now() | 0)

///|
/// Drive `tick` every `ms` milliseconds until it returns false.
///
/// Node's input arrives through callbacks, so a program that spins in a loop
/// never lets a key press reach it. The frame has to come from the event loop
/// instead, which is what this hands back to the caller.
pub fn pump(ms : Int, tick : () -> Bool) -> Unit {
  js_pump(ms, tick)
}

///|
extern "js" fn js_pump(ms : Int, tick : () -> Bool) -> Unit =
  #| (ms, tick) => {
  #|   const id = setInterval(() => {
  #|     if (!tick()) {
  #|       clearInterval(id);
  #|       process.exit(0);
  #|     }
  #|   }, ms);
  #| }
