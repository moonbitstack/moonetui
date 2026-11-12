// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One thing to draw, in the canvas's own coordinates: the range the canvas was
/// given, not rows and columns.
#derive(Eq, Debug)
pub(all) enum Shape {
  /// A point at `(x, y)`.
  Dot(Double, Double)
  /// A straight line from `(x0, y0)` to `(x1, y1)`.
  Line(Double, Double, Double, Double)
  /// The outline of a rectangle from `(x0, y0)` to `(x1, y1)`.
  Rect(Double, Double, Double, Double)
  /// The outline of a circle at `(cx, cy)` with radius `r`.
  Circle(Double, Double, Double)
}

///|
pub extend Shape with Eq::{not_equal, equal}

///|
pub extend Shape with Debug::{to_repr}

///|
/// A plot drawn with Braille dots: each cell of the terminal is two dots wide and
/// four tall, which is the finest grid a terminal without images offers.
///
/// The canvas draws into whatever size the layout gives it, so the same shapes
/// are a thumbnail in a sidebar and a full plot in the main pane. `x_range` and
/// `y_range` say what coordinates the shape values are in; `y` grows upwards,
/// as a plot does, though the rows of a terminal grow down.
pub struct Canvas {
  mut shapes : Array[Shape]
  mut x_range : (Double, Double)
  mut y_range : (Double, Double)
  style : @style.Style
  mut dots : Array[Bool]
  mut dots_width : Int32
  mut dots_height : Int32
  mut drawn_width : Int32
  mut drawn_height : Int32
}

///|
pub fn Canvas::new(
  shapes~ : Array[Shape] = [],
  x_range~ : (Double, Double) = (0.0, 1.0),
  y_range~ : (Double, Double) = (0.0, 1.0),
  style~ : @style.Style = @style.default,
) -> Canvas {
  {
    shapes,
    x_range,
    y_range,
    style,
    dots: [],
    dots_width: 0,
    dots_height: 0,
    drawn_width: 0,
    drawn_height: 0,
  }
}

///|
pub fn Canvas::shapes(self : Canvas) -> Array[Shape] {
  self.shapes
}

///|
pub fn Canvas::set_shapes(self : Canvas, shapes : Array[Shape]) -> Unit {
  self.shapes = shapes
  self.drawn_width = 0
}

///|
/// Adds one shape to what is already there.
pub fn Canvas::draw(self : Canvas, shape : Shape) -> Unit {
  self.shapes.push(shape)
  self.drawn_width = 0
}

///|
/// The coordinates the shapes are read in. `y` grows upwards.
pub fn Canvas::set_range(
  self : Canvas,
  x_range~ : (Double, Double),
  y_range~ : (Double, Double),
) -> Unit {
  self.x_range = x_range
  self.y_range = y_range
  self.drawn_width = 0
}

///|
pub fn Canvas::x_range(self : Canvas) -> (Double, Double) {
  self.x_range
}

///|
pub fn Canvas::y_range(self : Canvas) -> (Double, Double) {
  self.y_range
}

///|
/// The bit a dot takes in the Braille pattern of its cell: the left column is
/// dots 1, 2, 3 and 7 from the top, the right column 4, 5, 6 and 8.
fn dot_bit(dx : Int32, dy : Int32) -> Int32 {
  match (dx, dy) {
    (0, 0) => 0x01
    (0, 1) => 0x02
    (0, 2) => 0x04
    (0, 3) => 0x40
    (1, 0) => 0x08
    (1, 1) => 0x10
    (1, 2) => 0x20
    _ => 0x80
  }
}

///|
/// Fills the dot grid for the size asked for, if it is not filled already.
fn Canvas::build(self : Canvas, width : Int32, height : Int32) -> Unit {
  if self.drawn_width == width && self.drawn_height == height {
    return
  }
  self.dots_width = width * 2
  self.dots_height = height * 4
  self.drawn_width = width
  self.drawn_height = height
  let total = self.dots_width * self.dots_height
  self.dots = []
  for _ in 0..<total {
    self.dots.push(false)
  }
  for shape in self.shapes {
    self.place(shape)
  }
}

///|
/// One dot, if it falls inside the grid: a shape that runs off the edge is cut
/// there rather than wrapping or failing.
fn Canvas::plot(self : Canvas, x : Double, y : Double) -> Unit {
  let dot_x = round_to_dot(x)
  let dot_y = round_to_dot(y)
  if dot_x < 0 ||
    dot_y < 0 ||
    dot_x >= self.dots_width ||
    dot_y >= self.dots_height {
    return
  }
  self.dots[dot_y * self.dots_width + dot_x] = true
}

///|
fn round_to_dot(value : Double) -> Int32 {
  (value + 0.5).to_int()
}

///|
/// A shape in canvas coordinates to dots, and then to the plot.
fn Canvas::place(self : Canvas, shape : Shape) -> Unit {
  let (x0, x1) = self.x_range
  let (y0, y1) = self.y_range
  let span_x = if x1 == x0 { 1.0 } else { x1 - x0 }
  let span_y = if y1 == y0 { 1.0 } else { y1 - y0 }
  let to_dot_x = fn(x : Double) {
    (x - x0) / span_x * (self.dots_width - 1).to_double()
  }
  let to_dot_y = fn(y : Double) {
    (1.0 - (y - y0) / span_y) * (self.dots_height - 1).to_double()
  }
  match shape {
    Dot(x, y) => self.plot(to_dot_x(x), to_dot_y(y))
    Line(ax, ay, bx, by) =>
      self.segment(to_dot_x(ax), to_dot_y(ay), to_dot_x(bx), to_dot_y(by))
    Rect(ax, ay, bx, by) => {
      let left = to_dot_x(ax)
      let right = to_dot_x(bx)
      let top = to_dot_y(ay)
      let bottom = to_dot_y(by)
      self.segment(left, top, right, top)
      self.segment(left, bottom, right, bottom)
      self.segment(left, top, left, bottom)
      self.segment(right, top, right, bottom)
    }
    Circle(cx, cy, r) => {
      let centre_x = to_dot_x(cx)
      let centre_y = to_dot_y(cy)
      let radius_x = r / span_x * (self.dots_width - 1).to_double()
      let radius_y = r / span_y * (self.dots_height - 1).to_double()
      let steps = (radius_x.max(radius_y) * 8.0 + 16.0).to_int()
      for step in 0..<steps {
        let turn = 6.283185307179586 * step.to_double() / steps.to_double()
        self.plot(
          centre_x + radius_x * @math.cos(turn),
          centre_y - radius_y * @math.sin(turn),
        )
      }
    }
  }
}

///|
/// A straight run of dots, one dot per step along its longer axis, so it has no
/// gaps whatever angle it is drawn at.
fn Canvas::segment(
  self : Canvas,
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
) -> Unit {
  let steps = (bx - ax).abs().max((by - ay).abs()).to_int().max(1)
  for step in 0..<=steps {
    let t = step.to_double() / steps.to_double()
    self.plot(ax + (bx - ax) * t, ay + (by - ay) * t)
  }
}

///|
/// The glyph of one cell: its eight dots as one character, or a space when it is
/// empty so that a blank plot is not a field of blank Braille patterns.
fn Canvas::glyph(self : Canvas, x : Int32, y : Int32) -> Char {
  let mut bits = 0
  for dx in 0..<=1 {
    for dy in 0..<=3 {
      let dot_x = x * 2 + dx
      let dot_y = y * 4 + dy
      if self.dots[dot_y * self.dots_width + dot_x] {
        bits = bits | dot_bit(dx, dy)
      }
    }
  }
  if bits == 0 {
    return ' '
  }
  (0x2800 + bits).unsafe_to_char()
}

///|
pub impl Widget for Canvas with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 || row < 0 || row >= size.height {
    return @strip.Strip::empty()
  }
  self.build(size.width, size.height)
  let out = StringBuilder()
  for x in 0..<size.width {
    out.write_char(self.glyph(x, row))
  }
  @strip.Strip::of(out.to_string(), self.style)
}

///|
pub impl Widget for Canvas with fn hint(_self, size) {
  size
}

///|
pub impl Widget for Canvas with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for Canvas with fn focusable(_self) {
  false
}

///|
pub extend Canvas with Widget::{focusable, handle, hint, render_line}
