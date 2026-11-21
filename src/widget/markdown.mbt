// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
#derive(Eq, Debug)
pub struct Markdown {
  mut source : String
  mut laid : Array[@strip.Strip]
  mut laid_width : Int32
  mut dirty : Bool
  mut offset_y : Int32
  mut seen : Int32
  style : @style.Style
  heading_style : @style.Style
  code_style : @style.Style
  quote_style : @style.Style
  rule_style : @style.Style
}

///|
pub extend Markdown with Debug::{to_repr}

///|
pub extend Markdown with Eq::{not_equal, equal}

///|
pub fn Markdown::new(
  text : String,
  style~ : @style.Style = @style.Style::new(),
  heading_style~ : @style.Style = @style.Style::new(bold=true),
  code_style~ : @style.Style = @style.Style::new(fg=@style.cyan),
  quote_style~ : @style.Style = @style.Style::new(italic=true),
  rule_style~ : @style.Style = @style.Style::new(dim=true),
) -> Markdown {
  {
    source: text,
    laid: [],
    laid_width: -1,
    dirty: true,
    offset_y: 0,
    seen: 0,
    style,
    heading_style,
    code_style,
    quote_style,
    rule_style,
  }
}

///|
pub fn Markdown::update(self : Markdown, text : String) -> Unit {
  self.source = text
  self.dirty = true
  self.offset_y = 0
}

///|
pub fn Markdown::text(self : Markdown) -> String {
  self.source
}

///|
fn md_cell_strip(
  segs : Array[@strip.Seg],
  width : Int32,
  align : Align,
  style : @style.Style,
) -> @strip.Strip {
  let body = @strip.Strip::from_segs(segs)
  let used = body.cell_length()
  if used >= width {
    return body.crop(0, width)
  }
  let mut left = 0
  let rest = width - used
  match align {
    Left => left = 0
    Right => left = rest
    Centre => left = rest / 2
  }
  @strip.Strip::join([
    @strip.Strip::blank(left, style),
    body,
    @strip.Strip::blank(rest - left, style),
  ])
}

///|
fn Markdown::lay_table(
  self : Markdown,
  aligns : Array[Align],
  head : Array[String],
  rows : Array[Array[String]],
  _width : Int32,
  out : Array[@strip.Strip],
) -> Unit {
  let mut span = head.length()
  for cells in rows {
    if cells.length() > span {
      span = cells.length()
    }
  }
  let widths : Array[Int32] = []
  for _ in 0..<span {
    widths.push(0)
  }
  for i in 0..<span {
    let mut wide = if i < head.length() { @strip.str_cells(head[i]) } else { 0 }
    for cells in rows {
      if i < cells.length() {
        let used = @strip.str_cells(cells[i])
        if used > wide {
          wide = used
        }
      }
    }
    if wide < 1 {
      wide = 1
    }
    widths[i] = wide
  }
  let head_style = self.style.merge(self.heading_style)
  let head_pieces : Array[@strip.Strip] = []
  for i in 0..<span {
    if i > 0 {
      head_pieces.push(@strip.Strip::of("│", head_style))
    }
    let label = if i < head.length() { head[i] } else { "" }
    head_pieces.push(
      @strip.Strip::join([
        @strip.Strip::blank(1, head_style),
        md_cell_strip(
          [@strip.Seg::new(label, head_style)],
          widths[i],
          Left,
          head_style,
        ),
        @strip.Strip::blank(1, head_style),
      ]),
    )
  }
  out.push(@strip.Strip::join(head_pieces))
  let rule = StringBuilder()
  for i in 0..<span {
    if i > 0 {
      rule.write_string("┼")
    }
    let mut dashes = widths[i] + 2
    while dashes > 0 {
      rule.write_string("─")
      dashes = dashes - 1
    }
  }
  out.push(@strip.Strip::of(rule.to_string(), self.rule_style))
  for cells in rows {
    let pieces : Array[@strip.Strip] = []
    for i in 0..<span {
      if i > 0 {
        pieces.push(@strip.Strip::of("│", self.style))
      }
      let plain = if i < cells.length() { cells[i] } else { "" }
      let align = if i < aligns.length() { aligns[i] } else { Left }
      pieces.push(
        @strip.Strip::join([
          @strip.Strip::blank(1, self.style),
          md_cell_strip(
            md_inline(plain, self.style),
            widths[i],
            align,
            self.style,
          ),
          @strip.Strip::blank(1, self.style),
        ]),
      )
    }
    out.push(@strip.Strip::join(pieces))
  }
}

///|
fn md_is_list(flow : MDFlow) -> Bool {
  match flow {
    MDBullet(_, _) | MDNumbered(_, _, _) => true
    _ => false
  }
}

///|
/// A list item: the marker on its first line, the rest indented under it.
fn Markdown::lay_item(
  self : Markdown,
  marker : String,
  text : String,
  width : Int32,
  out : Array[@strip.Strip],
) -> Unit {
  let indent = @strip.str_cells(marker)
  let lines = md_wrap(text, @cmp.maximum(1, width - indent), self.style)
  for i, line in lines {
    let lead = if i == 0 { marker } else { " ".repeat(indent) }
    out.push(@strip.Strip::join([@strip.Strip::of(lead, self.style), line]))
  }
}

///|
fn Markdown::lay(self : Markdown, width : Int32) -> Unit {
  let blocks = md_parse(self.source)
  let safe = if width < 4 { 4 } else { width }
  let out : Array[@strip.Strip] = []
  let total = blocks.length()
  let mut at = 0
  while at < total {
    let flow = blocks[at]
    if at > 0 && !(md_is_list(blocks[at - 1]) && md_is_list(flow)) {
      out.push(@strip.Strip::blank(safe, self.style))
    }
    match flow {
      MDHeading(level, text) => {
        let style = if level == 1 {
          self.heading_style.merge(@style.Style::new(underline=true))
        } else {
          self.heading_style
        }
        out.append(md_wrap(text, safe, self.style.merge(style)))
      }
      MDParagraph(text) => out.append(md_wrap(text, safe, self.style))
      MDQuote(text) =>
        for line in md_wrap(text, safe - 2, self.quote_style) {
          out.push(
            @strip.Strip::join([
              @strip.Strip::of("▌ ", self.quote_style),
              line,
            ]),
          )
        }
      MDBullet(depth, text) =>
        self.lay_item(md_marker(depth, true, 0), text, safe, out)
      MDNumbered(depth, number, text) =>
        self.lay_item(md_marker(depth, false, number), text, safe, out)
      MDCode(code) =>
        for line in code {
          out.push(@strip.Strip::of(line, self.code_style))
        }
      MDRule => {
        let bar = StringBuilder()
        let mut dashes = safe
        while dashes > 0 {
          bar.write_string("─")
          dashes = dashes - 1
        }
        out.push(@strip.Strip::of(bar.to_string(), self.rule_style))
      }
      MDTable(aligns, head, rows) =>
        self.lay_table(aligns, head, rows, safe, out)
    }
    at = at + 1
  }
  self.laid = out
  self.laid_width = width
  self.dirty = false
}

///|
fn Markdown::ensure(self : Markdown, width : Int32) -> Unit {
  if self.dirty || self.laid_width != width {
    self.lay(width)
  }
}

///|
fn md_max_line(lines : Array[@strip.Strip]) -> Int32 {
  let mut widest = 0
  for line in lines {
    let used = line.cell_length()
    if used > widest {
      widest = used
    }
  }
  widest
}

///|
pub impl Widget for Markdown with fn render_line(self, row, size) {
  self.seen = size.height
  self.ensure(size.width)
  let index = row + self.offset_y
  let count = self.laid.length()
  if index < 0 || index >= count {
    return @strip.Strip::blank(size.width, self.style)
  }
  self.laid[index].pad_to(size.width, self.style)
}

///|
pub impl Widget for Markdown with fn hint(self, size) {
  let width = if size.width > 0 { size.width } else { 40 }
  self.ensure(width)
  let widest = md_max_line(self.laid)
  @geom.Size::new(
    if widest > width {
      widest
    } else {
      width
    },
    self.laid.length(),
  )
}

///|
pub impl Widget for Markdown with fn focusable(_self) {
  true
}

///|
fn Markdown::scroll_by(self : Markdown, ctx : Ctx, lines : Int32) -> Unit {
  let count = self.laid.length()
  // The last page ends on the last line: once a height is known, scrolling stops
  // with the document filling the view rather than one line at the top of it.
  let page = if self.seen > 0 { self.seen } else { 1 }
  let most = if count > page { count - page } else { 0 }
  let mut next = self.offset_y + lines
  if next > most {
    next = most
  }
  if next < 0 {
    next = 0
  }
  if next != self.offset_y {
    self.offset_y = next
    ctx.emit(Scrolled(id=ctx.id, x=0, y=self.offset_y))
    ctx.repaint()
  }
}

///|
pub impl Widget for Markdown with fn handle(self, ctx, msg) {
  self.seen = ctx.size.height
  self.ensure(ctx.size.width)
  match msg {
    Key(k) => {
      let page = if self.seen > 1 { self.seen - 1 } else { 1 }
      match k.code {
        Up | Left => {
          self.scroll_by(ctx, -1)
          true
        }
        Down | Right => {
          self.scroll_by(ctx, 1)
          true
        }
        PageUp => {
          self.scroll_by(ctx, -page)
          true
        }
        PageDown => {
          self.scroll_by(ctx, page)
          true
        }
        Home => {
          self.scroll_by(ctx, -self.laid.length())
          true
        }
        End => {
          self.scroll_by(ctx, self.laid.length())
          true
        }
        _ => false
      }
    }
    Mouse(m) =>
      match m.kind {
        ScrollUp => {
          self.scroll_by(ctx, -1)
          true
        }
        ScrollDown => {
          self.scroll_by(ctx, 1)
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub extend Markdown with Widget::{focusable, handle, hint, render_line}
