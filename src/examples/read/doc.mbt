// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A Markdown document, set the way a reader expects to find it: headings that
// dominate, bullets that indent, code that sits on its own plate, a quote with
// a rule down its side, and a table whose columns line up.

///|
/// 0 body, 1 title, 2 heading, 3 bullet, 4 code, 5 quote, 6 rule, 7 table.
let kinds : Array[Int32] = [
  1, 0, 0, 2, 0, 3, 3, 4, 4, 4, 0, 5, 0, 6, 0, 7, 7, 0, 2, 0, 3, 0,
]

///|
let lines : Array[String] = [
  "MoonBit Easy Terminal UI Frame", "", "A terminal toolkit for MoonBit: a cell buffer, a differential renderer, an",
  "incremental key parser, a CSS-like design system, and 55 widgets.", "", "What it is good at",
  "• one synchronous step per frame: poll, parse, dispatch, lay out, diff", "• the same code and the same tests on wasm, wasm-gc, js and native",
  "  moon run --target native src/examples/read/main", "  moon test --target all",
  "", "> A terminal program is a page that redraws itself; the renderer is only",
  "> the printer.", "", "────────────────────────────────────────────────────────────────────",
  "", "| widget   | cells | notes                    |", "| table    |   many | sorts, filters, pages    |",
  "", "Getting started", "", "• moon add moonbitstack/moonetui",
]

///|
pub struct Doc {
  mut top : Int32
  mut height : Int32
}

///|
pub fn Doc::new() -> Doc {
  { top: 0, height: 1, }
}

///|
pub fn Doc::lines() -> Int32 {
  lines.length()
}

///|
pub fn Doc::top(self : Doc) -> Int32 {
  self.top
}

///|
fn Doc::most(self : Doc) -> Int32 {
  let most = lines.length() - self.height
  if most < 0 {
    0
  } else {
    most
  }
}

///|
pub fn Doc::scroll(self : Doc, step : Int32) -> Unit {
  let next = self.top + step
  let most = self.most()
  self.top = if next < 0 { 0 } else if next > most { most } else { next }
}

///|
pub fn Doc::to_start(self : Doc) -> Unit {
  self.top = 0
}

///|
pub fn Doc::to_end(self : Doc) -> Unit {
  self.top = self.most()
}

///|
let title_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let head_style : @style.Style = @style.Style::new(
  fg=@theme.accent_alt,
  bold=true,
)

///|
let body_style : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let bullet_style : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let code_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let quote_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let dim_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn repeat(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
/// One line, set by its kind, and never wider than the page.
fn Doc::row(self : Doc, index : Int32, width : Int32) -> @strip.Strip {
  ignore(self)
  let text = lines[index]
  let kind = kinds[index]
  let (shown, style) = match kind {
    1 => (text, title_style)
    2 => ("▌ " + text, head_style)
    3 => ("  • " + text, bullet_style)
    4 => ("    " + text, code_style)
    5 => ("│ " + text, quote_style)
    6 => (repeat("─", if width > 2 { width - 1 } else { width }), dim_style)
    7 => (text, body_style)
    _ => (text, body_style)
  }
  @strip.Strip::of(shown, style)
}

///|
/// The scrollbar down the right edge: a track, and a thumb as tall as the part
/// of the document the page is showing.
fn Doc::bar(self : Doc, row : Int32, height : Int32) -> String {
  let most = self.most()
  if most == 0 || height <= 0 {
    return " "
  }
  let track = height
  let thumb = if lines.length() > 0 {
    let size = height * height / lines.length()
    if size < 1 {
      1
    } else {
      size
    }
  } else {
    1
  }
  let start = self.top * (track - thumb) / most
  if row >= start && row < start + thumb {
    "█"
  } else {
    "│"
  }
}

///|
impl @widget.Widget for Doc with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  self.height = height
  if width < 20 || height < 2 {
    return @strip.Strip::blank(width, @style.default)
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " " +
      self.top.to_string() +
      "–" +
      (if self.top + height - 1 < lines.length() {
        self.top + height - 1
      } else {
        lines.length()
      }).to_string() +
      " of " +
      lines.length().to_string() +
      " · ↑↓ scroll · g top · G end",
      dim_style,
    )
  }
  let index = self.top + row
  let page = width - 2
  let content = if index < lines.length() {
    self.row(index, page)
  } else {
    @strip.Strip::blank(page, @style.default)
  }
  @strip.Strip::join([
    content,
    @strip.Strip::blank(1, @style.default),
    @strip.Strip::of(self.bar(row, height - 1), dim_style),
  ])
}

///|
impl @widget.Widget for Doc with fn hint(_self, size) {
  @geom.Size::new(size.width, 18)
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
        Up => {
          self.scroll(-1)
          ctx.repaint()
          true
        }
        Down => {
          self.scroll(1)
          ctx.repaint()
          true
        }
        PageUp => {
          self.scroll(-(self.height - 2))
          ctx.repaint()
          true
        }
        PageDown => {
          self.scroll(self.height - 2)
          ctx.repaint()
          true
        }
        Char(103) => {
          self.to_start()
          ctx.repaint()
          true
        }
        Char(71) => {
          self.to_end()
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
