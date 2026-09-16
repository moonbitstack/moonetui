// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A progress bar.
///
/// The bar is drawn with eighth-width block characters, so a bar twenty columns
/// wide has a hundred and sixty steps rather than twenty: a bar that only moves
/// once per five percent looks stuck.
pub struct Progress {
  mut value : Int
  mut total : Int
  style : @style.Style
  bar_style : @style.Style
  show_percent : Bool
}

///|
/// A bar at zero out of `total`.
pub fn Progress::new(
  total? : Int = 100,
  style? : @style.Style = @style.Style::new(dim=true),
  bar_style? : @style.Style = @style.Style::new(),
  show_percent? : Bool = true,
) -> Progress {
  {
    value: 0,
    total: if total <= 0 {
      1
    } else {
      total
    },
    style,
    bar_style,
    show_percent,
  }
}

///|
/// Move the bar.
pub fn Progress::set(self : Progress, value : Int) -> Unit {
  self.value = clamp_value(value, 0, self.total)
}

///|
/// Add to the bar.
pub fn Progress::advance(self : Progress, amount : Int) -> Unit {
  self.set(self.value + amount)
}

///|
/// Change what full means, keeping the current value inside it.
pub fn Progress::set_total(self : Progress, total : Int) -> Unit {
  self.total = if total <= 0 { 1 } else { total }
  self.value = clamp_value(self.value, 0, self.total)
}

///|
/// How far along the bar is, from zero to a hundred.
pub fn Progress::percent(self : Progress) -> Int {
  self.value * 100 / self.total
}

///|
pub impl Widget for Progress with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let label = if self.show_percent {
    " " + self.percent().to_string() + "%"
  } else {
    ""
  }
  let bar_width = size.width - @strip.str_cells(label)
  if bar_width <= 0 {
    return align_line(label, size.width, Right, self.style)
  }
  @strip.Strip::join([self.bar(bar_width), @strip.Strip::of(label, self.style)])
}

///|
pub impl Widget for Progress with fn hint(self, size) {
  ignore(self)
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Progress with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Progress with fn focusable(_self) {
  false
}

///|
/// The bar itself, in eighths of a column.
fn Progress::bar(self : Progress, width : Int) -> @strip.Strip {
  let eighths = width * 8 * self.value / self.total
  let full = eighths / 8
  let part = eighths % 8
  let out = StringBuilder()
  for _ in 0..<full {
    out.write_string("█")
  }
  if part > 0 && full < width {
    out.write_string(partials[part])
  }
  let drawn = full + (if part > 0 && full < width { 1 } else { 0 })
  let bar = @strip.Strip::of(out.to_string(), self.bar_style)
  if drawn >= width {
    return bar
  }
  @strip.Strip::join([bar, @strip.Strip::blank(width - drawn, self.style)])
}

///|
/// The partial blocks, indexed by how many eighths are filled.
let partials : Array[String] = [
  "", "▏", "▎", "▍", "▌", "▋", "▊", "▉",
]

///|
fn clamp_value(value : Int, low : Int, high : Int) -> Int {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}
