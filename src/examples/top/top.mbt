// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// Four regions on one page: cores on the left, memory and the network on the
// right, the busiest processes under them. The numbers are a fixed function of
// the tick, so the page is the same page twice and a frame test can read it.

///|
pub struct Monitor {
  mut tick : Int32
  mut held : Bool
}

///|
pub fn Monitor::new() -> Monitor {
  { tick: 0, held: false, }
}

///|
pub fn Monitor::step(self : Monitor) -> Unit {
  if !self.held {
    self.tick = self.tick + 1
  }
}

///|
pub fn Monitor::toggle(self : Monitor) -> Unit {
  self.held = !self.held
}

///|
pub fn Monitor::tick(self : Monitor) -> Int32 {
  self.tick
}

///|
/// A core's load: a wave with a slow drift, different for every core.
fn core_load(core : Int32, tick : Int32) -> Int32 {
  let phase = (tick + core * 7) % 40
  let wave = if phase < 20 { phase * 3 } else { (40 - phase) * 3 }
  let base = 20 + core * 6
  let value = base + wave / 2
  if value > 100 {
    100
  } else {
    value
  }
}

///|
fn memory(tick : Int32) -> Int32 {
  48 + tick % 9
}

///|
fn swap(tick : Int32) -> Int32 {
  12 + tick % 5
}

///|
/// One reading of the network, in kilobytes a second, 0 to 8 for the chart.
fn net(tick : Int32, offset : Int32) -> Int32 {
  // A chart drawn from before the first tick reads negative indices unless the
  // remainder is wrapped here rather than at the glyph.
  let raw = (tick + offset) % 9
  if raw < 0 {
    raw + 9
  } else {
    raw
  }
}

///|
let label_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let value_style : @style.Style = @style.Style::new(fg=@theme.ink, bold=true)

///|
let cpu_style : @style.Style = @style.Style::new(fg=@theme.accent)

///|
let mem_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let swp_style : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let net_style : @style.Style = @style.Style::new(fg=@theme.accent_alt)

///|
let hot_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
fn repeat(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
fn bars(percent : Int32, width : Int32) -> String {
  let filled = width * percent / 100
  repeat("█", filled) + repeat("░", width - filled)
}

///|
/// The shades of a small chart, one per reading.
let shades : Array[String] = [
  "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█",
]

///|
impl @widget.Widget for Monitor with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 40 {
    return @strip.Strip::blank(width, @style.default)
  }
  let left_width = width * 44 / 100
  let right_width = width - left_width - 2
  if row == 0 {
    return @strip.Strip::join([
      @strip.Strip::of(" top", @style.Style::new(fg=@theme.accent, bold=true)),
      @strip.Strip::of("  load ", label_style),
      @strip.Strip::of("0.42 0.31 0.28", value_style),
      @strip.Strip::of("   uptime ", label_style),
      @strip.Strip::of((self.tick + 3).to_string() + "s", value_style),
      @strip.Strip::of(
        if self.held {
          "   held"
        } else {
          "   live"
        },
        label_style,
      ),
    ])
  }
  if row == height - 1 {
    return @strip.Strip::of(" space holds · esc quits", label_style)
  }
  let body = row - 1
  // The cores, one bar each, down the left.
  if body < 8 {
    let load = core_load(body, self.tick)
    let left = @strip.Strip::join([
      @strip.Strip::of(" cpu" + body.to_string() + " ", label_style),
      @strip.Strip::of(bars(load, left_width - 12), cpu_style),
      @strip.Strip::of(" " + load.to_string() + "%", label_style),
    ])
    // The right side puts memory, swap and the two network charts beside them.
    let right = match body {
      0 =>
        @strip.Strip::join([
          @strip.Strip::of(" mem ", label_style),
          @strip.Strip::of(bars(memory(self.tick), right_width - 8), mem_style),
          @strip.Strip::of(
            " " + memory(self.tick).to_string() + "%",
            label_style,
          ),
        ])
      1 =>
        @strip.Strip::join([
          @strip.Strip::of(" swp ", label_style),
          @strip.Strip::of(bars(swap(self.tick), right_width - 8), swp_style),
          @strip.Strip::of(" " + swap(self.tick).to_string() + "%", label_style),
        ])
      2 =>
        @strip.Strip::join([
          @strip.Strip::of(" net up ", label_style),
          @strip.Strip::of(self.chart(right_width - 12, 0), net_style),
        ])
      3 =>
        @strip.Strip::join([
          @strip.Strip::of(" net down ", label_style),
          @strip.Strip::of(self.chart(right_width - 14, 5), net_style),
        ])
      _ => @strip.Strip::blank(right_width, label_style)
    }
    return @strip.Strip::join([
      left,
      @strip.Strip::blank(2, @style.Style::new()),
      right,
    ])
  }
  // The processes: what is busy, how busy, and how much it holds.
  let table_top = 8
  if body == table_top + 1 {
    return @strip.Strip::join([
      @strip.Strip::of(" pid    name            cpu   mem", label_style),
    ])
  }
  let names : Array[String] = [
    "moonc", "node", "postgres", "redis", "chrome", "kernel_task",
  ]
  let index = body - table_top - 2
  if index >= 0 && index < names.length() {
    let load = core_load(index * 3, self.tick)
    let mem = memory(self.tick) - index * 4
    let style = if load > 70 { hot_style } else { value_style }
    return @strip.Strip::join([
      @strip.Strip::of(
        " " + (1200 + index * 17).to_string() + "   ",
        label_style,
      ),
      @strip.Strip::of(pad(names[index], 15), value_style),
      @strip.Strip::of(pad(load.to_string() + "%", 5), style),
      @strip.Strip::of(pad(mem.to_string() + "%", 5), label_style),
      @strip.Strip::of(
        bars(load, 20),
        if load > 70 {
          hot_style
        } else {
          cpu_style
        },
      ),
    ])
  }
  @strip.Strip::blank(width, @style.default)
}

///|
fn pad(text : String, width : Int32) -> String {
  let pad = width - @strip.str_cells(text)
  if pad > 0 {
    text + repeat(" ", pad)
  } else {
    text
  }
}

///|
/// A sparkline of the network over the last `width` readings.
fn Monitor::chart(self : Monitor, width : Int32, offset : Int32) -> String {
  let out = StringBuilder()
  for x in 0..<width {
    let reading = net(self.tick - width + x, offset)
    let level = if reading > 7 { 7 } else { reading }
    out.write_string(shades[level])
  }
  out.to_string()
}

///|
impl @widget.Widget for Monitor with fn hint(_self, size) {
  @geom.Size::new(size.width, 18)
}

///|
impl @widget.Widget for Monitor with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Monitor with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Char(32) => {
          self.toggle()
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
pub struct Screen {
  root : @app.Node
  monitor : Monitor
}

///|
pub fn Screen::new() -> Screen {
  let monitor = Monitor::new()
  let root = @app.column(0, [
    @app.leaf(1, monitor, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, monitor, }
}
