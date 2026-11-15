// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A torus, turned on two axes and drawn as characters of shade. The maths is
/// the classic one: sample the surface, rotate it, project it, keep the nearest
/// sample per cell, and pick a glyph from how much light it caught.
pub struct Donut {
  cols : Int32
  rows : Int32
  mut a : Double
  mut b : Double
  mut paused : Bool
  mut frame : Array[String]
  mut levels : Array[Int32]
  mut ghost : Array[Int32]
}

///|
/// The shades, darkest first. A terminal has no lighting, so brightness is the
/// density of the glyph.
let shades : Array[String] = [
  ".", ",", "-", "~", ":", ";", "=", "!", "*", "#", "$", "@",
]

///|
pub fn Donut::new(cols~ : Int32 = 56, rows~ : Int32 = 20) -> Donut {
  let donut : Donut = {
    cols,
    rows,
    a: 0.0,
    b: 0.0,
    paused: false,
    frame: [],
    levels: [],
    ghost: [],
  }
  donut.spin()
  donut
}

///|
pub fn Donut::paused(self : Donut) -> Bool {
  self.paused
}

///|
pub fn Donut::toggle(self : Donut) -> Unit {
  self.paused = !self.paused
}

///|
/// The angle the donut has turned to, which is what a frame test reads.
pub fn Donut::angle(self : Donut) -> Double {
  self.a
}

///|
pub fn Donut::rows(self : Donut) -> Int32 {
  self.rows
}

///|
/// One frame: advance both angles and draw the surface into a new grid.
pub fn Donut::spin(self : Donut) -> Unit {
  if self.paused {
    return
  }
  self.a = self.a + 0.07
  self.b = self.b + 0.03
  // What the last frame drew becomes a shadow: the torus leaves a trace of
  // where it was, which is what makes a turning shape read as turning.
  self.ghost = self.levels
  let levels = self.draw()
  self.levels = levels
  self.frame = self.to_rows(levels)
}

///|
/// The grid of this frame, one string a row.
pub fn Donut::frame(self : Donut) -> Array[String] {
  self.frame
}

///|
fn Donut::draw(self : Donut) -> Array[Int32] {
  let cells = self.cols * self.rows
  let depth : Array[Double] = []
  let glyph : Array[Int32] = []
  for _ in 0..<cells {
    depth.push(0.0)
    glyph.push(-1)
  }
  let cos_a = @math.cos(self.a)
  let sin_a = @math.sin(self.a)
  let cos_b = @math.cos(self.b)
  let sin_b = @math.sin(self.b)
  // The tube is sampled coarsely on purpose: more samples means a longer
  // frame, and a terminal draws at most a few dozen a second.
  let theta_step = 0.09
  let phi_step = 0.035
  let mut theta = 0.0
  while theta < 6.283185307179586 {
    let cos_t = @math.cos(theta)
    let sin_t = @math.sin(theta)
    let mut phi = 0.0
    while phi < 6.283185307179586 {
      let cos_p = @math.cos(phi)
      let sin_p = @math.sin(phi)
      // A point on the torus: tube of radius 1 around a ring of radius 2.
      let ring = 2.0 + cos_p
      let px = ring * cos_t
      let py = ring * sin_t
      let pz = sin_p
      // The surface normal at that point points away from the tube's centre.
      let ny = cos_p * sin_t
      let nx = cos_p * cos_t
      let nz = sin_p
      // Turn about x, then about z: point and normal turn together.
      let py1 = py * cos_a - pz * sin_a
      let pz1 = py * sin_a + pz * cos_a
      let ny1 = ny * cos_a - nz * sin_a
      let nz1 = ny * sin_a + nz * cos_a
      let px2 = px * cos_b - py1 * sin_b
      let py2 = px * sin_b + py1 * cos_b
      let nx2 = nx * cos_b - ny1 * sin_b
      let ny2 = nx * sin_b + ny1 * cos_b
      // Push the torus away from the eye, then divide by depth: nearer cells
      // come out larger, which is the whole of the perspective.
      let depth_here = pz1 + 6.0
      if depth_here > 0.1 {
        let scale = 1.0 / depth_here
        let sx = self.cols.to_double() / 2.0 + 34.0 * scale * px2
        let sy = self.rows.to_double() / 2.0 - 16.0 * scale * py2
        let x = sx.to_int()
        let y = sy.to_int()
        if x >= 0 && x < self.cols && y >= 0 && y < self.rows {
          let cell = y * self.cols + x
          let seen = 1.0 / depth_here
          if seen > depth[cell] {
            depth[cell] = seen
            // Light from over the reader's shoulder, plus a little bounce so
            // the back of the torus is not black.
            // Light from the reader's upper left, in front of the screen: the
            // dot product of the turned normal with that direction.
            let light = 0.22 + 0.55 * ny2 - 0.62 * nz1 + 0.10 * nx2
            let level = if light < 0.0 {
              0
            } else if light > 1.0 {
              shades.length() - 1
            } else {
              (light * (shades.length() - 1).to_double()).to_int()
            }
            glyph[cell] = level
          }
        }
      }
      phi = phi + phi_step
    }
    theta = theta + theta_step
  }
  glyph
}

///|
/// The glyph grid of one frame, as text. A cell the torus missed still shows
/// the shadow of the frame before, two shades down.
fn Donut::to_rows(self : Donut, levels : Array[Int32]) -> Array[String] {
  let rows : Array[String] = []
  for y in 0..<self.rows {
    let line = StringBuilder()
    for x in 0..<self.cols {
      let cell = y * self.cols + x
      let level = levels[cell]
      if level >= 0 {
        line.write_string(shades[level])
      } else if cell < self.ghost.length() && self.ghost[cell] > 1 {
        line.write_string(shades[self.ghost[cell] - 2])
      } else {
        line.write_string(" ")
      }
    }
    rows.push(line.to_string())
  }
  rows
}

///|
let ink_style : @style.Style = @style.Style::new(fg=@theme.accent)

///|
impl @widget.Widget for Donut with fn render_line(self, row, size) {
  if row < 0 || row >= self.rows {
    return @strip.Strip::blank(size.width, @style.default)
  }
  let text = if row < self.frame.length() { self.frame[row] } else { "" }
  @strip.Strip::of(text, ink_style)
}

///|
impl @widget.Widget for Donut with fn hint(self, _size) {
  @geom.Size::new(self.cols, self.rows)
}

///|
impl @widget.Widget for Donut with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Donut with fn handle(self, ctx, msg) {
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
  // Nothing around the object: a black stage, a line of text, a line of keys.
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=@theme.ink)),
  )
  sheet.add(
    @design.Sel::new(name="Header"),
    @design.Styles::new(text=@style.Style::new(fg=@theme.muted)),
  )
  sheet.add(
    @design.Sel::new(classes=["bar"]),
    @design.Styles::new(dock=@design.Bottom),
  )
  sheet
}

///|
pub struct Screen {
  root : @app.Node
  donut : Donut
}

///|
pub fn Screen::new() -> Screen {
  let donut = Donut::new()
  let head = @theme.header("donut", note="a torus, turning · space holds")
  let foot = @theme.footer([("space", "hold"), ("esc", "quit")])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1)), name="Header"),
    @app.leaf(2, donut, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1)), classes=["bar"]),
  ])
  { root, donut, }
}
