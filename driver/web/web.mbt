// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A terminal drawn on a canvas in a browser.
///
/// The application writes escape sequences as it would to any terminal; this
/// driver keeps the grid they describe and paints the cells that changed. Input
/// goes the other way: a key press is encoded into the same bytes a terminal
/// would send, so the parser above has nothing to special-case.
pub struct WebTty {
  grid : Grid
  mut started : Bool
}

///|
/// Take over the canvas with this element id and build a terminal on it.
///
/// The size comes from the canvas and the font: the grid is as many whole cells
/// as fit, which is why a browser terminal has to measure before it can say how
/// big it is.
pub fn WebTty::new(
  canvas? : String = "moonetui",
  font_px? : Int = 16,
) -> WebTty {
  js_init(canvas, font_px)
  { grid: Grid::new(js_cols(), js_rows()), started: false, }
}

///|
/// The grid as it stands, one string per row. A test reads this instead of
/// looking at pixels.
pub fn WebTty::rows(self : WebTty) -> Array[String] {
  self.grid.rows()
}

///|
pub impl @driver.Driver for WebTty with fn start(self) {
  self.started = true
  js_listen()
  self.check_size()
}

///|
pub impl @driver.Driver for WebTty with fn stop(self) {
  self.started = false
  js_unlisten()
}

///|
pub impl @driver.Driver for WebTty with fn write(self, text) {
  if !self.started {
    raise @driver.Io("write before start")
  }
  self.grid.write(text)
  self.paint()
}

///|
pub impl @driver.Driver for WebTty with fn flush(_self) {

}

///|
pub impl @driver.Driver for WebTty with fn size(self) {
  @geom.Size::new(self.grid.width, self.grid.height)
}

///|
pub impl @driver.Driver for WebTty with fn poll(self, _timeout) {
  // The browser cannot be blocked, so a frame gets whatever the listeners have
  // queued since the last one.
  self.check_size()
  js_drain()
}

///|
pub impl @driver.Driver for WebTty with fn now(_self) {
  js_now()
}

///|
/// Notice a canvas that changed size and tell the application in band, the way
/// a terminal does.
fn WebTty::check_size(self : WebTty) -> Unit {
  let cols = js_cols()
  let rows = js_rows()
  if cols == self.grid.width && rows == self.grid.height {
    return
  }
  self.grid.resize(cols, rows)
  js_report_resize(cols, rows)
}

///|
/// Draw every cell that changed.
fn WebTty::paint(self : WebTty) -> Unit {
  for at in self.grid.take_dirty() {
    let (x, y) = at
    let cell = self.grid.at(x, y)
    if cell.text.length() == 0 {
      // The second half of a wide character: its owner drew both columns.
      continue
    }
    let reverse = cell.style.attrs.reverse
    let fg = if reverse {
      css(cell.style.bg, back)
    } else {
      css(cell.style.fg, fore)
    }
    let bg = if reverse {
      css(cell.style.fg, fore)
    } else {
      css(cell.style.bg, back)
    }
    let width = @strip.str_cells(cell.text)
    js_draw(
      eighths(cell.text),
      x,
      y,
      if width == 0 {
        1
      } else {
        width
      },
      cell.text,
      fg,
      bg,
      cell.style.attrs.bold,
      cell.style.attrs.underline,
      cell.style.attrs.dim,
    )
  }
}

///|
/// How many eighths of a cell a block character fills, or zero when the text is
/// not one.
///
/// A font's block glyphs rarely tile: drawn as text they leave hairlines
/// between cells, which turns a progress bar into a dotted line. Terminal
/// emulators paint them as rectangles instead, and so does this one.
fn eighths(text : String) -> Int {
  if text.length() != 1 {
    return 0
  }
  match text[0].to_int() {
    0x2588 => 8
    0x2589 => 7
    0x258A => 6
    0x258B => 5
    0x258C => 4
    0x258D => 3
    0x258E => 2
    0x258F => 1
    _ => 0
  }
}

///|
/// What the terminal's own foreground is, when a style does not name one.
let fore : String = "#d4d4d4"

///|
/// And its background.
let back : String = "#1e1e1e"

///|
/// A colour as CSS. The indexed colours use the palette the library already
/// knows, so the browser shows what a terminal would.
fn css(color : @style.Color, fallback : String) -> String {
  match color.to_rgb() {
    None => fallback
    Some((r, g, b)) =>
      "rgb(" + r.to_string() + "," + g.to_string() + "," + b.to_string() + ")"
  }
}

///|
/// Set up the canvas, measure the font, and work out how many cells fit.
extern "js" fn js_init(canvas : String, font_px : Int) -> Unit =
  #| (id, px) => {
  #|   const g = globalThis;
  #|   const el = document.getElementById(id);
  #|   const ctx = el.getContext("2d");
  #|   const dpr = globalThis.devicePixelRatio || 1;
  #|   const font = px + "px ui-monospace, Menlo, Consolas, monospace";
  #|   ctx.font = font;
  #|   const cw = Math.max(1, ctx.measureText("M").width);
  #|   const ch = Math.max(1, px * 1.35);
  #|   const cols = Math.max(1, Math.floor(el.clientWidth / cw));
  #|   const rows = Math.max(1, Math.floor(el.clientHeight / ch));
  #|   el.width = Math.floor(el.clientWidth * dpr);
  #|   el.height = Math.floor(el.clientHeight * dpr);
  #|   ctx.scale(dpr, dpr);
  #|   ctx.font = font;
  #|   ctx.textBaseline = "top";
  #|   g.__moonetui_web = {
  #|     el, ctx, cw, ch, cols, rows, px, font, dpr,
  #|     queue: [], onKey: null, onPaste: null, onResize: null,
  #|   };
  #| }

///|
extern "js" fn js_cols() -> Int =
  #| () => globalThis.__moonetui_web.cols

///|
extern "js" fn js_rows() -> Int =
  #| () => globalThis.__moonetui_web.rows

///|
extern "js" fn js_now() -> Int =
  #| () => (performance.now() | 0)

///|
/// Paint one cell: its background, then its text.
extern "js" fn js_draw(
  block : Int,
  x : Int,
  y : Int,
  width : Int,
  text : String,
  fg : String,
  bg : String,
  bold : Bool,
  underline : Bool,
  dim : Bool,
) -> Unit =
  #| (block, x, y, width, text, fg, bg, bold, underline, dim) => {
  #|   const s = globalThis.__moonetui_web;
  #|   const px = x * s.cw, py = y * s.ch;
  #|   s.ctx.fillStyle = bg;
  #|   // Cell metrics are fractional, so a background filled at the exact width
  #|   // leaves a hairline of the page showing between cells.
  #|   s.ctx.fillRect(Math.floor(px), Math.floor(py),
  #|                  Math.ceil(px + s.cw * width) - Math.floor(px),
  #|                  Math.ceil(py + s.ch) - Math.floor(py));
  #|   if (block > 0) {
  #|     s.ctx.fillStyle = fg;
  #|     const right = px + s.cw * width * block / 8;
  #|     s.ctx.fillRect(Math.floor(px), Math.floor(py),
  #|                    Math.ceil(right) - Math.floor(px),
  #|                    Math.ceil(py + s.ch) - Math.floor(py));
  #|     return;
  #|   }
  #|   s.ctx.font = (bold ? "bold " : "") + s.font;
  #|   s.ctx.globalAlpha = dim ? 0.6 : 1;
  #|   s.ctx.fillStyle = fg;
  #|   s.ctx.fillText(text, px, py + 1);
  #|   s.ctx.globalAlpha = 1;
  #|   if (underline) {
  #|     s.ctx.fillRect(Math.floor(px), Math.floor(py + s.ch - 2), Math.ceil(s.cw * width), 1);
  #|   }
  #| }

///|
/// Start listening for keys, pasted text and canvas resizes.
extern "js" fn js_listen() -> Unit =
  #| () => {
  #|   const s = globalThis.__moonetui_web;
  #|   if (s.onKey) return;
  #|   const enc = new TextEncoder();
  #|   const ESC = String.fromCharCode(27), DEL = String.fromCharCode(127);
  #|   const send = (text) => { s.queue.push(enc.encode(text)); };
  #|   s.onKey = (ev) => {
  #|     const k = ev.key;
  #|     const mods = 1 + (ev.shiftKey ? 1 : 0) + (ev.altKey ? 2 : 0) + (ev.ctrlKey ? 4 : 0);
  #|     const csi = (last) => send(mods > 1 ? ESC + "[1;" + mods + last : ESC + "[" + last);
  #|     const tilde = (n) => send(mods > 1 ? ESC + "[" + n + ";" + mods + "~" : ESC + "[" + n + "~");
  #|     if (k === "ArrowUp") csi("A");
  #|     else if (k === "ArrowDown") csi("B");
  #|     else if (k === "ArrowRight") csi("C");
  #|     else if (k === "ArrowLeft") csi("D");
  #|     else if (k === "Home") csi("H");
  #|     else if (k === "End") csi("F");
  #|     else if (k === "PageUp") tilde(5);
  #|     else if (k === "PageDown") tilde(6);
  #|     else if (k === "Insert") tilde(2);
  #|     else if (k === "Delete") tilde(3);
  #|     else if (k === "Enter") send("\r");
  #|     else if (k === "Tab") send(ev.shiftKey ? "[Z" : "\t");
  #|     else if (k === "Backspace") send(DEL);
  #|     else if (k === "Escape") send(ESC);
  #|     else if (k.length === 1) {
  #|       if (ev.ctrlKey) {
  #|         const c = k.toLowerCase().charCodeAt(0);
  #|         if (c >= 97 && c <= 122) send(String.fromCharCode(c - 96));
  #|         else return;
  #|       } else if (ev.altKey) send(ESC + k);
  #|       else send(k);
  #|     } else return;
  #|     ev.preventDefault();
  #|   };
  #|   s.onPaste = (ev) => {
  #|     const text = (ev.clipboardData || window.clipboardData).getData("text");
  #|     send(ESC + "[200~" + text + ESC + "[201~");
  #|     ev.preventDefault();
  #|   };
  #|   s.onResize = () => {
  #|     const cols = Math.max(1, Math.floor(s.el.clientWidth / s.cw));
  #|     const rows = Math.max(1, Math.floor(s.el.clientHeight / s.ch));
  #|     if (cols === s.cols && rows === s.rows) return;
  #|     s.cols = cols; s.rows = rows;
  #|     s.el.width = Math.floor(s.el.clientWidth * s.dpr);
  #|     s.el.height = Math.floor(s.el.clientHeight * s.dpr);
  #|     s.ctx.scale(s.dpr, s.dpr);
  #|     s.ctx.font = s.font;
  #|     s.ctx.textBaseline = "top";
  #|   };
  #|   window.addEventListener("keydown", s.onKey);
  #|   window.addEventListener("paste", s.onPaste);
  #|   window.addEventListener("resize", s.onResize);
  #| }

///|
extern "js" fn js_unlisten() -> Unit =
  #| () => {
  #|   const s = globalThis.__moonetui_web;
  #|   if (!s || !s.onKey) return;
  #|   window.removeEventListener("keydown", s.onKey);
  #|   window.removeEventListener("paste", s.onPaste);
  #|   window.removeEventListener("resize", s.onResize);
  #|   s.onKey = null; s.onPaste = null; s.onResize = null;
  #| }

///|
/// Queue the in-band size report a terminal would send, so the application
/// learns about a resized canvas through the same path as everything else.
extern "js" fn js_report_resize(cols : Int, rows : Int) -> Unit =
  #| (cols, rows) => {
  #|   const s = globalThis.__moonetui_web;
  #|   const enc = new TextEncoder();
  #|   const ESC = String.fromCharCode(27), DEL = String.fromCharCode(127);
  #|   s.queue.push(enc.encode(String.fromCharCode(27) + "[48;" + rows + ";" + cols + "t"));
  #| }

///|
extern "js" fn js_drain() -> Bytes =
  #| () => {
  #|   const s = globalThis.__moonetui_web;
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
/// Drive `tick` on every animation frame until it returns false. A browser
/// paints when it is ready, so the frame comes from the browser rather than
/// from a loop.
pub fn pump(tick : () -> Bool) -> Unit {
  js_pump(tick)
}

///|
extern "js" fn js_pump(tick : () -> Bool) -> Unit =
  #| (tick) => {
  #|   const run = () => { if (tick()) requestAnimationFrame(run); };
  #|   requestAnimationFrame(run);
  #| }

///|
pub extend WebTty with @driver.Driver::{
  flush,
  start,
  now,
  stop,
  size,
  poll,
  write,
}
