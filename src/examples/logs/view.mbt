// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The tail itself: a gutter of line numbers, the level in its colour, the
// message, and a column down the right edge that is a map of the whole file, so
// a reader can see the errors coming before they arrive.

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let number_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x3f, 0x48, 0x66),
)

///|
let info_style : @style.Style = @style.Style::new(fg=@theme.accent)

///|
let warn_style : @style.Style = @style.Style::new(fg=@theme.warn, bold=true)

///|
let error_style : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let picked : @style.Style = @style.Style::new(bg=@style.Rgb(0x1c, 0x22, 0x33))

///|
let bar_style : @style.Style = @style.Style::new(
  bg=@style.Rgb(0x0d, 0x10, 0x18),
)

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
fn level_text(level : Level) -> String {
  match level {
    Info => "INFO"
    Warn => "WARN"
    Error => "ERROR"
  }
}

///|
fn level_style(level : Level) -> @style.Style {
  match level {
    Info => info_style
    Warn => warn_style
    Error => error_style
  }
}

///|
/// One row: the gutter, the clock, the level and the message, cut to the room
/// the map column leaves.
fn Tail::row(self : Tail, index : Int32, message : Int32) -> @strip.Strip {
  let space = self.visible()
  if index < 0 || index >= space.length() {
    return @strip.Strip::blank(message + 25, @style.Style::new())
  }
  let line = self.lines[space[index]]
  let here = index == self.cursor
  @strip.Strip::join([
    @strip.Strip::of(
      if here {
        " ▎"
      } else {
        "  "
      },
      if here {
        head_style
      } else {
        dim
      },
    ),
    @strip.Strip::of(right(line.number.to_string(), 4) + "  ", number_style),
    @strip.Strip::of(line.at + "  ", dim),
    @strip.Strip::of(
      right(level_text(line.level), 5) + "  ",
      level_style(line.level),
    ),
    @strip.Strip::of(cut(line.text, message), ink),
  ]).pad_to(message + 25, @style.Style::new())
}

///|
fn map_cell(level : Level?) -> @strip.Strip {
  match level {
    Some(Error) => @strip.Strip::of("█", error_style)
    Some(Warn) => @strip.Strip::of("▌", warn_style)
    Some(Info) => @strip.Strip::of("·", number_style)
    None => @strip.Strip::of(" ", dim)
  }
}

///|
impl @widget.Widget for Tail with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    return @theme.band(
      "moonetui",
      subject="logs",
      note="api.log · " +
        self.lines.length().to_string() +
        " lines · " +
        self.count(Error).to_string() +
        " errors · " +
        (if self.follow { "tailing" } else { "held" }),
      width~,
    )
  }
  if row == 1 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 2 {
    return self.filter_bar(width)
  }
  if row == height - 1 {
    return @theme.keys(
      [
        ("1-3", "levels"),
        ("↑↓", "scroll"),
        ("e", "error"),
        ("space", "hold"),
        ("/", "filter"),
        ("q", "quit"),
      ],
      width~,
    )
  }
  let top = 2
  let rows = height - 4
  if row < top || row >= top + rows {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let space = self.visible()
  let offset = if self.follow && space.length() > rows {
    space.length() - rows
  } else if self.cursor >= rows - 1 {
    self.cursor - rows + 2
  } else {
    0
  }
  let at = row - top
  let index = offset + at
  let here = index == self.cursor
  let message = width - 2 - 25
  let line = self.row(index, message)
  @strip.Strip::join([
    line.apply(if here { picked } else { @style.Style::new() }),
    @strip.Strip::of(" ", @style.Style::new()),
    map_cell(self.map_at(at, rows)),
  ]).pad_to(width, if here { picked } else { @style.Style::new() })
}

///|
fn Tail::count_slot(self : Tail, slot : Int32) -> Int32 {
  match slot {
    0 => self.count(Info)
    1 => self.count(Warn)
    _ => self.count(Error)
  }
}

///|
/// The bar of filters: three levels that can be turned off, the query being
/// typed, and how many lines are left.
fn Tail::filter_bar(self : Tail, width : Int32) -> @strip.Strip {
  let parts : Array[@strip.Strip] = [@strip.Strip::of(" ", bar_style)]
  let labels : Array[String] = ["1 info", "2 warn", "3 error"]
  for slot in 0..<3 {
    let on = self.levels[slot]
    let text = " " +
      labels[slot] +
      " " +
      self.count_slot(slot).to_string() +
      " "
    let style = if on {
      @style.Style::new(fg=@style.black, bg=@theme.accent, bold=true)
    } else {
      @style.Style::new(fg=@theme.muted, bg=@style.Rgb(0x0d, 0x10, 0x18))
    }
    parts.push(@strip.Strip::of(text, style))
    parts.push(@strip.Strip::of(" ", bar_style))
  }
  let middle = if self.typing {
    "  /" + self.query + "▌  "
  } else if self.query.length() > 0 {
    "  /" + self.query + "  "
  } else {
    "  /  "
  }
  let middle_style = if self.typing {
    @style.Style::new(
      fg=@theme.accent_alt,
      bold=true,
      bg=@style.Rgb(0x0d, 0x10, 0x18),
    )
  } else {
    @style.Style::new(fg=@theme.muted, bg=@style.Rgb(0x0d, 0x10, 0x18))
  }
  parts.push(@strip.Strip::of(middle, middle_style))
  parts.push(
    @strip.Strip::of(
      " " + self.visible().length().to_string() + " shown ",
      @style.Style::new(fg=@theme.muted, bg=@style.Rgb(0x0d, 0x10, 0x18)),
    ),
  )
  @strip.Strip::join(parts).pad_to(width, bar_style)
}

///|
impl @widget.Widget for Tail with fn hint(_self, _size) {
  @geom.Size::new(56, 14)
}

///|
impl @widget.Widget for Tail with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Tail with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Char(ch) => {
          if self.typing {
            if ch >= 32 && ch < 127 {
              self.letter(ch)
              ctx.repaint()
              return true
            }
            return false
          }
          if ch == 47 {
            self.begin()
          } else if ch >= 49 && ch <= 51 {
            self.toggle(ch - 49)
          } else if ch == 101 {
            self.next_error()
          } else if ch == 32 {
            self.hold()
          } else {
            return false
          }
          ctx.repaint()
          true
        }
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
        PageUp => {
          self.walk(-10)
          ctx.repaint()
          true
        }
        PageDown => {
          self.walk(10)
          ctx.repaint()
          true
        }
        Enter =>
          if self.typing {
            self.settle()
            ctx.repaint()
            true
          } else {
            false
          }
        Backspace =>
          if self.typing {
            self.rub()
            ctx.repaint()
            true
          } else {
            false
          }
        Escape =>
          if self.typing || self.query.length() > 0 {
            self.clear()
            ctx.repaint()
            true
          } else {
            false
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
  tail : Tail
}

///|
pub fn Screen::new() -> Screen {
  let tail = Tail::new()
  let root = @app.column(0, [
    @app.leaf(1, tail, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, tail, }
}
