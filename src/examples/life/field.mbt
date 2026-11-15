// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A field of cells that follows one rule: a live cell with two or three live
/// neighbours lives, a dead one with exactly three is born. The edges wrap, so
/// a glider that leaves the right edge comes back on the left.
pub struct Field {
  cols : Int32
  rows : Int32
  mut cells : Array[Bool]
  mut gen : Int32
  mut running : Bool
  mut started : Bool
  mut peak : Int32
}

///|
/// Three figures a reader can recognise: a glider that walks, a blinker that
/// pulses, and a block that sits still.
pub fn Field::new(cols~ : Int32 = 44, rows~ : Int32 = 14) -> Field {
  let field : Field = {
    cols,
    rows,
    cells: [],
    gen: 0,
    running: false,
    started: false,
    peak: 0,
  }
  field.seed()
  field.running = false
  field
}

///|
fn put(field : Field, x : Int32, y : Int32) -> Unit {
  field.cells[y * field.cols + x] = true
}

///|
/// Start again, from the same three figures: a demonstration that can be
/// replayed, and a frame test that can say what it sees.
pub fn Field::seed(self : Field) -> Unit {
  let cells : Array[Bool] = []
  for _ in 0..<(self.cols * self.rows) {
    cells.push(false)
  }
  self.cells = cells
  self.gen = 0
  // A glider, walking down and right.
  put(self, 2, 2)
  put(self, 3, 3)
  put(self, 1, 4)
  put(self, 2, 4)
  put(self, 3, 4)
  // A blinker, pulsing in place.
  put(self, 14, 6)
  put(self, 15, 6)
  put(self, 16, 6)
  // A block, which never changes.
  put(self, 30, 9)
  put(self, 31, 9)
  put(self, 30, 10)
  put(self, 31, 10)
  self.peak = self.alive()
  if self.started {
    self.running = true
  }
}

///|
pub fn Field::gen(self : Field) -> Int32 {
  self.gen
}

///|
pub fn Field::peak(self : Field) -> Int32 {
  self.peak
}

///|
pub fn Field::started(self : Field) -> Bool {
  self.started
}

///|
pub fn Field::alive(self : Field) -> Int32 {
  let mut count = 0
  for cell in self.cells {
    if cell {
      count = count + 1
    }
  }
  count
}

///|
pub fn Field::alive_at(self : Field, x : Int32, y : Int32) -> Bool {
  self.cells[y * self.cols + x]
}

///|
pub fn Field::running(self : Field) -> Bool {
  self.running
}

///|
/// Open the field: from here the clock runs and the generations count.
pub fn Field::start(self : Field) -> Unit {
  self.started = true
  self.running = true
}

///|
pub fn Field::toggle(self : Field) -> Unit {
  self.running = !self.running
}

///|
fn Field::neighbours(self : Field, x : Int32, y : Int32) -> Int32 {
  let mut count = 0
  for dy in -1..<=1 {
    for dx in -1..<=1 {
      if dx == 0 && dy == 0 {
        continue
      }
      let nx = (x + dx + self.cols) % self.cols
      let ny = (y + dy + self.rows) % self.rows
      if self.cells[ny * self.cols + nx] {
        count = count + 1
      }
    }
  }
  count
}

///|
/// One generation. A paused field keeps its cells and its generation count.
pub fn Field::step(self : Field) -> Unit {
  if !self.started || !self.running {
    return
  }
  let next : Array[Bool] = []
  for y in 0..<self.rows {
    for x in 0..<self.cols {
      let around = self.neighbours(x, y)
      let live = self.cells[y * self.cols + x]
      next.push(around == 3 || (live && around == 2))
    }
  }
  self.cells = next
  self.gen = self.gen + 1
  let now = self.alive()
  if now > self.peak {
    self.peak = now
  }
}

///|
let alive_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let dead_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let hud_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let value_style : @style.Style = @style.Style::new(fg=@theme.ink, bold=true)

///|
let title_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let blank_style : @style.Style = @style.Style::new()

///|
fn centred(text : String, width : Int32, style : @style.Style) -> @strip.Strip {
  let pad = (width - @strip.str_cells(text)) / 2
  if pad <= 0 {
    return @strip.Strip::of(text, style)
  }
  @strip.Strip::join([
    @strip.Strip::blank(pad, blank_style),
    @strip.Strip::of(text, style),
  ])
}

///|
/// What the field says on the line above it, and on the title, one row each.
fn Field::scene_line(self : Field, row : Int32) -> (String, @style.Style)? {
  let middle = self.rows / 2
  if self.started {
    return None
  }
  if row == middle - 1 {
    Some(("L I F E", title_style))
  } else if row == middle + 1 {
    Some(("space to start", hud_style))
  } else if row == middle + 2 {
    Some(("glider · blinker · block", hud_style))
  } else {
    None
  }
}

///|
impl @widget.Widget for Field with fn render_line(self, row, size) {
  if row == 0 {
    let state = if self.running {
      "running"
    } else if self.started {
      "paused"
    } else {
      "ready"
    }
    return @strip.Strip::join([
      @strip.Strip::of(" gen ", hud_style),
      @strip.Strip::of(self.gen.to_string(), value_style),
      @strip.Strip::of("   alive ", hud_style),
      @strip.Strip::of(self.alive().to_string(), value_style),
      @strip.Strip::of("   peak ", hud_style),
      @strip.Strip::of(self.peak.to_string(), value_style),
      @strip.Strip::of("   " + state, hud_style),
    ])
  }
  let y = row - 1
  if y < 0 || y >= self.rows {
    return @strip.Strip::blank(size.width, blank_style)
  }
  let offset = if size.width > self.cols {
    (size.width - self.cols) / 2
  } else {
    0
  }
  match self.scene_line(y) {
    Some((text, style)) =>
      @strip.Strip::join([
        @strip.Strip::blank(offset, blank_style),
        centred(text, self.cols, style),
      ])
    None => {
      let parts : Array[@strip.Strip] = []
      if offset > 0 {
        parts.push(@strip.Strip::blank(offset, blank_style))
      }
      for x in 0..<self.cols {
        if !self.started {
          parts.push(@strip.Strip::blank(1, blank_style))
        } else if self.cells[y * self.cols + x] {
          parts.push(@strip.Strip::of("█", alive_style))
        } else {
          // A faint dot on the dead cells: an empty field still reads as a grid.
          parts.push(@strip.Strip::of("·", dead_style))
        }
      }
      @strip.Strip::join(parts)
    }
  }
}

///|
impl @widget.Widget for Field with fn hint(self, _size) {
  @geom.Size::new(self.cols, self.rows + 1)
}

///|
impl @widget.Widget for Field with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Field with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Char(32) => {
          if self.started {
            self.toggle()
          } else {
            self.start()
          }
          ctx.repaint()
          true
        }
        Char(114) => {
          self.started = true
          self.running = true
          self.seed()
          ctx.repaint()
          true
        }
        Char(46) => {
          let was = self.running
          self.started = true
          self.running = true
          self.step()
          self.running = was && self.running
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}
