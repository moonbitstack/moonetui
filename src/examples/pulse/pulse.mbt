// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A rolling window of samples drawn as a spectrum, with the latest reading
/// under it. The samples come from a fixed table, so a screenshot is the same
/// screenshot every run.
pub struct Pulse {
  cols : Int32
  rows : Int32
  samples : Array[Int32]
  mut at : Int32
  mut paused : Bool
}

///|
/// The shape the dashboard follows: a wave, a burst, a quiet stretch, then a
/// climb. Eight steps per phase, two hundred and fifty-six samples in all.
fn shape(at : Int32) -> Int32 {
  let step = at % 64
  if step < 16 {
    // A wave.
    let value = 8 + step % 8
    if value > 10 {
      10
    } else {
      value
    }
  } else if step < 32 {
    // A burst.
    10
  } else if step < 48 {
    // A quiet stretch.
    2
  } else {
    // A climb.
    3 + (step - 48) / 2
  }
}

///|
pub fn Pulse::new(cols~ : Int32 = 60, rows~ : Int32 = 8) -> Pulse {
  let pulse : Pulse = { cols, rows, samples: [], at: 0, paused: false, }
  // A full window on the first frame: the dashboard opens already alive.
  for _ in 0..<cols {
    pulse.tick()
  }
  pulse
}

///|
/// One reading arrives. The window slides: the oldest sample leaves.
pub fn Pulse::tick(self : Pulse) -> Unit {
  if self.paused {
    return
  }
  let value = shape(self.at)
  self.at = self.at + 1
  self.samples.push(value)
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
let peak_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let high_style : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let low_style : @style.Style = @style.Style::new(fg=@theme.accent)

///|
let floor_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn sample_style(value : Int32) -> @style.Style {
  if value >= 9 {
    return peak_style
  }
  if value >= 6 {
    return high_style
  }
  if value >= 3 {
    return low_style
  }
  floor_style
}

///|
impl @widget.Widget for Pulse with fn render_line(self, row, size) {
  if row == self.rows {
    let rate = self.latest() * 12
    let word = if self.paused { "held" } else { "live" }
    return @strip.Strip::of(
      "rate " + rate.to_string() + "/s · " + word + " · space holds",
      @style.Style::new(fg=@theme.muted),
    )
  }
  if row < 0 || row > self.rows {
    return @strip.Strip::blank(size.width, @style.default)
  }
  let height = self.rows - row
  let parts : Array[@strip.Strip] = []
  let offset = self.samples.length() - self.cols
  for x in 0..<self.cols {
    let index = x + offset
    let value = if index >= 0 && index < self.samples.length() {
      self.samples[index]
    } else {
      0
    }
    if value >= height {
      parts.push(@strip.Strip::of("█", sample_style(value)))
    } else {
      parts.push(@strip.Strip::of(" ", floor_style))
    }
  }
  @strip.Strip::join(parts)
}

///|
impl @widget.Widget for Pulse with fn hint(self, _size) {
  @geom.Size::new(self.cols, self.rows + 1)
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
  let head = @theme.header("pulse", note="a load seen through a window")
  let foot = @theme.footer([("space", "hold"), ("esc", "quit")])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.leaf(2, pulse, box=@layout.Box::new(extent=Cells(pulse.rows + 1)), classes=[
      "framed",
    ]),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, pulse, }
}
