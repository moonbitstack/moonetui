// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// How far round a meter is: a word on the left, a bar, and the percentage on
/// the right.
pub struct Gauge {
  mut ratio : Double
  mut label : String
  style : @style.Style
  bar_style : @style.Style
  rest_style : @style.Style
}

///|
pub fn Gauge::new(
  ratio~ : Double = 0.0,
  label~ : String = "",
  style~ : @style.Style = @style.default,
  bar_style~ : @style.Style = @style.Style::new(),
  rest_style~ : @style.Style = @style.Style::new(dim=true),
) -> Gauge {
  let gauge : Gauge = { ratio: 0.0, label, style, bar_style, rest_style, }
  gauge.set_ratio(ratio)
  gauge
}

///|
/// How full the meter is, held between nothing and all of it.
pub fn Gauge::set_ratio(self : Gauge, ratio : Double) -> Unit {
  if ratio < 0.0 {
    self.ratio = 0.0
  } else if ratio > 1.0 {
    self.ratio = 1.0
  } else {
    self.ratio = ratio
  }
}

///|
pub fn Gauge::ratio(self : Gauge) -> Double {
  self.ratio
}

///|
pub fn Gauge::percent(self : Gauge) -> Int32 {
  (self.ratio * 100.0 + 0.5).to_int()
}

///|
pub fn Gauge::label(self : Gauge) -> String {
  self.label
}

///|
pub fn Gauge::set_label(self : Gauge, label : String) -> Unit {
  self.label = label
}

///|
pub impl Widget for Gauge with fn render_line(self, row, size) {
  if row != 0 || size.width <= 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let percent = self.percent().to_string() + "%"
  let label = if self.label.length() == 0 {
    ""
  } else {
    clip_to(self.label, at_least_zero(size.width - 8)) + " "
  }
  let used = @strip.str_cells(label) + @strip.str_cells(percent) + 1
  let track = at_least_zero(size.width - used)
  let filled = (track.to_double() * self.ratio + 0.5).to_int()
  let filled = if filled > track { track } else { filled }
  @strip.Strip::join([
    @strip.Strip::of(label, self.style),
    @strip.Strip::of(repeat_glyph("█", filled), self.bar_style),
    @strip.Strip::of(repeat_glyph("░", track - filled), self.rest_style),
    @strip.Strip::of(" ", self.style),
    @strip.Strip::of(percent, self.style),
  ])
}

///|
pub impl Widget for Gauge with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Gauge with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Gauge with fn focusable(_self) {
  false
}

///|
pub extend Gauge with Widget::{focusable, handle, hint, render_line}
