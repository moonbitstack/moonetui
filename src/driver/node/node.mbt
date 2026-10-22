// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct NodeTty {
  mut started : Bool
}

///|
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
  js_drain()
}

///|
pub impl @driver.Driver for NodeTty with fn now(_self) {
  js_now()
}

///|
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
extern "js" fn js_columns() -> Int32 =
  #| () => (process.stdout.columns || 80)

///|
extern "js" fn js_rows() -> Int32 =
  #| () => (process.stdout.rows || 24)

///|
extern "js" fn js_now() -> Int32 =
  #| () => (performance.now() | 0)

///|
pub fn pump(ms : Int32, tick : () -> Bool) -> Unit {
  js_pump(ms, tick)
}

///|
extern "js" fn js_pump(ms : Int32, tick : () -> Bool) -> Unit =
  #| (ms, tick) => {
  #|   const id = setInterval(() => {
  #|     if (!tick()) {
  #|       clearInterval(id);
  #|       process.exit(0);
  #|     }
  #|   }, ms);
  #| }

///|
pub extend NodeTty with @driver.Driver::{
  flush,
  start,
  now,
  stop,
  size,
  poll,
  write,
}
