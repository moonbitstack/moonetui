// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// One host, drawn the way a container client draws it: the boxes down the left
// with a dot for each state, the chosen box opened to the right, and its log
// running underneath.

///|
const LIST_W : Int32 = 30

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let good : @style.Style = @style.Style::new(fg=@theme.good)

///|
let warn : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let bad : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let chosen : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.accent,
  bold=true,
)

///|
let chosen_bg : @style.Style = @style.Style::new(bg=@theme.accent)

///|
fn cells_of(text : String) -> Int32 {
  @strip.str_cells(text)
}

///|
fn cut(text : String, width : Int32) -> String {
  if cells_of(text) <= width {
    text
  } else {
    text[0:@strip.cut_at(text, width)].to_owned()
  }
}

///|
fn filled(text : String, width : Int32, style : @style.Style) -> @strip.Strip {
  let body = cut(text, width)
  @strip.Strip::of(body, style).pad_to(width, @style.Style::new())
}

///|
fn right(text : String, width : Int32) -> String {
  let cells = cells_of(text)
  if cells >= width {
    cut(text, width)
  } else {
    let out = StringBuilder()
    for _ in 0..<(width - cells) {
      out.write_string(" ")
    }
    out.write_string(text)
    out.to_string()
  }
}

///|
/// The dotted edge of a panel, with a title written into the top line and a
/// note in the corner.
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
    let fill = width - cells_of(head) - cells_of(tail)
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
fn rule(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("─")
  }
  out.to_string()
}

///|
fn floor(width : Int32) -> @strip.Strip {
  @strip.Strip::of("╰" + rule(width - 2) + "╯", frame_style)
}

///|
fn mem_text(mem : Int32) -> String {
  if mem >= 1024 {
    (mem / 1024).to_string() + "." + (mem % 1024 * 10 / 1024).to_string() + "g"
  } else if mem == 0 {
    "--"
  } else {
    mem.to_string() + "m"
  }
}

///|
fn up_text(minutes : Int32) -> String {
  if minutes >= 1440 {
    (minutes / 1440).to_string() + "d " + (minutes / 60 % 24).to_string() + "h"
  } else if minutes >= 60 {
    (minutes / 60).to_string() + "h " + (minutes % 60).to_string() + "m"
  } else {
    minutes.to_string() + "m"
  }
}

///|
fn dot_of(state : State) -> String {
  match state {
    Running => "●"
    Restarting => "◌"
    Exited => "○"
  }
}

///|
fn state_style(state : State) -> @style.Style {
  match state {
    Running => good
    Restarting => warn
    Exited => dim
  }
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
/// One line of the list: a dot for the state, the name, and what it is costing
/// the host. The chosen line is a band of the accent colour.
fn Host::row(self : Host, index : Int32, inner : Int32) -> @strip.Strip {
  let item = self.boxes[index]
  let name = cut(item.name, 13)
  let gap = 13 - cells_of(name)
  let cpu = right(item.cpu.to_string() + "%", 5)
  let mem = right(mem_text(item.mem), 6)
  if index == self.pick {
    let text = " " +
      dot_of(item.state) +
      " " +
      name +
      spaces(gap) +
      cpu +
      " " +
      mem
    return @strip.Strip::of(cut(text, inner), chosen).pad_to(inner, chosen_bg)
  }
  @strip.Strip::join([
    @strip.Strip::of(" " + dot_of(item.state) + " ", state_style(item.state)),
    @strip.Strip::of(name + spaces(gap), ink),
    @strip.Strip::of(cpu + " ", dim),
    @strip.Strip::of(mem, dim),
  ]).pad_to(inner, @style.Style::new())
}

///|
impl @widget.Widget for Host with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    let left = @strip.Strip::of(" ⬢ CONTAINERS", head_style)
    let right_text = @strip.Strip::of(
      "dockerd 27.1  ·  " +
      self.running().to_string() +
      " running of " +
      self.boxes.length().to_string() +
      "  ·  " +
      self.note +
      " ",
      dim,
    )
    let fill = width - left.cell_length() - right_text.cell_length()
    return @strip.Strip::join([
      left,
      @strip.Strip::blank(if fill > 0 { fill } else { 0 }, @style.Style::new()),
      right_text,
    ]).pad_to(width, @style.Style::new())
  }
  if row == 1 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 1 {
    return filled(
      " ↑↓ pick · r restart · s stop · space pause the tail · esc quit",
      width, dim,
    )
  }
  let top = 2
  let bottom = height - 1
  let right_x = LIST_W + 1
  let right_w = width - right_x
  if right_w < 24 {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  // Detail above, log below: five rows for the one, the rest for the other.
  let detail_h = 7
  let left_part = if row == top {
    edge(
      LIST_W,
      true,
      "BOXES",
      self.boxes.length().to_string(),
      @strip.Strip::empty(),
    )
  } else if row == bottom - 1 {
    floor(LIST_W)
  } else if row > top && row < bottom - 1 {
    let index = row - top - 1
    if index >= self.boxes.length() {
      edge(
        LIST_W,
        false,
        "",
        "",
        @strip.Strip::blank(LIST_W - 2, @style.Style::new()),
      )
    } else {
      edge(LIST_W, false, "", "", self.row(index, LIST_W - 2))
    }
  } else {
    @strip.Strip::blank(LIST_W, @style.Style::new())
  }
  let item = self.boxes[self.pick]
  let rinner = right_w - 2
  let right_part = if row == top {
    edge(
      right_w,
      true,
      item.name,
      match item.state {
        Running => "running"
        Restarting => "restarting"
        Exited => "exited"
      },
      @strip.Strip::empty(),
    )
  } else if row == top + detail_h - 1 {
    floor(right_w)
  } else if row > top && row < top + detail_h - 1 {
    let line = match row - top - 1 {
      0 => "id     " + item.id
      1 => "image  " + item.image
      2 => "up     " + up_text(item.up)
      3 => "ports  " + item.ports
      _ => "cpu    " + item.cpu.to_string() + "%  ·  mem " + mem_text(item.mem)
    }
    edge(right_w, false, "", "", filled(line, rinner, ink))
  } else if row == top + detail_h {
    edge(
      right_w,
      true,
      "LOGS",
      if self.paused {
        "paused"
      } else {
        "tail"
      },
      @strip.Strip::empty(),
    )
  } else if row == bottom - 1 {
    floor(right_w)
  } else if row > top + detail_h && row < bottom - 1 {
    let room = bottom - 1 - (top + detail_h) - 1
    let lines = item.logs.length()
    let at = lines - room + (row - top - detail_h - 1)
    let body = if at >= 0 && at < lines {
      let (at_time, level, text) = item.logs[at]
      let style = if level == "error" {
        bad
      } else if level == "warn" {
        warn
      } else {
        ink
      }
      let tag = tag_style(level)
      @strip.Strip::join([
        @strip.Strip::of(at_time + " ", dim),
        @strip.Strip::of(right(level, 5) + " ", tag),
        @strip.Strip::of(cut(text, rinner - 15), style),
      ]).pad_to(rinner, @style.Style::new())
    } else {
      @strip.Strip::blank(rinner, @style.Style::new())
    }
    edge(right_w, false, "", "", body)
  } else {
    @strip.Strip::blank(right_w, @style.Style::new())
  }
  @strip.Strip::join([
    left_part,
    @strip.Strip::blank(1, @style.Style::new()),
    right_part,
  ]).pad_to(width, @style.Style::new())
}

///|
fn tag_style(level : String) -> @style.Style {
  if level == "error" {
    bad
  } else if level == "warn" {
    warn
  } else {
    dim
  }
}

///|
impl @widget.Widget for Host with fn hint(_self, _size) {
  @geom.Size::new(60, 16)
}

///|
impl @widget.Widget for Host with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Host with fn handle(self, ctx, msg) {
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
        Char(114) => {
          self.restart()
          ctx.repaint()
          true
        }
        Char(115) => {
          self.stop()
          ctx.repaint()
          true
        }
        Char(32) => {
          self.pause()
          ctx.repaint()
          true
        }
        _ => false
      }
    Tick(_) =>
      if self.paused {
        false
      } else {
        self.advance()
        ctx.repaint()
        true
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
  host : Host
}

///|
pub fn Screen::new() -> Screen {
  let host = Host::new()
  let root = @app.column(0, [
    @app.leaf(1, host, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, host, }
}
