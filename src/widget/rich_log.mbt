// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct RichLog {
  mut lines : Array[@strip.Strip]
  mut width : Int32
  max_lines : Int32?
  min_width : Int32
  mut wrap : Bool
  mut auto_scroll : Bool
  mut stick : Bool
  mut seen : Int32
  mut offset_x : Int32
  mut offset_y : Int32
  mut focused : Bool
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn RichLog::new(
  max_lines? : Int32,
  min_width~ : Int32 = 78,
  wrap~ : Bool = false,
  auto_scroll~ : Bool = true,
  style~ : @style.Style = @style.Style::new(),
) -> RichLog {
  {
    lines: [],
    width: 0,
    max_lines,
    min_width,
    wrap,
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
pub fn RichLog::lines(self : RichLog) -> Array[@strip.Strip] {
  self.lines
}

///|
pub fn RichLog::line_count(self : RichLog) -> Int32 {
  self.lines.length()
}

///|
pub fn RichLog::write(
  self : RichLog,
  text : String,
  style~ : @style.Style = @style.Style::new(),
  width? : Int32,
  scroll_end? : Bool,
) -> Unit {
  let was_end = self.at_end()
  let pieces = plain_lines(text)
  if pieces.length() == 0 {
    let at = width.unwrap_or(self.min_width)
    self.append(@strip.Strip::blank(at, style), at)
  } else {
    let natural = widest_of(pieces)
    let at = match width {
      Some(w) => w
      None => if natural > self.min_width { natural } else { self.min_width }
    }
    for piece in pieces {
      let rows = if self.wrap { wrap_text(piece, at) } else { [piece] }
      for row in rows {
        self.append(@strip.Strip::of(row, style), at)
      }
    }
  }
  self.prune()
  match scroll_end {
    Some(true) => self.stick = true
    Some(false) => self.stick = false
    None => self.stick = self.auto_scroll && was_end
  }
}

///|
pub fn RichLog::set_auto_scroll(self : RichLog, auto_scroll : Bool) -> Unit {
  self.auto_scroll = auto_scroll
}

///|
pub fn RichLog::set_wrap(self : RichLog, wrap : Bool) -> Unit {
  self.wrap = wrap
}

///|
pub fn RichLog::clear(self : RichLog) -> Unit {
  self.lines = []
  self.width = 0
  self.stick = true
  self.offset_x = 0
  self.offset_y = 0
}

///|
pub fn RichLog::offset(self : RichLog) -> (Int32, Int32) {
  (self.offset_x, self.offset_y)
}

///|
pub impl Widget for RichLog with fn render_line(self, row, size) {
  let max_y = if self.lines.length() - size.height < 0 {
    0
  } else {
    self.lines.length() - size.height
  }
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
  self.lines[y]
  .crop(self.offset_x, self.offset_x + size.width)
  .pad_to(size.width, self.style)
  .apply(self.style)
}

///|
pub impl Widget for RichLog with fn hint(self, _size) {
  @geom.Size::new(self.width, self.lines.length())
}

///|
pub impl Widget for RichLog with fn handle(self, ctx, msg) {
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
          self.scroll_by(-rich_step(ctx))
          ctx.repaint()
          true
        }
        PageDown => {
          self.scroll_by(rich_step(ctx))
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
pub impl Widget for RichLog with fn focusable(_self) {
  true
}

///|
fn rich_step(ctx : Ctx) -> Int32 {
  if ctx.size.height > 1 {
    ctx.size.height - 1
  } else {
    1
  }
}

///|
fn RichLog::scroll_by(self : RichLog, delta : Int32) -> Unit {
  self.stick = false
  self.offset_y = self.offset_y + delta
}

///|
fn RichLog::at_end(self : RichLog) -> Bool {
  if self.stick || self.seen <= 0 {
    return true
  }
  self.offset_y >= self.lines.length() - self.seen
}

///|
fn RichLog::append(self : RichLog, strip : @strip.Strip, width : Int32) -> Unit {
  self.lines.push(strip.pad_to(width, @style.Style::new()))
  if width > self.width {
    self.width = width
  }
}

///|
fn RichLog::prune(self : RichLog) -> Unit {
  match self.max_lines {
    None => ()
    Some(max) => {
      let drop = self.lines.length() - max
      if drop > 0 {
        let kept : Array[@strip.Strip] = []
        let count = self.lines.length()
        for i in drop..<count {
          kept.push(self.lines[i])
        }
        self.lines = kept
        let mut width = 0
        for line in self.lines {
          if line.cells > width {
            width = line.cells
          }
        }
        self.width = width
      }
    }
  }
}

///|
fn plain_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  for piece in split_ending(text) {
    out.push(piece.0)
  }
  out
}

///|
fn widest_of(pieces : Array[String]) -> Int32 {
  let mut widest = 0
  for piece in pieces {
    let cells = @strip.str_cells(piece)
    if cells > widest {
      widest = cells
    }
  }
  widest
}

///|
fn wrap_text(text : String, width : Int32) -> Array[String] {
  if width <= 1 || @strip.str_cells(text) <= width {
    return [text]
  }
  let out : Array[String] = []
  let mut remaining = text
  while @strip.str_cells(remaining) > width {
    let cut = @strip.cut_at(remaining, width)
    let mut last_space = -1
    let mut i = 0
    while i < cut {
      let (code, used) = @strip.code_at(remaining, i)
      if code == 32 {
        last_space = i
      }
      i = i + used
    }
    if last_space > 0 {
      out.push(remaining[0:last_space].to_owned())
      let mut after = last_space
      while after < remaining.length() {
        let (code, used) = @strip.code_at(remaining, after)
        if code != 32 {
          break
        }
        after = after + used
      }
      remaining = remaining[after:].to_owned()
    } else {
      out.push(remaining[0:cut].to_owned())
      remaining = remaining[cut:].to_owned()
    }
  }
  out.push(remaining)
  out
}

///|
pub extend RichLog with Debug::{to_repr}

///|
pub extend RichLog with Eq::{not_equal, equal}

///|
pub extend RichLog with Widget::{focusable, handle, hint, render_line}
