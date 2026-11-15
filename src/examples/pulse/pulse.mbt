// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A dashboard, not a demo: the numbers a reader watches, the chart they watch
// them on, the gauges beside it, and the table underneath. It owns the whole
// window — no frame, no key bar across the top — because a dashboard is a page,
// not a widget in a box.

///|
pub struct Pulse {
  cols : Int32
  rows : Int32
  samples : Array[Int32]
  mut at : Int32
  mut paused : Bool
}

///|
/// One reading of requests per second: a slow swell with a burst on top, and a
/// dip every sixteen samples. Twenty is subtracted so the chart has a floor.
fn reading(at : Int32) -> Int32 {
  let phase = at % 32
  let swell = if phase < 16 { phase * 6 } else { (32 - phase) * 6 }
  let dip = if at % 16 == 0 { 90 } else { 0 }
  let burst = if at % 47 < 3 { 140 } else { 0 }
  240 + swell + burst - dip
}

///|
pub fn Pulse::new(cols~ : Int32 = 78, rows~ : Int32 = 20) -> Pulse {
  let pulse : Pulse = { cols, rows, samples: [], at: 0, paused: false, }
  // A window already on the first frame: a dashboard opens on data.
  for _ in 0..<cols {
    pulse.tick()
  }
  pulse
}

///|
pub fn Pulse::tick(self : Pulse) -> Unit {
  if self.paused {
    return
  }
  self.samples.push(reading(self.at))
  self.at = self.at + 1
  if self.samples.length() > self.cols {
    ignore(self.samples.remove(0))
  }
}

///|
pub fn Pulse::latest(self : Pulse) -> Int32 {
  if self.samples.length() == 0 {
    return 0
  }
  self.samples[self.samples.length() - 1]
}

///|
pub fn Pulse::toggle(self : Pulse) -> Unit {
  self.paused = !self.paused
}

///|
fn Pulse::top(self : Pulse) -> Int32 {
  let mut most = 1
  for value in self.samples {
    if value > most {
      most = value
    }
  }
  most
}

///|
fn Pulse::average(self : Pulse) -> Int32 {
  if self.samples.length() == 0 {
    return 0
  }
  let mut total = 0
  for value in self.samples {
    total = total + value
  }
  total / self.samples.length()
}

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let faint : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let line_style : @style.Style = @style.Style::new(fg=@theme.accent)

///|
let area_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let good_style : @style.Style = @style.Style::new(fg=@theme.good, bold=true)

///|
let warn_style : @style.Style = @style.Style::new(fg=@theme.warn, bold=true)

///|
let bad_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
fn repeat(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
/// A number with its thousands apart: 1,284 rather than 1284.
fn grouped(value : Int32) -> String {
  if value < 1000 {
    return value.to_string()
  }
  let high = value / 1000
  let low = value % 1000
  let tail = low.to_string()
  high.to_string() + "," + repeat("0", 3 - tail.length()) + tail
}

///|
/// A horizontal gauge: filled cells, empty cells, and the reading.
fn gauge(
  label : String,
  percent : Int32,
  width : Int32,
  style : @style.Style,
) -> @strip.Strip {
  let filled = width * percent / 100
  let parts : Array[@strip.Strip] = [
    @strip.Strip::of(label, faint),
    @strip.Strip::of(" ", faint),
    @strip.Strip::of(repeat("█", filled), style),
    @strip.Strip::of(repeat("░", width - filled), area_style),
    @strip.Strip::of(" " + percent.to_string() + "%", ink),
  ]
  @strip.Strip::join(parts)
}

///|
/// The four numbers a reader looks at first: what is arriving, how slow it is,
/// how much of it fails, and how many are connected. The arrow is the trend
/// against the window's average.
fn Pulse::headline(self : Pulse) -> @strip.Strip {
  let now = self.latest()
  let mean = self.average()
  let up = now >= mean
  let trend = if up { "▲" } else { "▼" }
  let trend_style = if up { good_style } else { bad_style }
  let parts : Array[@strip.Strip] = []
  let cell = fn(
    label : String,
    value : String,
    tail : String,
    style : @style.Style,
  ) {
    parts.push(@strip.Strip::of(" " + label + " ", faint))
    parts.push(@strip.Strip::of(value, @style.Style::new(bold=true)))
    if tail != "" {
      parts.push(@strip.Strip::of(" " + tail + " ", style))
    }
    parts.push(@strip.Strip::of("   ", faint))
  }
  cell("req/s", grouped(now), trend, trend_style)
  cell("p99", "42ms", "▼ 3%", good_style)
  cell("errors", "0.4%", "▲ 0.1", warn_style)
  cell("live", "128", "", faint)
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Pulse with fn render_line(self, row, size) {
  let width = size.width
  if width < 24 {
    return @strip.Strip::blank(width, @style.default)
  }
  // The page: one headline, one chart, two gauges, a table, a status line.
  let chart_top = 2
  let chart_rows = 7
  let gauge_top = chart_top + chart_rows + 1
  let table_top = gauge_top + 3
  if row == 0 {
    return self.headline()
  }
  if row >= chart_top && row < chart_top + chart_rows {
    return self.chart_row(row - chart_top, chart_rows, width)
  }
  if row == gauge_top {
    return gauge("cpu ", 68, width - 18, good_style)
  }
  if row == gauge_top + 1 {
    return gauge("mem ", 41, width - 18, warn_style)
  }
  if row == table_top {
    return @strip.Strip::join([
      @strip.Strip::of(" top endpoints", faint),
      @strip.Strip::of(repeat(" ", width - 40), faint),
      @strip.Strip::of("reqs   p99  ", faint),
    ])
  }
  if row > table_top && row < table_top + 5 {
    return self.table_row(row - table_top - 1, width)
  }
  if row == self.rows - 1 {
    let state = if self.paused { "held" } else { "live" }
    return @strip.Strip::join([
      @strip.Strip::of(
        " window " +
        self.samples.length().to_string() +
        "s · top " +
        grouped(self.top()) +
        " · avg " +
        grouped(self.average()) +
        " · " +
        state +
        " · space holds · esc quits",
        faint,
      ),
    ])
  }
  @strip.Strip::blank(width, @style.default)
}

///|
fn Pulse::chart_row(
  self : Pulse,
  offset : Int32,
  total : Int32,
  width : Int32,
) -> @strip.Strip {
  // A y axis on the left, then the window: the line where the reading is, a
  // shade under it so the shape reads at a glance.
  let axis = 6
  let span = width - axis - 1
  let most = self.top()
  let rows = total
  let level = rows - 1 - offset
  let label = if offset == 0 {
    grouped(most)
  } else if offset == rows / 2 {
    grouped(most / 2)
  } else if offset == rows - 1 {
    "0"
  } else {
    ""
  }
  let pad = 5 - label.length()
  let parts : Array[@strip.Strip] = [
    @strip.Strip::of(repeat(" ", if pad > 0 { pad } else { 0 }) + label, faint),
    @strip.Strip::of(if offset == rows - 1 { "└" } else { "┤" }, faint),
  ]
  let offset_in_window = if self.samples.length() > span {
    self.samples.length() - span
  } else {
    0
  }
  for x in 0..<span {
    let index = x + offset_in_window
    let value = if index < self.samples.length() {
      self.samples[index]
    } else {
      0
    }
    let y = if most == 0 { 0 } else { value * (rows - 1) / most }
    if y == level {
      parts.push(@strip.Strip::of("─", line_style))
    } else if y < level {
      parts.push(@strip.Strip::of("░", area_style))
    } else {
      parts.push(@strip.Strip::of(" ", faint))
    }
  }
  @strip.Strip::join(parts)
}

///|
fn Pulse::table_row(
  _self : Pulse,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let names : Array[String] = [
    "/api/orders", "/api/search", "/api/users", "/api/checkout", "/api/health",
  ]
  let counts : Array[Int32] = [482, 361, 244, 130, 67]
  let times : Array[String] = ["38ms", "52ms", "12ms", "96ms", "3ms"]
  if index < 0 || index >= names.length() {
    return @strip.Strip::blank(width, @style.default)
  }
  let bar_width = width - 42
  let share = counts[index] * bar_width / 482
  let style = if times[index] == "96ms" { warn_style } else { line_style }
  @strip.Strip::join([
    @strip.Strip::of(" " + names[index], ink),
    @strip.Strip::of(repeat(" ", 20 - names[index].length()), faint),
    @strip.Strip::of(repeat("█", share), style),
    @strip.Strip::of(repeat("░", bar_width - share), area_style),
    @strip.Strip::of("  " + counts[index].to_string(), ink),
    @strip.Strip::of("  " + times[index], faint),
  ])
}

///|
impl @widget.Widget for Pulse with fn hint(self, size) {
  @geom.Size::new(
    if size.width > 0 {
      size.width
    } else {
      self.cols
    },
    self.rows,
  )
}

///|
impl @widget.Widget for Pulse with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Pulse with fn handle(self, ctx, msg) {
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
  pulse : Pulse
}

///|
pub fn Screen::new() -> Screen {
  let pulse = Pulse::new()
  // No frame, no header: the dashboard draws its own page, edge to edge.
  let root = @app.column(0, [
    @app.leaf(1, pulse, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, pulse, }
}
