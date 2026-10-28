// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The stretch of values an axis covers. A `high` no greater than `low` is
/// taken from the data instead.
pub(all) struct Bounds {
  low : Double
  high : Double
} derive(Eq, Debug)

///|
pub fn Bounds::new(low~ : Double = 0.0, high~ : Double = 0.0) -> Bounds {
  { low, high, }
}

///|
pub fn Bounds::span(self : Bounds) -> Double {
  if self.high > self.low {
    self.high - self.low
  } else {
    0.0
  }
}

///|
/// One side of a plot: the words along it and the stretch they cover.
pub(all) struct Axis {
  title : String
  labels : Array[String]
  bounds : Bounds
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Axis::new(
  labels~ : Array[String] = [],
  bounds~ : Bounds = Bounds::new(),
  title~ : String = "",
  style~ : @style.Style = @style.Style::new(dim=true),
) -> Axis {
  { title, labels, bounds, style, }
}

///|
/// How a series is drawn: joined from point to point, or as the points
/// themselves.
pub(all) enum GraphKind {
  Line
  Scatter
} derive(Eq, Debug)

///|
pub fn GraphKind::marker(self : GraphKind) -> String {
  match self {
    Line => "•"
    Scatter => "▪"
  }
}

///|
/// One series of points, named and drawn in its own colour.
pub(all) struct Dataset {
  name : String
  kind : GraphKind
  points : Array[(Double, Double)]
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Dataset::new(
  name : String,
  points : Array[(Double, Double)],
  kind~ : GraphKind = Line,
  style~ : @style.Style = @style.Style::new(),
) -> Dataset {
  { name, kind, points, style, }
}

///|
/// Points on two axes, one or more series of them, and a legend: a plot that
/// fits whatever box it is given.
///
/// A series drawn as a line is joined across the columns between its points;
/// one drawn as scatter keeps to the points themselves.
pub struct Chart {
  mut datasets : Array[Dataset]
  mut x : Axis
  mut y : Axis
  legend : Bool
  style : @style.Style
  axis_style : @style.Style
  label_style : @style.Style
}

///|
pub fn Chart::new(
  datasets~ : Array[Dataset] = [],
  x~ : Axis = Axis::new(),
  y~ : Axis = Axis::new(),
  legend~ : Bool = true,
  style~ : @style.Style = @style.default,
  axis_style~ : @style.Style = @style.default,
  label_style~ : @style.Style = @style.Style::new(dim=true),
) -> Chart {
  { datasets, x, y, legend, style, axis_style, label_style, }
}

///|
pub fn Chart::set_datasets(self : Chart, datasets : Array[Dataset]) -> Unit {
  self.datasets = datasets
}

///|
pub fn Chart::set_x(self : Chart, axis : Axis) -> Unit {
  self.x = axis
}

///|
pub fn Chart::set_y(self : Chart, axis : Axis) -> Unit {
  self.y = axis
}

///|
pub fn Chart::datasets(self : Chart) -> Array[Dataset] {
  self.datasets
}

///|
/// The stretch the vertical axis covers: what it was given, or what the data
/// spans with a little room above.
pub fn Chart::bounds(self : Chart) -> Bounds {
  if self.y.bounds.span() > 0.0 {
    return self.y.bounds
  }
  let mut low = 0.0
  let mut high = 0.0
  let mut seen = false
  for dataset in self.datasets {
    for point in dataset.points {
      let value = point.1
      if !seen || value < low {
        low = value
      }
      if !seen || value > high {
        high = value
      }
      seen = true
    }
  }
  if !seen {
    return Bounds::new(low=0.0, high=1.0)
  }
  if high <= low {
    high = low + 1.0
  }
  let pad = (high - low) * 0.1
  Bounds::new(low~, high=high + pad)
}

///|
pub impl Widget for Chart with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 {
    return @strip.Strip::empty()
  }
  let legend_rows = if self.legend && self.datasets.length() > 0 {
    1
  } else {
    0
  }
  let gutter = self.gutter()
  let plot_h = at_least_zero(size.height - legend_rows - self.x_foot())
  let plot_w = at_least_zero(size.width - gutter)
  if row < legend_rows {
    return self.legend_line(size)
  }
  let at = row - legend_rows
  if at >= plot_h {
    return self.foot_line(at - plot_h, plot_w, size, gutter~)
  }
  let plot = self.plot(plot_w, plot_h)
  let segs : Array[@strip.Strip] = [@strip.Strip::blank(gutter, self.style)]
  if gutter > 0 && (at == 0 || at == plot_h - 1 || at == plot_h / 2) {
    segs.clear()
    let mark = self.y_mark(at, plot_h)
    segs.push(
      @strip.Strip::of(
        clip_to(mark, at_least_zero(gutter - 1)) + " ",
        self.label_style,
      ),
    )
  }
  for x in 0..<plot_w {
    match plot[at][x] {
      None => segs.push(@strip.Strip::of(" ", self.style))
      Some((glyph, mark_style)) =>
        segs.push(@strip.Strip::of(glyph, mark_style))
    }
  }
  @strip.Strip::join(segs)
}

///|
pub impl Widget for Chart with fn hint(_self, size) {
  @geom.Size::new(size.width, size.height)
}

///|
pub impl Widget for Chart with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Chart with fn focusable(_self) {
  false
}

///|
/// The whole plot as glyphs and colours, one cell at a time.
fn Chart::plot(
  self : Chart,
  width : Int32,
  height : Int32,
) -> Array[Array[(String, @style.Style)?]] {
  let rows : Array[Array[(String, @style.Style)?]] = []
  for _ in 0..<height {
    let line : Array[(String, @style.Style)?] = []
    for _ in 0..<width {
      line.push(None)
    }
    rows.push(line)
  }
  if width <= 0 || height <= 0 {
    return rows
  }
  let bounds = self.bounds()
  for dataset in self.datasets {
    let count = dataset.points.length()
    for i in 0..<count {
      let (at_x, at_y) = dataset.points[i]
      let column = self.column_of(at_x, width)
      let row = self.row_of(at_y, bounds, height)
      self.mark(rows, row, column, dataset.kind.marker(), dataset.style)
      if dataset.kind == Scatter || i + 1 >= count {
        continue
      }
      let (next_x, next_y) = dataset.points[i + 1]
      let to_column = self.column_of(next_x, width)
      if to_column == column {
        continue
      }
      let step = if to_column > column { 1 } else { -1 }
      let mut across = column + step
      while across != to_column {
        let part = (across - column).to_double() /
          (to_column - column).to_double()
        let value = at_y + (next_y - at_y) * part
        let line_row = self.row_of(value, bounds, height)
        self.mark(rows, line_row, across, "·", dataset.style)
        across = across + step
      }
    }
  }
  rows
}

///|
fn Chart::mark(
  _self : Chart,
  rows : Array[Array[(String, @style.Style)?]],
  row : Int32,
  column : Int32,
  glyph : String,
  mark_style : @style.Style,
) -> Unit {
  if row < 0 || row >= rows.length() {
    return
  }
  if column < 0 || column >= rows[row].length() {
    return
  }
  rows[row][column] = Some((glyph, mark_style))
}

///|
/// Which column a value on the horizontal axis falls in. With no bounds of
/// its own, the points are spread evenly across.
fn Chart::column_of(self : Chart, value : Double, width : Int32) -> Int32 {
  if width <= 1 {
    return 0
  }
  let span = self.x.bounds.span()
  if span <= 0.0 {
    return 0
  }
  let part = (value - self.x.bounds.low) / span
  let at = (part * (width - 1).to_double()).to_int()
  if at < 0 {
    0
  } else if at > width - 1 {
    width - 1
  } else {
    at
  }
}

///|
/// Which row a value on the vertical axis falls in, counting from the top.
fn Chart::row_of(
  _self : Chart,
  value : Double,
  bounds : Bounds,
  height : Int32,
) -> Int32 {
  if height <= 1 {
    return 0
  }
  let span = bounds.span()
  let part = if span > 0.0 { (bounds.high - value) / span } else { 0.0 }
  let at = (part * (height - 1).to_double()).to_int()
  if at < 0 {
    0
  } else if at > height - 1 {
    height - 1
  } else {
    at
  }
}

///|
/// The columns the vertical axis keeps for its own words.
fn Chart::gutter(self : Chart) -> Int32 {
  let mut widest = 0
  for label in self.y.labels {
    let cells = @strip.str_cells(label)
    if cells > widest {
      widest = cells
    }
  }
  for index in [0, 1, 2] {
    let cells = @strip.str_cells(self.y_label(index, 3))
    if cells > widest {
      widest = cells
    }
  }
  if y_title_of(self.y).length() > 0 {
    widest = widest + 1
  }
  if widest == 0 {
    0
  } else {
    widest + 1
  }
}

///|
/// How many rows the horizontal axis takes under the plot: its labels, and
/// its title if it has one.
fn Chart::x_foot(self : Chart) -> Int32 {
  let mut rows = if self.x.labels.length() > 0 { 1 } else { 0 }
  if self.x.title.length() > 0 {
    rows = rows + 1
  }
  rows
}

///|
fn Chart::y_mark(self : Chart, at : Int32, height : Int32) -> String {
  let labels = self.y.labels
  if labels.length() == 0 {
    return self.y_label(at, height)
  }
  let place = if height > 1 {
    (labels.length() - 1) * (height - 1 - at) / (height - 1)
  } else {
    0
  }
  labels[constrain(place, 0, labels.length() - 1)]
}

///|
/// A number for a row when the axis has no words of its own.
fn Chart::y_label(self : Chart, at : Int32, height : Int32) -> String {
  let bounds = self.bounds()
  let part = if height > 1 {
    (height - 1 - at).to_double() / (height - 1).to_double()
  } else {
    1.0
  }
  let value = bounds.high - (bounds.high - bounds.low) * part
  trim_double(value)
}

///|
fn Chart::foot_line(
  self : Chart,
  at : Int32,
  width : Int32,
  size : @geom.Size,
  gutter~ : Int32,
) -> @strip.Strip {
  let word_row = if self.x.labels.length() > 0 { 1 } else { 0 }
  if at == 0 && self.x.labels.length() > 0 {
    let labels = self.x.labels
    let segs : Array[@strip.Strip] = [@strip.Strip::blank(gutter, self.style)]
    let count = labels.length()
    let mut at = 0
    for k in 0..<count {
      let tick = if count > 1 && width > 1 {
        k * (width - 1) / (count - 1)
      } else {
        0
      }
      let text = clip_to(labels[k], width)
      let cells = @strip.str_cells(text)
      let start = if tick + cells > width {
        at_least_zero(width - cells)
      } else {
        tick
      }
      if start > at {
        segs.push(@strip.Strip::blank(start - at, self.style))
      } else {
        segs.push(@strip.Strip::blank(at_least_zero(start - at), self.style))
      }
      segs.push(@strip.Strip::of(text, self.label_style))
      at = start + cells
    }
    segs.push(@strip.Strip::blank(at_least_zero(width - at), self.style))
    return @strip.Strip::join(segs).pad_to(size.width, self.style)
  }
  if self.x.title.length() > 0 && at == word_row {
    return align_line(self.x.title, size.width, Centre, self.label_style)
  }
  @strip.Strip::blank(size.width, self.style)
}

///|
fn Chart::legend_line(self : Chart, size : @geom.Size) -> @strip.Strip {
  let segs : Array[@strip.Strip] = []
  for dataset in self.datasets {
    segs.push(@strip.Strip::of(dataset.kind.marker() + " ", dataset.style))
    segs.push(@strip.Strip::of(dataset.name + " ", self.style))
  }
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
fn y_title_of(axis : Axis) -> String {
  axis.title
}

///|
/// A number with no more than one decimal, and none when it is a whole one.
fn trim_double(value : Double) -> String {
  let whole = value.to_int()
  if value < 0.0 {
    return whole.to_string()
  }
  let tenths = ((value - whole.to_double()) * 10.0).to_int()
  if tenths == 0 {
    return whole.to_string()
  }
  whole.to_string() + "." + tenths.to_string()
}

///|
pub extend Axis with Debug::{to_repr}

///|
pub extend Axis with Eq::{not_equal, equal}

///|
pub extend Bounds with Debug::{to_repr}

///|
pub extend Bounds with Eq::{not_equal, equal}

///|
pub extend Dataset with Debug::{to_repr}

///|
pub extend Dataset with Eq::{not_equal, equal}

///|
pub extend GraphKind with Debug::{to_repr}

///|
pub extend GraphKind with Eq::{not_equal, equal}

///|
pub extend Chart with Widget::{focusable, handle, hint, render_line}
