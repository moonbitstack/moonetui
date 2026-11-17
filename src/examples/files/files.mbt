// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A browser in Miller columns: where a reader is on the left, what is in it in
// the middle, what the selection holds on the right. The tree is fixed, so the
// example needs no disk and a frame test sees the same three columns twice.

///|
let names : Array[String] = [
  "src", "docs", "moon.mod", "app", "widgets", "main.mbt", "README.md", "guide.md",
  "list.mbt", "table.mbt",
]

///|
/// The parent of each entry; -1 is the top.
let parents : Array[Int32] = [-1, -1, -1, 0, 0, 0, 1, 1, 4, 4]

///|
let is_dir : Array[Bool] = [
  true, true, false, true, true, false, false, false, false, false,
]

///|
pub struct Files {
  /// The directories opened, outermost first.
  path : Array[Int32]
  /// Where the cursor sits in the rightmost column.
  mut at : Int32
}

///|
pub fn Files::new() -> Files {
  { path: [], at: 0, }
}

///|
fn children_of(index : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in 0..<names.length() {
    if parents[i] == index {
      out.push(i)
    }
  }
  out
}

///|
fn Files::here(self : Files) -> Int32 {
  if self.path.length() == 0 {
    -1
  } else {
    self.path[self.path.length() - 1]
  }
}

///|
fn Files::rows(self : Files) -> Array[Int32] {
  children_of(self.here())
}

///|
/// The name a reader's cursor is on, which is what a test reads.
pub fn Files::selection(self : Files) -> String {
  let rows = self.rows()
  if rows.length() == 0 {
    return ""
  }
  let at = if self.at < rows.length() { self.at } else { rows.length() - 1 }
  let name = names[rows[at]]
  if is_dir[rows[at]] {
    name + "/"
  } else {
    name
  }
}

///|
pub fn Files::depth(self : Files) -> Int32 {
  self.path.length()
}

///|
fn Files::shift(self : Files, step : Int32) -> Unit {
  let rows = self.rows()
  if rows.length() == 0 {
    return
  }
  let next = self.at + step
  if next >= 0 && next < rows.length() {
    self.at = next
  }
}

///|
fn Files::enter(self : Files) -> Unit {
  let rows = self.rows()
  if self.at < 0 || self.at >= rows.length() {
    return
  }
  let index = rows[self.at]
  if is_dir[index] {
    self.path.push(index)
    self.at = 0
  }
}

///|
fn Files::up(self : Files) -> Unit {
  if self.path.length() == 0 {
    return
  }
  ignore(self.path.pop())
  self.at = 0
}

///|
/// The entry's full path, for the line at the top of the screen.
fn Files::trail(self : Files) -> String {
  let out = StringBuilder()
  out.write_string("/")
  for index in self.path {
    out.write_string(names[index] + "/")
  }
  out.to_string()
}

///|
let dir_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let file_style : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|

///|
fn repeat(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
/// One column, one row of it: nothing where the column is shorter than the row.
fn column_row(
  list : Array[Int32],
  body : Int32,
  width : Int32,
  cursor : Int32,
  live : Bool,
) -> @strip.Strip {
  if body < 0 || body >= list.length() {
    return @strip.Strip::blank(width, dim_style)
  }
  let index = list[body]
  let text = if is_dir[index] { names[index] + "/" } else { names[index] }
  let pad = width - @strip.str_cells(text)
  let line = if pad > 0 { text + repeat(" ", pad) } else { text }
  // A column the cursor is not in is dimmer than the one it is: the eye reads
  // where it is before it reads what is there.
  let style = if live && body == cursor {
    @theme.cursor
  } else if !live {
    @theme.quiet
  } else if is_dir[index] {
    dir_style
  } else {
    file_style
  }
  if live && body == cursor {
    return @strip.Strip::join([
      @strip.Strip::of("▌", @theme.marker),
      @strip.Strip::of(line, style).pad_to(width - 1, style),
    ]).crop(0, width)
  }
  @strip.Strip::of(line, style)
}

///|
impl @widget.Widget for Files with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 30 {
    return @strip.Strip::blank(width, @style.default)
  }
  if row == 0 {
    return @theme.band(
      "moonetui",
      subject="files",
      note="moonetui" + self.trail(),
      width~,
    )
  }
  if row == 1 {
    return @theme.rule(width~)
  }
  if row == height - 1 {
    return @theme.keys(
      [("↑↓", "move"), ("→", "enter"), ("←", "up"), ("q", "quit")],
      width~,
    )
  }
  // Miller columns: where the reader came from, what is here, what the
  // selection holds. A column that has nothing to show is not drawn, so the
  // root of a tree is two columns at the left edge and not two columns pushed
  // along by an empty one.
  let here = self.here()
  let up = if self.path.length() > 0 { parents[here] } else { -2 }
  let rows = children_of(here)
  let picked = if self.at < rows.length() { rows[self.at] } else { -1 }
  let body = row - 2
  let left : Array[Int32] = if self.path.length() > 0 {
    children_of(up)
  } else {
    []
  }
  let left_cursor = if self.path.length() > 0 {
    self.path[self.path.length() - 1]
  } else {
    -1
  }
  let right = if picked >= 0 && is_dir[picked] {
    children_of(picked)
  } else {
    []
  }
  let mut left_index = -1
  for i in 0..<left.length() {
    if left[i] == left_cursor {
      left_index = i
    }
  }
  let columns = if left_index >= 0 { 3 } else { 2 }
  let gap = 3
  let column_width = (width - gap * (columns - 1)) / columns
  let gap_strip = @strip.Strip::join([@strip.Strip::of("│ ", @theme.edge)])
  let parts : Array[@strip.Strip] = []
  if left_index >= 0 {
    parts.push(column_row(left, left_index, column_width, -1, false))
    parts.push(gap_strip)
  }
  parts.push(column_row(rows, body, column_width, self.at, true))
  if columns == 3 || right.length() > 0 {
    parts.push(gap_strip)
    parts.push(column_row(right, body, column_width, -1, false))
  }
  @strip.Strip::join(parts).crop(0, width).pad_to(width, @style.Style::new())
}

///|
impl @widget.Widget for Files with fn hint(_self, _size) {
  @geom.Size::new(90, 18)
}

///|
impl @widget.Widget for Files with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Files with fn handle(self, ctx, msg) {
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
        Right | Enter => {
          self.enter()
          ctx.repaint()
          true
        }
        Left | Backspace => {
          self.up()
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
  files : Files
}

///|
pub fn Screen::new() -> Screen {
  let files = Files::new()
  let root = @app.column(0, [
    @app.leaf(1, files, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, files, }
}
