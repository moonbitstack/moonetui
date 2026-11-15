// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A JSON document as a tree on the left and the selected node on the right.
// The document is fixed, so the example needs no parser and a frame test sees
// the same indentation twice.

///|
pub(all) struct Item {
  depth : Int32
  parent : Int32
  key : String
  value : String
  kind : Int32
}

///|
/// 0 is a string, 1 a number, 2 a keyword, 3 a container.
fn item(
  depth : Int32,
  parent : Int32,
  key : String,
  value : String,
  kind : Int32,
) -> Item {
  { depth, parent, key, value, kind, }
}

///|
fn document() -> Array[Item] {
  [
    item(0, -1, "", "{", 3),
    item(1, 0, "name", "\"moonetui\"", 0),
    item(1, 0, "version", "0.4.0", 1),
    item(1, 0, "stable", "true", 2),
    item(1, 0, "targets", "[3]", 3),
    item(2, 4, "0", "\"wasm-gc\"", 0),
    item(2, 4, "1", "\"js\"", 0),
    item(2, 4, "2", "\"native\"", 0),
    item(1, 0, "features", "{4}", 3),
    item(2, 8, "renderer", "\"differential\"", 0),
    item(2, 8, "widgets", "55", 1),
    item(2, 8, "backends", "4", 1),
    item(2, 8, "license", "\"Apache-2.0\"", 0),
    item(1, 0, "notes", "null", 2),
  ]
}

///|
pub struct Tree {
  entries : Array[Item]
  folded : Array[Bool]
  mut at : Int32
}

///|
pub fn Tree::new() -> Tree {
  let entries = document()
  let folded : Array[Bool] = []
  for _ in 0..<entries.length() {
    folded.push(false)
  }
  { entries, folded, at: 0, }
}

///|
/// Whether a node is hidden because something above it is folded.
fn Tree::hidden(self : Tree, index : Int32) -> Bool {
  let mut parent = self.entries[index].parent
  while parent >= 0 {
    if self.folded[parent] {
      return true
    }
    parent = self.entries[parent].parent
  }
  false
}

///|
fn Tree::visible(self : Tree) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in 0..<self.entries.length() {
    if !self.hidden(i) {
      out.push(i)
    }
  }
  out
}

///|
/// The selected node's key, which is what a test reads.
pub fn Tree::selection(self : Tree) -> String {
  let rows = self.visible()
  if rows.length() == 0 {
    return ""
  }
  let at = if self.at < rows.length() { self.at } else { rows.length() - 1 }
  let node = self.entries[rows[at]]
  if node.key == "" {
    "(root)"
  } else {
    node.key
  }
}

///|
pub fn Tree::rows_visible(self : Tree) -> Int32 {
  self.visible().length()
}

///|
pub fn Tree::shift(self : Tree, step : Int32) -> Unit {
  let rows = self.visible()
  let next = self.at + step
  if next >= 0 && next < rows.length() {
    self.at = next
  }
}

///|
/// Fold or open the node the cursor is on. A value has nothing to fold.
pub fn Tree::toggle(self : Tree) -> Unit {
  let rows = self.visible()
  if self.at < 0 || self.at >= rows.length() {
    return
  }
  let index = rows[self.at]
  if self.entries[index].kind != 3 {
    return
  }
  self.folded[index] = !self.folded[index]
}

///|
let key_style : @style.Style = @style.Style::new(fg=@theme.accent_alt)

///|
let string_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let number_style : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let keyword_style : @style.Style = @style.Style::new(fg=@theme.bad)

///|
let dim_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let picked_style : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.accent,
  bold=true,
)

///|
let title_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn repeat(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
fn value_style(kind : Int32) -> @style.Style {
  if kind == 0 {
    string_style
  } else if kind == 1 {
    number_style
  } else if kind == 2 {
    keyword_style
  } else {
    key_style
  }
}

///|
/// One row of the left pane: guides, an expander, a key and a value.
fn Tree::entry_row(
  self : Tree,
  index : Int32,
  width : Int32,
  picked : Bool,
) -> @strip.Strip {
  let node = self.entries[index]
  let guide = repeat("  ", node.depth)
  let expander = if node.kind == 3 {
    if self.folded[index] {
      "▸ "
    } else {
      "▾ "
    }
  } else {
    "  "
  }
  let key = if node.key == "" { "" } else { node.key + ": " }
  let parts : Array[@strip.Strip] = [
    @strip.Strip::of(guide + expander, dim_style),
    @strip.Strip::of(key, if picked { picked_style } else { key_style }),
    @strip.Strip::of(
      node.value,
      if picked {
        picked_style
      } else {
        value_style(node.kind)
      },
    ),
  ]
  let line = @strip.Strip::join(parts)
  if picked {
    // The highlight runs to the edge of the pane, so a row reads as one block.
    let used = @strip.str_cells(guide) +
      @strip.str_cells(expander) +
      @strip.str_cells(key) +
      @strip.str_cells(node.value)
    if used < width {
      return @strip.Strip::join([
        line,
        @strip.Strip::blank(width - used, picked_style),
      ])
    }
  }
  line
}

///|
impl @widget.Widget for Tree with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 40 {
    return @strip.Strip::blank(width, @style.default)
  }
  let left_width = width * 56 / 100
  let right_width = width - left_width - 2
  let rows = self.visible()
  if row == 0 {
    return @strip.Strip::join([
      @strip.Strip::of(" tree", @style.Style::new(fg=@theme.accent, bold=true)),
      @strip.Strip::of("  ↑↓ move · space fold · esc quit", title_style),
    ])
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " " +
      self.entries.length().to_string() +
      " nodes · " +
      rows.length().to_string() +
      " shown",
      title_style,
    )
  }
  let body = row - 1
  let left = if body < rows.length() {
    self.entry_row(rows[body], left_width, body == self.at)
  } else {
    @strip.Strip::blank(left_width, @style.Style::new())
  }
  // The right pane: the path of the selected node, and what it holds.
  let right = if body == 0 {
    let at = if self.at < rows.length() {
      self.entries[rows[self.at]]
    } else {
      self.entries[0]
    }
    @strip.Strip::join([
      @strip.Strip::of(" selected", title_style),
      @strip.Strip::of("  depth " + at.depth.to_string(), dim_style),
    ])
  } else if body == 2 {
    let at = if self.at < rows.length() {
      self.entries[rows[self.at]]
    } else {
      self.entries[0]
    }
    @strip.Strip::join([
      @strip.Strip::of(
        " " + (if at.key == "" { "(root)" } else { at.key }),
        key_style,
      ),
      @strip.Strip::of("  ", dim_style),
      @strip.Strip::of(at.value, value_style(at.kind)),
    ])
  } else {
    @strip.Strip::blank(right_width, @style.Style::new())
  }
  @strip.Strip::join([left, @strip.Strip::blank(2, @style.Style::new()), right])
}

///|
impl @widget.Widget for Tree with fn hint(_self, size) {
  @geom.Size::new(size.width, 16)
}

///|
impl @widget.Widget for Tree with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Tree with fn handle(self, ctx, msg) {
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
        Char(32) => {
          self.toggle()
          ctx.repaint()
          true
        }
        Right => {
          if self.at >= 0 && self.at < self.visible().length() {
            let index = self.visible()[self.at]
            self.folded[index] = false
          }
          ctx.repaint()
          true
        }
        Left => {
          if self.at >= 0 && self.at < self.visible().length() {
            let index = self.visible()[self.at]
            self.folded[index] = true
          }
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
  tree : Tree
}

///|
pub fn Screen::new() -> Screen {
  let tree = Tree::new()
  let root = @app.column(0, [
    @app.leaf(1, tree, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, tree, }
}
