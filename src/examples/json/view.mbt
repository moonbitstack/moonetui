// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The document, drawn as a browser draws one: the path across the top, the keys
// with a marker that folds, the value in the colour of its type, and — when a
// query is open — everything it does not match pushed back to grey.

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let key_style : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let box_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let string_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let number_style : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let bool_style : @style.Style = @style.Style::new(
  fg=@theme.accent_alt,
  bold=true,
)

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
fn value_style(kind : String) -> @style.Style {
  if kind == "string" {
    string_style
  } else if kind == "number" {
    number_style
  } else if kind == "boolean" {
    bool_style
  } else {
    box_style
  }
}

///|
/// What the line says after its key: a string in quotes, a container as its
/// count, a number and a boolean as themselves.
fn value_text(node : Node) -> String {
  if node.kind == "string" {
    "\"" + node.text + "\""
  } else if node.kind == "object" || node.kind == "array" {
    "{" + node.text + "}"
  } else {
    node.text
  }
}

///|
fn Doc::row(self : Doc, index : Int32, width : Int32) -> @strip.Strip {
  let node = self.nodes[index]
  let here = index == self.cursor
  let folds = node.kind == "object" || node.kind == "array"
  let marker = if folds {
    if node.open {
      "▾ "
    } else {
      "▸ "
    }
  } else {
    "  "
  }
  let lit = self.matches(node)
  // Every value starts at the same column, so a reader can run down them.
  let used = node.depth * 2 + 2 + @strip.str_cells(node.key)
  let gap = if node.key.length() == 0 {
    1
  } else if 24 > used {
    24 - used
  } else {
    1
  }
  let room = width - used - gap
  @strip.Strip::join([
    @strip.Strip::blank(node.depth * 2, @style.Style::new()),
    @strip.Strip::of(marker, if lit { box_style } else { dim }),
    @strip.Strip::of(
      if node.key.length() == 0 {
        ""
      } else {
        node.key
      },
      if !lit {
        dim
      } else if here {
        ink
      } else {
        key_style
      },
    ),
    @strip.Strip::blank(gap, @style.Style::new()),
    @strip.Strip::of(
      cut(value_text(node), if room > 0 { room } else { 4 }),
      if lit {
        value_style(node.kind)
      } else {
        dim
      },
    ),
  ]).pad_to(width, if here { picked } else { @style.Style::new() })
}

///|
impl @widget.Widget for Doc with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    let band = @strip.Strip::of(" {} JSON", box_style)
    let stats = @strip.Strip::of(
      "payload.json  ·  " +
      self.nodes.length().to_string() +
      " lines  ·  4.1 kb  ·  utf-8 ",
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
    let head = @strip.Strip::of(" path  ", dim)
    let path = @strip.Strip::of(self.path(), box_style)
    let tail = @strip.Strip::of(
      right(
        (self.cursor + 1).to_string() +
        " of " +
        self.visible().length().to_string() +
        " ",
        14,
      ),
      dim,
    )
    let fill = width -
      head.cell_length() -
      path.cell_length() -
      tail.cell_length()
    return @strip.Strip::join([
      head,
      path,
      @strip.Strip::blank(if fill > 0 { fill } else { 0 }, @style.Style::new()),
      tail,
    ]).pad_to(width, @style.Style::new())
  }
  if row == 2 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 2 {
    let node = self.at()
    return @strip.Strip::join([
      @strip.Strip::of(
        " " +
        label(node) +
        "  ·  " +
        node.kind +
        "  ·  " +
        node.text +
        "  ·  ",
        dim,
      ),
      @strip.Strip::of(self.note, if self.typing { bool_style } else { dim }),
    ]).pad_to(width, @style.Style::new())
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " ← fold · ↑↓ move · / find · enter keeps it · esc clears or quits ",
      dim,
    ).pad_to(width, @style.Style::new())
  }
  let top = 3
  let rows = height - 5
  let space = self.visible()
  let offset = {
    let mut first = 0
    let mut at = 0
    let mut i = 0
    while i < space.length() {
      if space[i] == self.cursor {
        at = i
      }
      i = i + 1
    }
    if at >= rows - 1 {
      first = at - rows + 2
    }
    first
  }
  let index = offset + row - top
  if row < top || row >= top + rows {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let wide = width > 62
  let left_w = if wide { 46 } else { width }
  let line = if index < space.length() {
    self.row(space[index], left_w)
  } else {
    @strip.Strip::blank(left_w, @style.Style::new())
  }
  if !wide {
    return line
  }
  return @strip.Strip::join([
    line,
    @strip.Strip::blank(1, @style.Style::new()),
    self.detail_row(row - top, width - left_w - 1, rows),
  ]).pad_to(width, @style.Style::new())
}

///|
/// The pane on the right, carried over from the tree example: what the node
/// under the cursor is, what it holds, and where it is in the document.
fn Doc::detail_row(
  self : Doc,
  at : Int32,
  dw : Int32,
  dh : Int32,
) -> @strip.Strip {
  let node = self.at()
  let inner = dw - 4
  if at == 0 {
    let head = "╭─ " + label(node) + " "
    let fill = dw - 1 - @strip.str_cells(head)
    return @strip.Strip::join([
      @strip.Strip::of(head, box_style),
      @strip.Strip::of(
        rule(if fill > 0 { fill } else { 0 }) + "╮",
        frame_style,
      ),
    ]).pad_to(dw, @style.Style::new())
  }
  if at == dh - 1 {
    return @strip.Strip::of("╰" + rule(dw - 2) + "╯", frame_style)
  }
  if at == 1 {
    let held = if node.kind == "object" || node.kind == "array" {
      node.kind + "  ·  " + node.text
    } else {
      node.kind
    }
    return @strip.Strip::join([
      @strip.Strip::of("│ ", frame_style),
      @strip.Strip::of(cut(held, inner), dim).pad_to(inner, @style.Style::new()),
      @strip.Strip::of(" │", frame_style),
    ])
  }
  if at == dh - 2 {
    return @strip.Strip::join([
      @strip.Strip::of("│ ", frame_style),
      @strip.Strip::of(cut(self.path(), inner), dim).pad_to(
        inner,
        @style.Style::new(),
      ),
      @strip.Strip::of(" │", frame_style),
    ])
  }
  // The rest is what the node holds: its children, or its own value.
  let body = if node.kind == "object" || node.kind == "array" {
    let kids = self.children()
    let slot = at - 2
    if slot < kids.length() {
      let kid = kids[slot]
      @strip.Strip::join([
        @strip.Strip::of(cut(kid.key, 14), ink),
        @strip.Strip::blank(
          if 14 > @strip.str_cells(kid.key) {
            14 - @strip.str_cells(kid.key)
          } else {
            1
          },
          @style.Style::new(),
        ),
        @strip.Strip::of(
          cut(value_text(kid), inner - 15),
          value_style(kid.kind),
        ),
      ]).pad_to(inner, @style.Style::new())
    } else if slot == kids.length() && kids.length() > 0 {
      @strip.Strip::of("…", dim).pad_to(inner, @style.Style::new())
    } else {
      @strip.Strip::blank(inner, @style.Style::new())
    }
  } else if at == 3 {
    @strip.Strip::of(cut(value_text(node), inner), value_style(node.kind)).pad_to(
      inner,
      @style.Style::new(),
    )
  } else {
    @strip.Strip::blank(inner, @style.Style::new())
  }
  @strip.Strip::join([
    @strip.Strip::of("│ ", frame_style),
    body,
    @strip.Strip::of(" │", frame_style),
  ])
}

///|
/// The nodes directly under the cursor, in the order they are written.
fn Doc::children(self : Doc) -> Array[Node] {
  let out : Array[Node] = []
  let depth = self.nodes[self.cursor].depth
  let mut i = self.cursor + 1
  while i < self.nodes.length() && self.nodes[i].depth > depth {
    if self.nodes[i].depth == depth + 1 {
      out.push(self.nodes[i])
    }
    i = i + 1
  }
  out
}

///|
impl @widget.Widget for Doc with fn hint(_self, _size) {
  @geom.Size::new(52, 14)
}

///|
impl @widget.Widget for Doc with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Doc with fn handle(self, ctx, msg) {
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
            ctx.repaint()
            return true
          }
          false
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
        Left => {
          self.fold()
          ctx.repaint()
          true
        }
        Enter =>
          if self.typing {
            self.settle()
            ctx.repaint()
            true
          } else {
            self.fold()
            ctx.repaint()
            true
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
  doc : Doc
}

///|
pub fn Screen::new() -> Screen {
  let doc = Doc::new()
  let root = @app.column(0, [
    @app.leaf(1, doc, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, doc, }
}
