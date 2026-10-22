// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The page-side half of one terminal: its canvas, measurements, queued input
/// and listeners. Each `WebTty` owns one, so a page can hold as many terminals
/// as it has canvases.
#external
priv type Host

///|
/// A terminal drawn on a canvas.
///
/// Keys, pastes and the mouse are taken from the canvas only while it has focus,
/// so the rest of the page keeps its own keyboard. The mouse is reported when the
/// application turns reporting on, in the form it asked for.
struct WebTty {
  host : Host
  grid : @vt.Grid
  mut started : Bool
}

///|
/// A terminal on the canvas whose id is `canvas`, in a `font_px` monospace font,
/// painting `fg` and `bg` (any CSS colour) where the application leaves the
/// colours unset.
pub fn WebTty::new(
  canvas~ : String = "moonetui",
  font_px~ : Int32 = 16,
  fg~ : String = "#d4d4d4",
  bg~ : String = "#1e1e1e",
) -> WebTty {
  let host = js_init(canvas, font_px, fg, bg)
  { host, grid: @vt.Grid::new(js_cols(host), js_rows(host)), started: false, }
}

///|
/// The screen the canvas shows, for a test or a screenshot.
pub fn WebTty::grid(self : WebTty) -> @vt.Grid {
  self.grid
}

///|
pub fn WebTty::rows(self : WebTty) -> Array[String] {
  self.grid.rows()
}

///|
pub impl @driver.Driver for WebTty with fn start(self) {
  self.started = true
  js_listen(self.host)
  self.check_size()
}

///|
pub impl @driver.Driver for WebTty with fn stop(self) {
  self.started = false
  js_unlisten(self.host)
}

///|
pub impl @driver.Driver for WebTty with fn write(self, text) {
  if !self.started {
    raise @driver.Io("write before start")
  }
  self.grid.write(text)
  let motion = if self.grid.mode(1003) {
    2
  } else if self.grid.mode(1002) {
    1
  } else {
    0
  }
  js_modes(
    self.host,
    self.grid.mode(1000) || motion > 0,
    motion,
    self.grid.mode(1006),
    self.grid.mode(2004),
  )
  self.paint()
}

///|
pub impl @driver.Driver for WebTty with fn flush(_self) {

}

///|
pub impl @driver.Driver for WebTty with fn size(self) {
  @geom.Size::new(self.grid.width(), self.grid.height())
}

///|
pub impl @driver.Driver for WebTty with fn poll(self, _timeout) {
  self.check_size()
  js_drain(self.host)
}

///|
pub impl @driver.Driver for WebTty with fn now(_self) {
  js_now()
}

///|
/// Follow the canvas: a new cell count resizes the grid and tells the
/// application in-band; a canvas that was cleared without changing size, as a
/// change of pixel ratio does, is painted again from the grid.
fn WebTty::check_size(self : WebTty) -> Unit {
  let cols = js_cols(self.host)
  let rows = js_rows(self.host)
  if cols != self.grid.width() || rows != self.grid.height() {
    self.grid.resize(cols, rows)
    js_report_resize(self.host, cols, rows)
  } else if js_cleared(self.host) {
    self.grid.dirty_all()
    self.paint()
  }
}

///|
fn WebTty::paint(self : WebTty) -> Unit {
  for at in self.grid.take_dirty() {
    let (x, y) = at
    let cell = self.grid.at(x, y)
    if cell.text.length() == 0 {
      continue
    }
    let attrs = cell.style.attrs
    let (fore, back) = if attrs.reverse {
      (cell.style.bg, cell.style.fg)
    } else {
      (cell.style.fg, cell.style.bg)
    }
    let width = @strip.str_cells(cell.text)
    js_draw(
      self.host,
      x,
      y,
      if width == 0 {
        1
      } else {
        width
      },
      cell.text,
      css(fore),
      css(back),
      (if attrs.reverse { 32 } else { 0 }) |
      (if attrs.bold { 1 } else { 0 }) |
      (if attrs.dim { 2 } else { 0 }) |
      (if attrs.italic { 4 } else { 0 }) |
      (if attrs.underline { 8 } else { 0 }) |
      (if attrs.strike { 16 } else { 0 }),
    )
  }
}

///|
/// A colour as CSS, or the empty string for the terminal's own default, which
/// the page side resolves against its `fg` or `bg`.
fn css(colour : @style.Colour) -> String {
  match colour.to_rgb() {
    None => ""
    Some((r, g, b)) => "rgb(\{r},\{g},\{b})"
  }
}

///|
extern "js" fn js_init(
  canvas : String,
  font_px : Int32,
  fg : String,
  bg : String,
) -> Host =
  #| (id, px, fg, bg) => {
  #|   const el = document.getElementById(id);
  #|   if (!el || !el.getContext) throw new Error("moonetui: no canvas with id " + id);
  #|   if (!globalThis.__moonetui_glyphs) {
  #|     const table = ("0101 0202 1010 2020 01013 02023 10103 20203 01014 02024 10104 20204 " +
  #|       "0110 0210 0120 0220 0011 0012 0021 0022 1100 1200 2100 2200 1001 1002 2001 2002 " +
  #|       "1110 1210 2110 1120 2120 2210 1220 2220 1011 1012 2011 1021 2021 2012 1022 2022 " +
  #|       "0111 0112 0211 0212 0121 0122 0221 0222 1101 1102 1201 1202 2101 2102 2201 2202 " +
  #|       "1111 1112 1211 1212 2111 1121 2121 2112 2211 1122 1221 2212 1222 2122 2221 2222 " +
  #|       "01012 02022 10102 20202 0303 3030 0310 0130 0330 0013 0031 0033 1300 3100 3300 " +
  #|       "1003 3001 3003 1310 3130 3330 1013 3031 3033 0313 0131 0333 1303 3101 3303 1313 " +
  #|       "3131 3333 0110a 0011a 1001a 1100a / B X 0001 1000 0100 0010 0002 2000 0200 0020 " +
  #|       "0201 1020 0102 2010").split(" ");
  #|     const quads = [4, 8, 1, 13, 9, 7, 11, 2, 6, 14];
  #|     const box = (ctx, entry, x0, y0, x1, y1) => {
  #|       const w = x1 - x0, h = y1 - y0;
  #|       const t = Math.max(1, Math.round(h / 16));
  #|       const cx = Math.floor(x0 + w / 2 - t / 2), cy = Math.floor(y0 + h / 2 - t / 2);
  #|       if (entry === "/" || entry === "B" || entry === "X") {
  #|         ctx.lineWidth = t;
  #|         ctx.beginPath();
  #|         if (entry !== "B") { ctx.moveTo(x1, y0); ctx.lineTo(x0, y1); }
  #|         if (entry !== "/") { ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); }
  #|         ctx.stroke();
  #|         return;
  #|       }
  #|       const seg = [0, 1, 2, 3].map(i => +entry[i]);
  #|       const flag = entry[4];
  #|       if (flag === "a") {
  #|         const ends = [[cx + t / 2, y0], [x1, cy + t / 2], [cx + t / 2, y1], [x0, cy + t / 2]];
  #|         const [a, b] = [0, 1, 2, 3].filter(i => seg[i] > 0);
  #|         ctx.lineWidth = t;
  #|         ctx.beginPath();
  #|         ctx.moveTo(ends[a][0], ends[a][1]);
  #|         ctx.arcTo(cx + t / 2, cy + t / 2, ends[b][0], ends[b][1], Math.min(w, h) / 2);
  #|         ctx.lineTo(ends[b][0], ends[b][1]);
  #|         ctx.stroke();
  #|         return;
  #|       }
  #|       const dashes = flag ? +flag : 0;
  #|       const run = (vertical, from, to, at, thick) => {
  #|         if (!dashes) {
  #|           if (vertical) ctx.fillRect(at, from, thick, to - from);
  #|           else ctx.fillRect(from, at, to - from, thick);
  #|           return;
  #|         }
  #|         const span = (vertical ? h : w) / dashes;
  #|         const start = vertical ? y0 : x0;
  #|         for (let i = 0; i < dashes; i++) {
  #|           const a = Math.round(start + i * span), b = Math.round(start + (i + 0.6) * span);
  #|           if (vertical) ctx.fillRect(at, a, thick, b - a);
  #|           else ctx.fillRect(a, at, b - a, thick);
  #|         }
  #|       };
  #|       seg.forEach((weight, dir) => {
  #|         if (weight === 0) return;
  #|         const vertical = dir === 0 || dir === 2;
  #|         const thick = weight === 2 ? t * 2 : t;
  #|         const shift = weight === 2 ? Math.floor(t / 2) : 0;
  #|         const offsets = weight === 3 ? [-t, t] : [0];
  #|         offsets.forEach(off => {
  #|           if (vertical) {
  #|             const at = cx - shift + off;
  #|             if (dir === 0) run(true, y0, cy + t + Math.abs(off), at, thick);
  #|             else run(true, cy - Math.abs(off), y1, at, thick);
  #|           } else {
  #|             const at = cy - shift + off;
  #|             if (dir === 3) run(false, x0, cx + t + Math.abs(off), at, thick);
  #|             else run(false, cx - Math.abs(off), x1, at, thick);
  #|           }
  #|         });
  #|       });
  #|     };
  #|     const block = (ctx, code, x0, y0, x1, y1) => {
  #|       const w = x1 - x0, h = y1 - y0;
  #|       const rect = (a, b, c, d) => {
  #|         const l = Math.round(x0 + w * a), r = Math.round(x0 + w * c);
  #|         const tp = Math.round(y0 + h * b), bt = Math.round(y0 + h * d);
  #|         ctx.fillRect(l, tp, r - l, bt - tp);
  #|       };
  #|       if (code === 0x2580) rect(0, 0, 1, 0.5);
  #|       else if (code <= 0x2588) rect(0, 1 - (code - 0x2580) / 8, 1, 1);
  #|       else if (code <= 0x258F) rect(0, 0, (0x2590 - code) / 8, 1);
  #|       else if (code === 0x2590) rect(0.5, 0, 1, 1);
  #|       else if (code <= 0x2593) {
  #|         ctx.globalAlpha = (code - 0x2590) / 4;
  #|         rect(0, 0, 1, 1);
  #|         ctx.globalAlpha = 1;
  #|       } else if (code === 0x2594) rect(0, 0, 1, 1 / 8);
  #|       else if (code === 0x2595) rect(7 / 8, 0, 1, 1);
  #|       else {
  #|         const bits = quads[code - 0x2596];
  #|         if (bits & 1) rect(0, 0, 0.5, 0.5);
  #|         if (bits & 2) rect(0.5, 0, 1, 0.5);
  #|         if (bits & 4) rect(0, 0.5, 0.5, 1);
  #|         if (bits & 8) rect(0.5, 0.5, 1, 1);
  #|       }
  #|     };
  #|     globalThis.__moonetui_glyphs = (ctx, text, x0, y0, x1, y1) => {
  #|       if (text.length !== 1) return false;
  #|       const code = text.charCodeAt(0);
  #|       if (code >= 0x2500 && code <= 0x257F) box(ctx, table[code - 0x2500], x0, y0, x1, y1);
  #|       else if (code >= 0x2580 && code <= 0x259F) block(ctx, code, x0, y0, x1, y1);
  #|       else return false;
  #|       return true;
  #|     };
  #|   }
  #|   if (el.tabIndex < 0) el.tabIndex = 0;
  #|   const s = {
  #|     el, ctx: el.getContext("2d"), px, fg, bg,
  #|     family: "ui-monospace, 'Cascadia Mono', 'JetBrains Mono', Menlo, Consolas, monospace",
  #|     cw: 1, ch: 1, cols: 1, rows: 1, dpr: 1,
  #|     queue: [], report: false, motion: 0, sgr: false, paste: false,
  #|     held: -1, last: "", off: null, cleared: false,
  #|   };
  #|   s.measure = () => {
  #|     s.dpr = globalThis.devicePixelRatio || 1;
  #|     s.ctx.font = s.px + "px " + s.family;
  #|     s.cw = Math.max(1, s.ctx.measureText("M").width);
  #|     s.ch = Math.max(1, Math.round(s.px * 1.25));
  #|     s.cols = Math.max(1, Math.floor(el.clientWidth / s.cw));
  #|     s.rows = Math.max(1, Math.floor(el.clientHeight / s.ch));
  #|     el.width = Math.floor(el.clientWidth * s.dpr);
  #|     el.height = Math.floor(el.clientHeight * s.dpr);
  #|     s.ctx.setTransform(s.dpr, 0, 0, s.dpr, 0, 0);
  #|     s.ctx.textBaseline = "middle";
  #|     s.ctx.fillStyle = s.bg;
  #|     s.ctx.fillRect(0, 0, el.clientWidth, el.clientHeight);
  #|     s.cleared = true;
  #|   };
  #|   s.measure();
  #|   return s;
  #| }

///|
extern "js" fn js_cols(host : Host) -> Int32 =
  #| (s) => s.cols

///|
extern "js" fn js_rows(host : Host) -> Int32 =
  #| (s) => s.rows

///|
extern "js" fn js_cleared(host : Host) -> Bool =
  #| (s) => { const was = s.cleared; s.cleared = false; return was; }

///|
extern "js" fn js_now() -> Int32 =
  #| () => (performance.now() | 0)

///|
extern "js" fn js_modes(
  host : Host,
  report : Bool,
  motion : Int32,
  sgr : Bool,
  paste : Bool,
) -> Unit =
  #| (s, report, motion, sgr, paste) => {
  #|   s.report = report; s.motion = motion; s.sgr = sgr; s.paste = paste;
  #| }

///|
extern "js" fn js_draw(
  host : Host,
  x : Int32,
  y : Int32,
  width : Int32,
  text : String,
  fg : String,
  bg : String,
  flags : Int32,
) -> Unit =
  #| (s, x, y, width, text, fg, bg, flags) => {
  #|   const ctx = s.ctx;
  #|   const x0 = Math.round(x * s.cw), x1 = Math.round((x + width) * s.cw);
  #|   const y0 = y * s.ch, y1 = y0 + s.ch;
  #|   const reverse = flags & 32;
  #|   ctx.fillStyle = bg || (reverse ? s.fg : s.bg);
  #|   ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
  #|   const ink = fg || (reverse ? s.bg : s.fg);
  #|   ctx.globalAlpha = flags & 2 ? 0.55 : 1;
  #|   ctx.fillStyle = ink;
  #|   ctx.strokeStyle = ink;
  #|   if (!globalThis.__moonetui_glyphs(ctx, text, x0, y0, x1, y1) && text !== " ") {
  #|     ctx.font = (flags & 4 ? "italic " : "") + (flags & 1 ? "bold " : "") + s.px + "px " + s.family;
  #|     ctx.fillText(text, x0, y0 + s.ch / 2 + 1);
  #|   }
  #|   const line = Math.max(1, Math.round(s.ch / 16));
  #|   if (flags & 8) ctx.fillRect(x0, y1 - line - 1, x1 - x0, line);
  #|   if (flags & 16) ctx.fillRect(x0, Math.round(y0 + s.ch / 2), x1 - x0, line);
  #|   ctx.globalAlpha = 1;
  #| }

///|
extern "js" fn js_listen(host : Host) -> Unit =
  #| (s) => {
  #|   if (s.off) return;
  #|   const el = s.el;
  #|   const enc = new TextEncoder();
  #|   const ESC = String.fromCharCode(27);
  #|   const send = (text) => { s.queue.push(enc.encode(text)); };
  #|   const fkeys = { F1: "P", F2: "Q", F3: "R", F4: "S", F5: 15, F6: 17, F7: 18, F8: 19,
  #|                   F9: 20, F10: 21, F11: 23, F12: 24 };
  #|   const csi = { ArrowUp: "A", ArrowDown: "B", ArrowRight: "C", ArrowLeft: "D", Home: "H", End: "F" };
  #|   const tilde = { Insert: 2, Delete: 3, PageUp: 5, PageDown: 6 };
  #|   const onKey = (ev) => {
  #|     const k = ev.key;
  #|     const mods = 1 + (ev.shiftKey ? 1 : 0) + (ev.altKey ? 2 : 0) + (ev.ctrlKey ? 4 : 0);
  #|     const m = mods > 1 ? ";" + mods : "";
  #|     if (k in csi) send(ESC + (mods > 1 ? "[1" + m : "[") + csi[k]);
  #|     else if (k in tilde) send(ESC + "[" + tilde[k] + m + "~");
  #|     else if (k in fkeys) {
  #|       const f = fkeys[k];
  #|       if (typeof f === "string") send(ESC + (mods > 1 ? "[1" + m : "O") + f);
  #|       else send(ESC + "[" + f + m + "~");
  #|     } else if (k === "Enter") send("\r");
  #|     else if (k === "Tab") send(ev.shiftKey ? ESC + "[Z" : "\t");
  #|     else if (k === "Backspace") send(String.fromCharCode(127));
  #|     else if (k === "Escape") send(ESC);
  #|     else if ([...k].length === 1) {
  #|       if (ev.metaKey) return;
  #|       if (ev.ctrlKey && !ev.altKey) {
  #|         const c = k.toUpperCase().charCodeAt(0);
  #|         if (c >= 64 && c <= 95) send(String.fromCharCode(c - 64));
  #|         else if (k === " ") send(String.fromCharCode(0));
  #|         else return;
  #|       } else send((ev.altKey ? ESC : "") + k);
  #|     } else return;
  #|     ev.preventDefault();
  #|   };
  #|   const onPaste = (ev) => {
  #|     const text = (ev.clipboardData || globalThis.clipboardData).getData("text");
  #|     send(s.paste ? ESC + "[200~" + text + ESC + "[201~" : text);
  #|     ev.preventDefault();
  #|   };
  #|   const cell = (ev) => {
  #|     const r = el.getBoundingClientRect();
  #|     const x = Math.min(s.cols - 1, Math.max(0, Math.floor((ev.clientX - r.left) / s.cw)));
  #|     const y = Math.min(s.rows - 1, Math.max(0, Math.floor((ev.clientY - r.top) / s.ch)));
  #|     return [x + 1, y + 1];
  #|   };
  #|   const mouse = (ev, button, release) => {
  #|     const [x, y] = cell(ev);
  #|     const b = button + (ev.shiftKey ? 4 : 0) + (ev.altKey ? 8 : 0) + (ev.ctrlKey ? 16 : 0);
  #|     if (s.sgr) send(ESC + "[<" + b + ";" + x + ";" + y + (release ? "m" : "M"));
  #|     else send(ESC + "[M" + String.fromCharCode(32 + (release ? 3 : b), 32 + x, 32 + y));
  #|   };
  #|   const onDown = (ev) => {
  #|     el.focus();
  #|     if (!s.report) return;
  #|     s.held = ev.button;
  #|     mouse(ev, ev.button, false);
  #|     ev.preventDefault();
  #|   };
  #|   const onUp = (ev) => {
  #|     if (!s.report || s.held < 0) return;
  #|     mouse(ev, s.held, true);
  #|     s.held = -1;
  #|   };
  #|   const onMove = (ev) => {
  #|     if (!s.report || s.motion === 0 || (s.motion === 1 && s.held < 0)) return;
  #|     const at = cell(ev).join(";");
  #|     if (at === s.last) return;
  #|     s.last = at;
  #|     mouse(ev, 32 + (s.held < 0 ? 3 : s.held), false);
  #|   };
  #|   const onWheel = (ev) => {
  #|     if (!s.report || document.activeElement !== el || ev.deltaY === 0) return;
  #|     mouse(ev, ev.deltaY < 0 ? 64 : 65, false);
  #|     ev.preventDefault();
  #|   };
  #|   const onMenu = (ev) => { if (s.report) ev.preventDefault(); };
  #|   const watch = new ResizeObserver(() => s.measure());
  #|   el.addEventListener("keydown", onKey);
  #|   el.addEventListener("paste", onPaste);
  #|   el.addEventListener("pointerdown", onDown);
  #|   el.addEventListener("pointerup", onUp);
  #|   el.addEventListener("pointermove", onMove);
  #|   el.addEventListener("wheel", onWheel, { passive: false });
  #|   el.addEventListener("contextmenu", onMenu);
  #|   watch.observe(el);
  #|   s.off = () => {
  #|     el.removeEventListener("keydown", onKey);
  #|     el.removeEventListener("paste", onPaste);
  #|     el.removeEventListener("pointerdown", onDown);
  #|     el.removeEventListener("pointerup", onUp);
  #|     el.removeEventListener("pointermove", onMove);
  #|     el.removeEventListener("wheel", onWheel);
  #|     el.removeEventListener("contextmenu", onMenu);
  #|     watch.disconnect();
  #|   };
  #| }

///|
extern "js" fn js_unlisten(host : Host) -> Unit =
  #| (s) => {
  #|   if (!s.off) return;
  #|   s.off();
  #|   s.off = null;
  #| }

///|
extern "js" fn js_report_resize(
  host : Host,
  cols : Int32,
  rows : Int32,
) -> Unit =
  #| (s, cols, rows) => {
  #|   s.queue.push(new TextEncoder().encode(String.fromCharCode(27) + "[48;" + rows + ";" + cols + "t"));
  #| }

///|
extern "js" fn js_drain(host : Host) -> Bytes =
  #| (s) => {
  #|   if (s.queue.length === 0) return new Uint8Array(0);
  #|   let total = 0;
  #|   for (const c of s.queue) total += c.length;
  #|   const out = new Uint8Array(total);
  #|   let at = 0;
  #|   for (const c of s.queue) { out.set(c, at); at += c.length; }
  #|   s.queue.length = 0;
  #|   return out;
  #| }

///|
/// Call `tick` once per animation frame for as long as it returns true.
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
