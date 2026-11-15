// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The chart, the market and the logbook. The chart is a grid of cells: links
// drawn first, then the ports as rings, the one the ship is in filled in and
// the one it has set a course for open.

///|
const CHART_W : Int32 = 38

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let link_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x3a, 0x44, 0x62),
)

///|
let now_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let aim_style : @style.Style = @style.Style::new(
  fg=@theme.accent_alt,
  bold=true,
)

///|
let cheap : @style.Style = @style.Style::new(fg=@theme.good, bold=true)

///|
let dear : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let picked : @style.Style = @style.Style::new(bg=@style.Rgb(0x1c, 0x22, 0x33))

///|
fn rule(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("─")
  }
  out.to_string()
}

///|
fn spaces(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(" ")
  }
  out.to_string()
}

///|
fn cut(text : String, width : Int32) -> String {
  if @strip.str_cells(text) <= width {
    text
  } else {
    text[0:@strip.cut_at(text, width)].to_owned()
  }
}

///|
fn right(text : String, width : Int32) -> String {
  let cells = @strip.str_cells(text)
  if cells >= width {
    cut(text, width)
  } else {
    spaces(width - cells) + text
  }
}

///|
fn left(text : String, width : Int32) -> String {
  let cells = @strip.str_cells(text)
  if cells >= width {
    cut(text, width)
  } else {
    text + spaces(width - cells)
  }
}

///|
fn edge(
  width : Int32,
  top : Bool,
  title : String,
  note : String,
  body : @strip.Strip,
) -> @strip.Strip {
  if top {
    let head = "╭─ " + title + " "
    let tail = if note.length() > 0 { " " + note + " ─╮" } else { "─╮" }
    let fill = width - @strip.str_cells(head) - @strip.str_cells(tail)
    return @strip.Strip::from_segs([
      @strip.Seg::new(head, head_style),
      @strip.Seg::new(if fill > 0 { rule(fill) } else { "" }, frame_style),
      @strip.Seg::new(tail, dim),
    ])
  }
  @strip.Strip::join([
    @strip.Strip::of("│", frame_style),
    body,
    @strip.Strip::of("│", frame_style),
  ])
}

///|
fn floor(width : Int32) -> @strip.Strip {
  @strip.Strip::of("╰" + rule(width - 2) + "╯", frame_style)
}

///|
/// The style of a chart cell: nought is paper, one a link, two a port, three
/// the port the ship is in, four the port it has a course for.
fn cell_style(kind : Int32) -> @style.Style {
  match kind {
    1 => link_style
    2 => ink
    3 => now_style
    4 => aim_style
    _ => @style.Style::new()
  }
}

///|
/// One row of the chart: the ports on it as rings with their names beside them,
/// then the links, drawn only in the cells the names left free.
fn Ship::chart_row(self : Ship, y : Int32, width : Int32) -> @strip.Strip {
  let glyphs : Array[String] = []
  let kinds : Array[Int32] = []
  for _ in 0..<width {
    glyphs.push(" ")
    kinds.push(0)
  }
  // The ports first: a ring, and a name two cells to its right.
  for index in 0..<self.ports.length() {
    let port = self.ports[index]
    if port.y == y && port.x < width {
      let here = index == self.here
      let course = index == self.course && index != self.here
      glyphs[port.x] = if here { "◉" } else { "○" }
      kinds[port.x] = if here { 3 } else if course { 4 } else { 2 }
      let name = port.code
      let mut k = 0
      while k < name.length() && port.x + 2 + k < width {
        glyphs[port.x + 2 + k] = name[k].to_int().unsafe_to_char().to_string()
        kinds[port.x + 2 + k] = if here { 3 } else if course { 4 } else { 2 }
        k = k + 1
      }
    }
  }
  // Then the links: across a row, and down a column.
  let mut i = 0
  while i < self.ports.length() {
    let port = self.ports[i]
    let mut j = i + 1
    while j < self.ports.length() {
      let other = self.ports[j]
      // Only the nearest port to the right on this row: a link never runs
      // through another port.
      let mut nearest = true
      let mut k = i + 1
      while k < self.ports.length() {
        let third = self.ports[k]
        if third.y == y && third.x > port.x && third.x < other.x {
          nearest = false
        }
        k = k + 1
      }
      if port.y == other.y && port.y == y && nearest {
        let mut x = port.x + 3 + port.code.length()
        while x < other.x && x < width {
          if glyphs[x] == " " {
            glyphs[x] = "─"
            kinds[x] = 1
          }
          x = x + 1
        }
      } else if port.x == other.x && port.x < width {
        if (y > port.y && y < other.y) || (y > other.y && y < port.y) {
          if glyphs[port.x] == " " {
            glyphs[port.x] = "│"
            kinds[port.x] = 1
          }
        }
      }
      j = j + 1
    }
    i = i + 1
  }
  // Cells that share a style are one segment, so a row costs a handful of them.
  let parts : Array[@strip.Strip] = []
  let mut start = 0
  let mut kind = kinds[0]
  let mut x = 1
  while x <= width {
    if x == width || kinds[x] != kind {
      let text = StringBuilder()
      let mut k = start
      while k < x {
        text.write_string(glyphs[k])
        k = k + 1
      }
      parts.push(@strip.Strip::of(text.to_string(), cell_style(kind)))
      start = x
      if x < width {
        kind = kinds[x]
      }
    }
    x = x + 1
  }
  @strip.Strip::join(parts).pad_to(width, @style.Style::new())
}

///|
fn Ship::market_row(self : Ship, good : Int32, width : Int32) -> @strip.Strip {
  let price = price_at(self.here, good)
  let base = bases_mark(good)
  let trend = if price < base { "^" } else if price > base { "v" } else { "·" }
  let trend_style = if price < base {
    cheap
  } else if price > base {
    dear
  } else {
    dim
  }
  let line = @strip.Strip::join([
    @strip.Strip::of(
      left(names_of(good), 10),
      if good == self.good {
        ink
      } else {
        dim
      },
    ),
    @strip.Strip::of(
      right(price.to_string(), 6),
      if good == self.good {
        ink
      } else {
        dim
      },
    ),
    @strip.Strip::of(
      right(
        if price < base {
          "cheap"
        } else if price > base {
          "dear"
        } else {
          "fair"
        },
        7,
      ),
      dim,
    ),
    @strip.Strip::of(" " + trend, trend_style),
    @strip.Strip::of(right(self.bay[good].to_string(), 6), ink),
  ])
  if good == self.good {
    line.apply(picked).pad_to(width, picked)
  } else {
    line.pad_to(width, @style.Style::new())
  }
}

///|
fn names_of(good : Int32) -> String {
  match good {
    0 => "water"
    1 => "ore"
    2 => "medicine"
    _ => "spice"
  }
}

///|
fn bases_mark(good : Int32) -> Int32 {
  match good {
    0 => 12
    1 => 38
    2 => 90
    _ => 64
  }
}

///|
impl @widget.Widget for Ship with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    let band = @strip.Strip::of(
      " ◇ DRIFT",
      @style.Style::new(fg=@theme.accent_alt, bold=true),
    )
    let stats = @strip.Strip::of(
      right(self.credits.to_string(), 6) +
      " cr  ·  fuel " +
      self.fuel.to_string() +
      "/10  ·  hull " +
      self.hull.to_string() +
      "%  ·  hold " +
      self.held().to_string() +
      "/20 ",
      dim,
    )
    let fill = width - band.cell_length() - stats.cell_length()
    return @strip.Strip::join([
      band,
      @strip.Strip::blank(if fill > 0 { fill } else { 0 }, @style.Style::new()),
      stats,
    ]).pad_to(width, @style.Style::new())
  }
  if row == 1 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " ↑↓ course · ←→ good · j jump · b buy · s sell · f fuel · x patch · esc quit ",
      dim,
    ).pad_to(width, @style.Style::new())
  }
  let panel_h = 9
  let right_w = width - CHART_W - 1
  if row < 2 || row >= 2 + panel_h {
    let feed = 2 + panel_h + 1
    if row == feed {
      return @strip.Strip::join([
        @strip.Strip::of(" LOGBOOK", head_style),
        @strip.Strip::of("  " + self.note, dim),
      ]).pad_to(width, @style.Style::new())
    }
    if row > feed && row < height - 1 {
      let at = row - feed - 1
      if at < self.log.length() {
        let line = self.log[self.log.length() - 1 - at]
        return @strip.Strip::join([
          @strip.Strip::of("  › ", link_style),
          @strip.Strip::of(cut(line, width - 4), dim),
        ]).pad_to(width, @style.Style::new())
      }
    }
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let at = row - 2
  let here = self.ports[self.here]
  let course = self.ports[self.course]
  let chart = if at == 0 {
    edge(
      CHART_W,
      true,
      "CHART",
      self.ports.length().to_string(),
      @strip.Strip::empty(),
    )
  } else if at == panel_h - 1 {
    floor(CHART_W)
  } else {
    edge(CHART_W, false, "", "", self.chart_row(at - 1, CHART_W - 2))
  }
  let market = if at == 0 {
    edge(right_w, true, here.name, "market", @strip.Strip::empty())
  } else if at == panel_h - 1 {
    floor(right_w)
  } else if at == 1 {
    edge(
      right_w,
      false,
      "",
      "",
      @strip.Strip::join([
        @strip.Strip::of(
          left("good", 10) + right("price", 6) + right("trend", 7) + "    hold",
          dim,
        ),
        @strip.Strip::blank(right_w - 2 - 28, @style.Style::new()),
      ]),
    )
  } else if at >= 2 && at <= 5 {
    edge(right_w, false, "", "", self.market_row(at - 2, right_w - 2))
  } else if at == 6 {
    edge(
      right_w,
      false,
      "",
      "",
      @strip.Strip::of(
        cut(
          " jump to " +
          course.name +
          ": " +
          self.cost_to(self.course).to_string() +
          " fuel",
          right_w - 2,
        ),
        aim_style,
      ).pad_to(right_w - 2, @style.Style::new()),
    )
  } else {
    edge(
      right_w,
      false,
      "",
      "",
      @strip.Strip::blank(right_w - 2, @style.Style::new()),
    )
  }
  @strip.Strip::join([
    chart,
    @strip.Strip::blank(1, @style.Style::new()),
    market,
  ]).pad_to(width, @style.Style::new())
}

///|
impl @widget.Widget for Ship with fn hint(_self, _size) {
  @geom.Size::new(60, 18)
}

///|
impl @widget.Widget for Ship with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Ship with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Up => {
          self.walk(-1)
          ctx.repaint()
          true
        }
        Down => {
          self.walk(1)
          ctx.repaint()
          true
        }
        Left => {
          self.pick(-1)
          ctx.repaint()
          true
        }
        Right => {
          self.pick(1)
          ctx.repaint()
          true
        }
        Char(106) => {
          self.jump()
          ctx.repaint()
          true
        }
        Char(98) => {
          self.buy()
          ctx.repaint()
          true
        }
        Char(115) => {
          self.sell()
          ctx.repaint()
          true
        }
        Char(102) => {
          self.refuel()
          ctx.repaint()
          true
        }
        Char(120) => {
          self.patch()
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
  ship : Ship
}

///|
pub fn Screen::new() -> Screen {
  let ship = Ship::new()
  let root = @app.column(0, [
    @app.leaf(1, ship, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, ship, }
}
