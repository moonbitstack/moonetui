// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One column of a bar chart: what it is called, how tall it stands, and the
/// colour it is drawn in when it has one of its own.
pub(all) struct Bar {
  label : String
  value : Double
  style : @style.Style?
} derive(Eq, Debug)

///|
pub fn Bar::new(
  label : String,
  value~ : Double = 0.0,
  style~ : @style.Style? = None,
) -> Bar {
  { label, value, style, }
}

///|
/// Columns of heights, named along the bottom.
///
/// The tallest bar fills the plot unless a `max` is given, which is how
/// several charts are held to one scale.
pub struct BarChart {
  mut bars : Array[Bar]
  mut max : Double?
  gap : Int32
  values : Bool
  style : @style.Style
  bar_style : @style.Style
  label_style : @style.Style
}

///|
pub fn BarChart::new(
  bars~ : Array[Bar] = [],
  max~ : Double? = None,
  gap~ : Int32 = 1,
  values~ : Bool = false,
  style~ : @style.Style = @style.default,
  bar_style~ : @style.Style = @style.Style::new(),
  label_style~ : @style.Style = @style.Style::new(dim=true),
) -> BarChart {
  { bars, max, gap, values, style, bar_style, label_style, }
}

///|
pub fn BarChart::set_bars(self : BarChart, bars : Array[Bar]) -> Unit {
  self.bars = bars
}

///|
/// Hold every bar to this scale, or let the tallest one set it.
pub fn BarChart::set_max(self : BarChart, max : Double?) -> Unit {
  self.max = max
}

///|
pub fn BarChart::bars(self : BarChart) -> Array[Bar] {
  self.bars
}

///|
/// What the tallest column is measured against.
pub fn BarChart::scale(self : BarChart) -> Double {
  match self.max {
    Some(given) => if given > 0.0 { given } else { 1.0 }
    None => {
      let mut tallest = 0.0
      for bar in self.bars {
        if bar.value > tallest {
          tallest = bar.value
        }
      }
      if tallest > 0.0 {
        tallest
      } else {
        1.0
      }
    }
  }
}

///|
pub impl Widget for BarChart with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 {
    return @strip.Strip::empty()
  }
  let foot = if self.bars.length() > 0 { 1 } else { 0 }
  if self.values && self.bars.length() > 0 && row == 0 && size.height > 2 {
    return self.value_line(size)
  }
  let plot_h = at_least_zero(
    size.height - foot - (if self.values { 1 } else { 0 }),
  )
  let top = if self.values { 1 } else { 0 }
  let at = row - top
  if at >= plot_h || plot_h <= 0 {
    let foot_at = at - plot_h
    if foot_at >= 0 && foot < 1 {
      return @strip.Strip::blank(size.width, self.style)
    }
    return self.label_line(size)
  }
  let scale = self.scale()
  let segs : Array[@strip.Strip] = []
  let columns = self.columns(size.width)
  for i in 0..<self.bars.length() {
    let (start, width) = columns[i]
    let want = (self.bars[i].value / scale * plot_h.to_double() + 0.5).to_int()
    let filled = if at >= plot_h - want { true } else { false }
    let ink = match self.bars[i].style {
      Some(own) => own
      None => self.bar_style
    }
    if filled {
      segs.push(@strip.Strip::of(repeat_glyph("█", width), ink))
    } else {
      segs.push(@strip.Strip::blank(width, self.style))
    }
    if i + 1 < self.bars.length() {
      segs.push(@strip.Strip::blank(self.gap, self.style))
    }
    ignore(start)
  }
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
pub impl Widget for BarChart with fn hint(_self, size) {
  @geom.Size::new(size.width, size.height)
}

///|
pub impl Widget for BarChart with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for BarChart with fn focusable(_self) {
  false
}

///|
/// Where each column starts and how wide it is, the width shared out with
/// the gaps between taken off first.
fn BarChart::columns(self : BarChart, width : Int32) -> Array[(Int32, Int32)] {
  let count = self.bars.length()
  let out : Array[(Int32, Int32)] = []
  if count == 0 {
    return out
  }
  let gaps = self.gap * (count - 1)
  let room = at_least_zero(width - gaps)
  let share = if room / count < 1 { 1 } else { room / count }
  let mut at = 0
  for i in 0..<count {
    let span = if i == count - 1 {
      let left = at_least_zero(width - at)
      if left < 1 {
        1
      } else {
        left
      }
    } else {
      share
    }
    out.push((at, span))
    at = at + span + self.gap
  }
  out
}

///|
fn BarChart::label_line(self : BarChart, size : @geom.Size) -> @strip.Strip {
  let columns = self.columns(size.width)
  let segs : Array[@strip.Strip] = []
  for i in 0..<self.bars.length() {
    let (_, width) = columns[i]
    segs.push(
      @strip.Strip::of(clip_to(self.bars[i].label, width), self.label_style).pad_to(
        width,
        self.style,
      ),
    )
    if i + 1 < self.bars.length() {
      segs.push(@strip.Strip::blank(self.gap, self.style))
    }
  }
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
fn BarChart::value_line(self : BarChart, size : @geom.Size) -> @strip.Strip {
  let columns = self.columns(size.width)
  let segs : Array[@strip.Strip] = []
  for i in 0..<self.bars.length() {
    let (_, width) = columns[i]
    segs.push(
      align_line(
        trim_double(self.bars[i].value),
        width,
        Centre,
        self.label_style,
      ).pad_to(width, self.style),
    )
    if i + 1 < self.bars.length() {
      segs.push(@strip.Strip::blank(self.gap, self.style))
    }
  }
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
pub extend Bar with Debug::{to_repr}

///|
pub extend Bar with Eq::{not_equal, equal}

///|
pub extend BarChart with Widget::{focusable, handle, hint, render_line}
