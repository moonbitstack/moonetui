// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Six frames on one page, each with its title in the top edge and a note in
// the corner: a clock of big numerals, the month, what is left to do, the last
// commits, the load, and the day's agenda.

///|
const GAP : Int32 = 2

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let title_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let badge_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let warm : @style.Style = @style.Style::new(fg=@theme.warn, bold=true)

///|
let lit : @style.Style = @style.Style::new(fg=@theme.accent_alt, bold=true)

///|
/// A row that the cursor is on: the same ink, on a band one step up from the
/// page, so the eye finds it without a marker in the margin.
let picked : @style.Style = @style.Style::new(
  fg=@theme.ink,
  bg=@style.Rgb(0x22, 0x26, 0x38),
  bold=true,
)

///|
let picked_bg : @style.Style = @style.Style::new(
  bg=@style.Rgb(0x22, 0x26, 0x38),
)

///|
let done_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn cut(text : String, width : Int32) -> String {
  if @strip.str_cells(text) <= width {
    text
  } else {
    text[0:@strip.cut_at(text, width)].to_owned()
  }
}

///|
/// A line of content, cut to the panel and filled out to its width.
fn body_line(
  text : String,
  style : @style.Style,
  inner : Int32,
) -> @strip.Strip {
  @strip.Strip::of(cut(text, inner), style).pad_to(inner, @style.Style::new())
}

///|
/// `text` in a column of `width`, against its right edge.
fn right(text : String, width : Int32) -> String {
  let room = width - @strip.str_cells(text)
  if room > 0 {
    @theme.repeat(" ", room) + text
  } else {
    text
  }
}

///|
/// A bar of eighths, filled to `part` of `of`.
fn bar(part : Int32, of : Int32, width : Int32) -> String {
  let full = if of <= 0 { 0 } else { part * width / of }
  let out = StringBuilder()
  for i in 0..<width {
    out.write_string(if i < full { "█" } else { "░" })
  }
  out.to_string()
}

///|
/// A sparkline: a row of block heights, one per cell, sampled across the series.
fn spark(data : Array[Double], width : Int32) -> String {
  let marks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  let n = data.length()
  let out = StringBuilder()
  if n == 0 || width <= 0 {
    return ""
  }
  for x in 0..<width {
    let at = x * n / width
    let value = data[at]
    let mut step = (value / 12.5).to_int()
    if step < 0 {
      step = 0
    }
    if step > 7 {
      step = 7
    }
    out.write_string(marks[step])
  }
  out.to_string()
}

///|
/// The month of the day the board says it is: November 2026 starts on a Sunday
/// and has thirty days.
fn month_rows(inner : Int32, iy : Int32) -> @strip.Strip {
  if iy == 0 {
    return body_line("su mo tu we th fr sa", dim, inner)
  }
  if iy >= 1 && iy <= 5 {
    let first = 1 + (iy - 1) * 7
    let out = StringBuilder()
    for column in 0..<7 {
      let day = first + column
      if day > 30 {
        out.write_string(if column == 0 { "" } else { "   " })
      } else {
        let text = if day < 10 {
          " " + day.to_string()
        } else {
          day.to_string()
        }
        if column > 0 {
          out.write_string(" ")
        }
        out.write_string(text)
      }
    }
    let line = out.to_string()
    if iy == 3 {
      // The fifteenth is a Sunday, and it gets a band of its own.
      return @strip.Strip::join([
        @strip.Strip::of(
          "15",
          @style.Style::new(fg=@style.black, bg=@theme.accent, bold=true),
        ),
        @strip.Strip::of(line[2:].to_owned(), ink),
      ]).pad_to(inner, @style.Style::new())
    }
    return body_line(line, ink, inner)
  }
  if iy == 6 {
    return body_line("day 319 · week 46", dim, inner)
  }
  @strip.Strip::blank(inner, @style.Style::new())
}

///|
fn Board::cell(
  self : Board,
  panel : Int32,
  inner : Int32,
  iy : Int32,
) -> @strip.Strip {
  if iy < 0 {
    return @strip.Strip::blank(inner, @style.Style::new())
  }
  match panel {
    0 => {
      // What is left to do, with the cursor on one of them.
      if iy < 5 {
        let on = self.done[iy]
        let box = if on { "[x] " } else { "[ ] " }
        let text = box + chores[iy]
        if iy == self.cursor {
          return @strip.Strip::of(cut(text, inner), picked).pad_to(
            inner, picked_bg,
          )
        }
        return body_line(text, if on { done_style } else { ink }, inner)
      }
      if iy == 5 {
        return @strip.Strip::blank(inner, @style.Style::new())
      }
      if iy == 6 {
        let done = self.done_count()
        let left = " " +
          done.to_string() +
          "/" +
          self.done.length().to_string() +
          "  done"
        let room = inner - @strip.str_cells(left)
        return @strip.Strip::join([
          @strip.Strip::of(
            bar(done, self.done.length(), room),
            if done == self.done.length() {
              @style.Style::new(fg=@theme.good, bold=true)
            } else {
              @style.Style::new(fg=@theme.accent)
            },
          ),
          @strip.Strip::of(left, dim),
        ])
      }
      @strip.Strip::blank(inner, @style.Style::new())
    }
    1 => {
      // The clock: numerals for the hour and the minute, the rest in words.
      if iy < 3 {
        let shown = @widget.Digits::new(
          value=self.brief(),
          style=@style.Style::new(fg=@theme.ink, bold=true),
        )
        let width = @widget.Digits::width_of(self.brief())
        let pad = if inner > width { (inner - width) / 2 } else { 0 }
        let left = @strip.Strip::blank(pad, @style.Style::new())
        let right = @strip.Strip::blank(
          if inner > width + pad {
            inner - width - pad
          } else {
            0
          },
          @style.Style::new(),
        )
        return @strip.Strip::join([
          left,
          shown.render_line(iy, @geom.Size::new(width, 3)),
          right,
        ])
      }
      if iy == 3 {
        return @strip.Strip::blank(inner, @style.Style::new())
      }
      if iy == 4 {
        return body_line(
          "sun 15 nov 2026 · :" + self.seconds_text(),
          ink,
          inner,
        )
      }
      if iy == 5 {
        return body_line("tokyo 18:30 · ny 04:30", dim, inner)
      }
      if iy == 6 {
        return body_line("utc 09:30 · week 46", dim, inner)
      }
      @strip.Strip::blank(inner, @style.Style::new())
    }
    2 => month_rows(inner, iy)
    3 =>
      if iy < 6 {
        let (hash, subject, pushed) = commits[iy]
        let dot = @strip.Strip::of(
          if pushed {
            "● "
          } else {
            "○ "
          },
          if pushed {
            @style.Style::new(fg=@theme.good, bold=true)
          } else {
            warm
          },
        )
        @strip.Strip::join([
          dot,
          @strip.Strip::of(hash + " ", dim),
          @strip.Strip::of(cut(subject, inner - 9), ink),
        ]).pad_to(inner, @style.Style::new())
      } else if iy == 6 {
        body_line("6 today · 1 to push", dim, inner)
      } else {
        @strip.Strip::blank(inner, @style.Style::new())
      }
    4 => {
      // The host in four readings, each a label, a value and the bar it fills:
      // one shape repeated, so the eye can compare them without reading.
      let now = self.load[self.load.length() - 1]
      let pct = now.to_int()
      let reading = fn(label : String, value : String, style : @style.Style) {
        @strip.Strip::join([
          @strip.Strip::of(" " + label, dim),
          @strip.Strip::of(right(value, 9), style),
        ])
      }
      if iy == 0 {
        // The one line with two numbers on it: the reading, and what the
        // window averages, so a reader can tell a spike from a trend.
        return @strip.Strip::join([
          @strip.Strip::of(" cpu", dim),
          @strip.Strip::of(right(pct.to_string() + "%", 7), warm),
          @strip.Strip::of("  avg " + (pct - 8).to_string() + "%", dim),
        ]).crop(0, inner)
      }
      if iy == 1 {
        return @strip.Strip::join([
          @strip.Strip::of(" ", @style.Style::new()),
          @strip.Strip::of(
            spark(self.load, inner - 1),
            @style.Style::new(fg=@theme.accent),
          ),
        ]).pad_to(inner, @style.Style::new())
      }
      if iy >= 3 && iy <= 6 {
        let (label, value, filled, style) = match iy {
          3 => ("mem", "12.4/32g", 38, @theme.accent_alt)
          4 => ("", "", 38, @theme.accent_alt)
          5 => ("swp", "0.9/8g", 9, @theme.accent_alt)
          _ => ("", "", 9, @theme.accent_alt)
        }
        if label == "" {
          return @strip.Strip::join([
            @strip.Strip::of("  ", @style.Style::new()),
            @strip.Strip::of(
              bar(filled, 100, inner - 10),
              @style.Style::new(fg=style),
            ),
          ]).pad_to(inner, @style.Style::new())
        }
        return reading(label, value, @style.Style::new(fg=@theme.ink)).pad_to(
          inner,
          @style.Style::new(),
        )
      }
      if iy == 7 {
        return body_line(" net ↓ 1.4 mb/s · ↑ 320 kb/s", dim, inner)
      }
      @strip.Strip::blank(inner, @style.Style::new())
    }
    _ =>
      if iy < 5 {
        let (at, what, how) = agenda[iy]
        let live = iy == 1
        @strip.Strip::join([
          @strip.Strip::of(
            if live {
              "▸ "
            } else {
              "  "
            },
            if live {
              lit
            } else {
              dim
            },
          ),
          @strip.Strip::of(at + " ", if live { lit } else { dim }),
          @strip.Strip::of(cut(what, inner - 13), ink),
          @strip.Strip::of(" " + how, dim),
        ]).pad_to(inner, @style.Style::new())
      } else if iy == 6 {
        body_line("next in 40 minutes", dim, inner)
      } else {
        @strip.Strip::blank(inner, @style.Style::new())
      }
  }
}

///|
fn panel_titles() -> Array[(String, String)] {
  [
    ("TO DO", "5 items"),
    ("NOW", "local"),
    ("NOVEMBER", "2026"),
    ("COMMITS", "main"),
    ("LOAD", "60s"),
    ("AGENDA", "today"),
  ]
}

///|
/// One row of a panel: the frame, with the title written into the top edge.
fn framed(
  index : Int32,
  inner : Int32,
  ph : Int32,
  step_row : Int32,
  body : @strip.Strip,
) -> @strip.Strip {
  let width = inner + 2
  let (title, badge) = panel_titles()[index]
  if step_row == 0 {
    let head = "╭─ " + title + " "
    let tail = " " + badge + " ─╮"
    let fill = width - @strip.str_cells(head) - @strip.str_cells(tail)
    return @strip.Strip::from_segs([
      @strip.Seg::new(head, title_style),
      @strip.Seg::new(if fill > 0 { dashes(fill) } else { "" }, frame_style),
      @strip.Seg::new(tail, badge_style),
    ])
  }
  if step_row == ph - 1 {
    return @strip.Strip::of("╰" + dashes(width - 2) + "╯", frame_style)
  }
  @strip.Strip::join([
    @strip.Strip::of("│", frame_style),
    body,
    @strip.Strip::of("│", frame_style),
  ])
}

///|
fn dashes(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("─")
  }
  out.to_string()
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    return @theme.band(
      "moonetui",
      subject="board",
      note="sun 15 november 2026 · " + self.clock_text() + " · week 46",
      width~,
    )
  }
  if row == 1 {
    return @theme.rule(width~)
  }
  if row == height - 1 {
    return @theme.keys(
      [("↑↓", "task"), ("space", "done"), ("r", "refresh"), ("q", "quit")],
      width~,
    )
  }
  let pw = (width - GAP * 2) / 3
  let inner = pw - 2
  let top = 2
  let grid = height - 3
  let ph = (grid - 1) / 2
  if ph < 4 || inner < 8 {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let band = (row - top) / (ph + 1)
  let row_in = row - top - band * (ph + 1)
  if band > 1 || row_in >= ph {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let parts : Array[@strip.Strip] = []
  for column in 0..<3 {
    let index = band * 3 + column
    let body = self.cell(index, inner, row_in - 1)
    if column > 0 {
      parts.push(@strip.Strip::blank(GAP, @style.Style::new()))
    }
    parts.push(framed(index, inner, ph, row_in, body))
  }
  let used = pw * 3 + GAP * 2
  let offset = if width > used { (width - used) / 2 } else { 0 }
  @strip.Strip::join([
    @strip.Strip::blank(offset, @style.Style::new()),
    @strip.Strip::join(parts),
  ]).pad_to(width, @style.Style::new())
}

///|
impl @widget.Widget for Board with fn hint(_self, _size) {
  @geom.Size::new(72, 20)
}

///|
impl @widget.Widget for Board with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Board with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Up => {
          self.shift(-1)
          ctx.repaint()
          true
        }
        Down => {
          self.shift(1)
          ctx.repaint()
          true
        }
        Char(32) | Enter => {
          self.toggle()
          ctx.repaint()
          true
        }
        Char(114) => {
          self.refresh()
          ctx.repaint()
          true
        }
        _ => false
      }
    Tick(ms) => {
      let before = self.seconds
      self.tick(ms)
      if self.seconds != before {
        ctx.repaint()
        true
      } else {
        false
      }
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
  board : Board
}

///|
pub fn Screen::new() -> Screen {
  let board = Board::new()
  let root = @app.column(0, [
    @app.leaf(1, board, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, board, }
}
