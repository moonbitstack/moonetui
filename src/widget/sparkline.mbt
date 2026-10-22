// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum Summary {
  Maximum
  Minimum
  Mean
  Median
  Latest
} derive(Eq, Debug)

///|
pub struct Sparkline {
  mut data : Array[Double]
  summary : Summary
  min_colour : @style.Colour
  max_colour : @style.Colour
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Sparkline::new(
  data~ : Array[Double] = [],
  summary~ : Summary = Maximum,
  min_colour~ : @style.Colour = @style.Colour::rgb(0, 255, 0),
  max_colour~ : @style.Colour = @style.Colour::rgb(255, 0, 0),
  style~ : @style.Style = @style.Style::new(),
) -> Sparkline {
  { data, summary, min_colour, max_colour, style, }
}

///|
pub fn Sparkline::data(self : Sparkline) -> Array[Double] {
  self.data
}

///|
pub fn Sparkline::set(self : Sparkline, data : Array[Double]) -> Unit {
  self.data = data
}

///|
pub impl Widget for Sparkline with fn render_line(self, row, size) {
  let w = size.width
  let h = size.height
  if w <= 0 {
    return @strip.Strip::empty()
  }
  if self.data.length() == 0 {
    if row == h - 1 {
      return bar_row(w, "▁", self.min_colour, self.style)
    }
    return @strip.Strip::blank(w, self.style)
  }
  if self.data.length() == 1 {
    return bar_row(w, "█", self.max_colour, self.style)
  }
  let segments = 8 * h - 1
  let mut minimum = self.data[0]
  let mut maximum = self.data[0]
  for value in self.data {
    if value < minimum {
      minimum = value
    }
    if value > maximum {
      maximum = value
    }
  }
  let extent = if maximum - minimum == 0.0 { 1.0 } else { maximum - minimum }
  let i = h - 1 - row
  let low = i * 8
  let high = (i + 1) * 8
  let segs : Array[@strip.Seg] = []
  let buckets = self.buckets(w)
  if buckets.length() == 0 {
    return @strip.Strip::blank(w, self.style)
  }
  let step = buckets.length().to_double() / w.to_double()
  for column in 0..<w {
    let bucket = buckets[(step * column.to_double()).to_int()]
    let summary = self.summarize(bucket)
    let ratio = (summary - minimum) / extent
    let index = (ratio * segments.to_double()).to_int()
    let seg : @strip.Seg = if index < low {
      @strip.Seg::new(" ", self.style)
    } else if index >= high {
      @strip.Seg::new(
        "█",
        @style.Style::new(
          fg=self.min_colour.blend(self.max_colour, ratio_hundred(ratio)),
        ),
      )
    } else {
      let bar = bars[index % 8]
      @strip.Seg::new(
        bar,
        @style.Style::new(
          fg=self.min_colour.blend(self.max_colour, ratio_hundred(ratio)),
        ),
      )
    }
    segs.push(seg)
  }
  @strip.Strip::from_segs(segs).pad_to(w, self.style)
}

///|
pub impl Widget for Sparkline with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Sparkline with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Sparkline with fn focusable(_self) {
  false
}

///|
let bars : Array[String] = [
  "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█",
]

///|
fn ratio_hundred(ratio : Double) -> Int32 {
  let percent = (ratio * 100.0).to_int()
  if percent < 0 {
    0
  } else if percent > 100 {
    100
  } else {
    percent
  }
}

///|
fn bar_row(
  width : Int32,
  glyph : String,
  colour : @style.Colour,
  style : @style.Style,
) -> @strip.Strip {
  let out = StringBuilder()
  for _ in 0..<width {
    out.write_string(glyph)
  }
  @strip.Strip::of(out.to_string(), @style.Style::new(fg=colour)).apply(style)
}

///|
fn Sparkline::buckets(self : Sparkline, count : Int32) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  let n = self.data.length().to_double()
  let step = n / count.to_double()
  for bucket in 0..<count {
    let start = (step * bucket.to_double()).to_int()
    let end = (step * (bucket.to_double() + 1.0)).to_int()
    if end > start {
      let part : Array[Double] = []
      for i in start..<end {
        part.push(self.data[i])
      }
      out.push(part)
    }
  }
  out
}

///|
fn Sparkline::summarize(self : Sparkline, bucket : Array[Double]) -> Double {
  match self.summary {
    Maximum => {
      let mut top = bucket[0]
      for value in bucket {
        if value > top {
          top = value
        }
      }
      top
    }
    Minimum => {
      let mut low = bucket[0]
      for value in bucket {
        if value < low {
          low = value
        }
      }
      low
    }
    Mean => {
      let mut total = 0.0
      for value in bucket {
        total = total + value
      }
      total / bucket.length().to_double()
    }
    Median => {
      let sorted : Array[Double] = []
      for value in bucket {
        sorted.push(value)
      }
      sorted.sort()
      let n = sorted.length()
      if n % 2 == 1 {
        sorted[n / 2]
      } else {
        (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
      }
    }
    Latest => bucket[bucket.length() - 1]
  }
}

///|
pub extend Summary with Debug::{to_repr}

///|
pub extend Summary with Eq::{not_equal, equal}

///|
pub extend Sparkline with Debug::{to_repr}

///|
pub extend Sparkline with Eq::{not_equal, equal}

///|
pub extend Sparkline with Widget::{focusable, handle, hint, render_line}
