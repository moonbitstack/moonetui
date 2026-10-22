// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Log {
  mut lines : Array[String]
  mut width : Int32
  max_lines : Int32?
  mut auto_scroll : Bool
  mut stick : Bool
  mut seen : Int32
  mut offset_x : Int32
  mut offset_y : Int32
  mut focused : Bool
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Log::new(
  max_lines? : Int32,
  auto_scroll~ : Bool = true,
  style~ : @style.Style = @style.Style::new(),
) -> Log {
  {
    lines: [],
    width: 0,
    max_lines,
    auto_scroll,
    stick: true,
    seen: 0,
    offset_x: 0,
    offset_y: 0,
    focused: false,
    style,
  }
}

///|
pub fn Log::lines(self : Log) -> Array[String] {
  self.lines
}

///|
pub fn Log::line_count(self : Log) -> Int32 {
  let n = self.lines.length()
  if n > 0 && self.lines[n - 1] == "" {
    n - 1
  } else {
    n
  }
}

///|
pub fn Log::write(self : Log, data : String, scroll_end? : Bool) -> Unit {
  let was_end = self.at_end()
  if data.length() > 0 {
    if self.lines.length() == 0 {
      self.lines.push("")
    }
    for piece in split_ending(data) {
      let last = self.lines.length() - 1
      self.lines[last] = self.lines[last] + piece.0
      let cells = @strip.str_cells(process_line(self.lines[last]))
      if cells > self.width {
        self.width = cells
      }
      if piece.1 {
        self.lines.push("")
      }
    }
  }
  self.prune()
  self.follow(scroll_end, was_end)
}

///|
pub fn Log::write_line(self : Log, line : String, scroll_end? : Bool) -> Unit {
  self.write_lines([line], scroll_end?)
}

///|
pub fn Log::write_lines(
  self : Log,
  lines : Array[String],
  scroll_end? : Bool,
) -> Unit {
  let was_end = self.at_end()
  for line in lines {
    for piece in split_ending(line) {
      self.lines.push(piece.0)
      let cells = @strip.str_cells(process_line(piece.0))
      if cells > self.width {
        self.width = cells
      }
    }
  }
  self.prune()
  self.follow(scroll_end, was_end)
}

///|
pub fn Log::clear(self : Log) -> Unit {
  self.lines = []
  self.width = 0
  self.stick = true
  self.offset_x = 0
  self.offset_y = 0
}

///|
pub fn Log::set_auto_scroll(self : Log, auto_scroll : Bool) -> Unit {
  self.auto_scroll = auto_scroll
}

///|
pub fn Log::offset(self : Log) -> (Int32, Int32) {
  (self.offset_x, self.offset_y)
}

///|
pub impl Widget for Log with fn render_line(self, row, size) {
  let count = self.line_count()
  let max_y = if count - size.height < 0 { 0 } else { count - size.height }
  self.seen = size.height
  if self.stick {
    self.offset_y = max_y
  }
  self.offset_y = clamp(self.offset_y, 0, max_y)
  if !self.stick && self.offset_y >= max_y {
    self.stick = true
  }
  let max_x = if self.width - size.width < 0 {
    0
  } else {
    self.width - size.width
  }
  self.offset_x = clamp(self.offset_x, 0, max_x)
  let y = self.offset_y + row
  if size.width <= 0 || y < 0 || y >= self.lines.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  @strip.Strip::of(process_line(self.lines[y]), self.style)
  .crop(self.offset_x, self.offset_x + size.width)
  .pad_to(size.width, self.style)
}

///|
pub impl Widget for Log with fn hint(self, _size) {
  @geom.Size::new(self.width, self.line_count())
}

///|
pub impl Widget for Log with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => {
      if !key.mods.is_none() {
        return false
      }
      match key.code {
        Up => {
          self.scroll_by(-1)
          ctx.repaint()
          true
        }
        Down => {
          self.scroll_by(1)
          ctx.repaint()
          true
        }
        PageUp => {
          self.scroll_by(-step(ctx))
          ctx.repaint()
          true
        }
        PageDown => {
          self.scroll_by(step(ctx))
          ctx.repaint()
          true
        }
        Home => {
          self.offset_y = 0
          self.stick = false
          ctx.repaint()
          true
        }
        End => {
          self.stick = true
          ctx.repaint()
          true
        }
        Left => {
          self.offset_x = self.offset_x - 1
          ctx.repaint()
          true
        }
        Right => {
          self.offset_x = self.offset_x + 1
          ctx.repaint()
          true
        }
        _ => false
      }
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          true
        }
        ScrollUp => {
          self.scroll_by(-1)
          ctx.repaint()
          true
        }
        ScrollDown => {
          self.scroll_by(1)
          ctx.repaint()
          true
        }
        ScrollLeft => {
          self.offset_x = self.offset_x - 1
          ctx.repaint()
          true
        }
        ScrollRight => {
          self.offset_x = self.offset_x + 1
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Log with fn focusable(_self) {
  true
}

///|
fn step(ctx : Ctx) -> Int32 {
  if ctx.size.height > 1 {
    ctx.size.height - 1
  } else {
    1
  }
}

///|
fn Log::scroll_by(self : Log, delta : Int32) -> Unit {
  self.stick = false
  self.offset_y = self.offset_y + delta
}

///|
fn Log::at_end(self : Log) -> Bool {
  if self.stick || self.seen <= 0 {
    return true
  }
  self.offset_y >= self.line_count() - self.seen
}

///|
fn Log::follow(self : Log, scroll_end : Bool?, was_end : Bool) -> Unit {
  match scroll_end {
    Some(true) => self.stick = true
    Some(false) => self.stick = false
    None => self.stick = self.auto_scroll && was_end
  }
}

///|
fn Log::prune(self : Log) -> Unit {
  match self.max_lines {
    None => ()
    Some(max) => {
      let drop = self.lines.length() - max
      if drop > 0 {
        let kept : Array[String] = []
        let count = self.lines.length()
        for i in drop..<count {
          kept.push(self.lines[i])
        }
        self.lines = kept
        self.rescan_width()
      }
    }
  }
}

///|
fn Log::rescan_width(self : Log) -> Unit {
  let mut width = 0
  for line in self.lines {
    let cells = @strip.str_cells(process_line(line))
    if cells > width {
      width = cells
    }
  }
  self.width = width
}

///|
fn process_line(line : String) -> String {
  let out = StringBuilder()
  let mut column = 0
  let mut i = 0
  while i < line.length() {
    let (code, used) = @strip.code_at(line, i)
    if code == 9 {
      let step = 8 - column % 8
      for _ in 0..<step {
        out.write_char(' ')
      }
      column = column + step
    } else if code <= 0x14 {
      out.write_char('\u{FFFD}')
      column = column + 1
    } else {
      out.write_string(line[i:i + used].to_owned())
      column = column + @strip.cell_width(code)
    }
    i = i + used
  }
  out.to_string()
}

///|
fn split_ending(data : String) -> Array[(String, Bool)] {
  let out : Array[(String, Bool)] = []
  let mut start = 0
  let mut prev = -1
  let mut i = 0
  while i < data.length() {
    let (code, used) = @strip.code_at(data, i)
    if code == 10 {
      let end = if prev == 13 { i - 1 } else { i }
      out.push((data[start:end].to_owned(), true))
      i = i + used
      start = i
    } else {
      i = i + used
    }
    prev = code
  }
  if start < data.length() {
    out.push((data[start:].to_owned(), false))
  }
  out
}

///|
pub extend Log with Debug::{to_repr}

///|
pub extend Log with Eq::{not_equal, equal}

///|
pub extend Log with Widget::{focusable, handle, hint, render_line}
