// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
priv enum MDFlow {
  MDHeading(Int32, String)
  MDParagraph(String)
  MDQuote(String)
  MDBullet(Int32, String)
  MDNumbered(Int32, Int32, String)
  MDCode(Array[String])
  MDRule
  MDTable(Array[Align], Array[String], Array[Array[String]])
}

///|
fn md_trim(line : String) -> String {
  let mut start = 0
  let end = line.length()
  while start < end && (line[start] == ' ' || line[start] == '\t') {
    start = start + 1
  }
  let mut stop = end
  while stop > start && (line[stop - 1] == ' ' || line[stop - 1] == '\t') {
    stop = stop - 1
  }
  line[start:stop].to_owned()
}

///|
fn md_spaces_of(line : String) -> Int32 {
  let mut count = 0
  let total = line.length()
  while count < total && line[count] == ' ' {
    count = count + 1
  }
  count
}

///|
fn md_starts_with(line : String, head : String) -> Bool {
  let span = head.length()
  if line.length() < span {
    return false
  }
  line[0:span].to_owned() == head
}

///|
fn md_heading(line : String) -> (Int32, String)? {
  let mut level = 0
  let total = line.length()
  while level < total && line[level] == '#' {
    level = level + 1
  }
  if level == 0 || level > 6 {
    return None
  }
  if level < total && line[level] != ' ' {
    return None
  }
  Some((level, md_trim(line[level:].to_owned())))
}

///|
fn md_hr(line : String) -> Bool {
  let total = line.length()
  if total < 3 {
    return false
  }
  let head = line[0]
  if head != '-' && head != '*' && head != '_' {
    return false
  }
  let mut at = 0
  while at < total {
    if line[at] != head {
      return false
    }
    at = at + 1
  }
  true
}

///|
fn md_split_row(line : String) -> Array[String] {
  let mut body = md_trim(line)
  if body.length() > 0 && body[0] == '|' {
    body = body[1:].to_owned()
  }
  if body.length() > 0 && body[body.length() - 1] == '|' {
    body = body[0:body.length() - 1].to_owned()
  }
  let cells : Array[String] = []
  let mut start = 0
  let total = body.length()
  let mut at = 0
  while at < total {
    if body[at] == '\\' && at + 1 < total && body[at + 1] == '|' {
      at = at + 2
    }
    if at < total && body[at] == '|' {
      cells.push(md_trim(body[start:at].to_owned()))
      start = at + 1
    }
    at = at + 1
  }
  cells.push(md_trim(body[start:].to_owned()))
  cells.map(c => c.replace_all(old="\\|", new="|"))
}

///|
fn md_sep_part(part : String) -> Bool {
  let total = part.length()
  if total == 0 {
    return false
  }
  let mut at = 0
  if part[at] == ':' {
    at = at + 1
  }
  let mut dashes = 0
  while at < total && part[at] == '-' {
    at = at + 1
    dashes = dashes + 1
  }
  if at < total && part[at] == ':' {
    at = at + 1
  }
  dashes > 0 && at == total
}

///|
fn md_align_of(part : String) -> Align {
  let total = part.length()
  let left = total > 0 && part[0] == ':'
  let right = total > 0 && part[total - 1] == ':'
  if left && right {
    return Centre
  }
  if right {
    return Right
  }
  Left
}

///|
fn md_table_sep(line : String) -> Array[Align]? {
  if !line.contains("|") {
    return None
  }
  let parts = md_split_row(line)
  let aligns : Array[Align] = []
  for part in parts {
    if !md_sep_part(part) {
      return None
    }
    aligns.push(md_align_of(part))
  }
  if aligns.length() == 0 {
    return None
  }
  Some(aligns)
}

///|
fn md_list(line : String) -> MDFlow? {
  let total = line.length()
  if total == 0 {
    return None
  }
  let head = line[0]
  if head == '-' || head == '+' || head == '*' {
    if total > 1 && line[1] == ' ' {
      return Some(MDBullet(0, md_trim(line[2:].to_owned())))
    }
    if total == 1 {
      return Some(MDBullet(0, ""))
    }
    return None
  }
  let mut digits = 0
  while digits < total && line[digits] >= '0' && line[digits] <= '9' {
    digits = digits + 1
  }
  if digits == 0 || digits + 1 >= total {
    return None
  }
  if line[digits] != '.' && line[digits] != ')' {
    return None
  }
  if line[digits + 1] != ' ' {
    return None
  }
  let number = md_number_of(line[0:digits].to_owned())
  Some(MDNumbered(0, number, md_trim(line[digits + 2:].to_owned())))
}

///|
fn md_parse(text : String) -> Array[MDFlow] {
  let blocks : Array[MDFlow] = []
  let lines = split_lines(text)
  let total = lines.length()
  let mut i = 0
  let mut para = ""
  let mut quote = ""
  while i < total {
    let raw = lines[i]
    let line = md_trim(raw)
    if line == "" {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      i = i + 1
      continue
    }
    if md_starts_with(line, "```") {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      i = i + 1
      let code : Array[String] = []
      while i < total && !md_starts_with(md_trim(lines[i]), "```") {
        code.push(lines[i])
        i = i + 1
      }
      blocks.push(MDCode(code))
      i = i + 1
      continue
    }
    match md_heading(line) {
      Some((level, head)) => {
        if para != "" {
          blocks.push(MDParagraph(para))
          para = ""
        }
        if quote != "" {
          blocks.push(MDQuote(quote))
          quote = ""
        }
        blocks.push(MDHeading(level, head))
        i = i + 1
        continue
      }
      None => ()
    }
    if md_hr(line) {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      blocks.push(MDRule)
      i = i + 1
      continue
    }
    if line.contains("|") &&
      i + 1 < total &&
      md_table_sep(md_trim(lines[i + 1])) is Some(_) {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      if quote != "" {
        blocks.push(MDQuote(quote))
        quote = ""
      }
      let head = md_split_row(line)
      let aligns = match md_table_sep(md_trim(lines[i + 1])) {
        Some(found) => found
        None => []
      }
      let rows : Array[Array[String]] = []
      i = i + 2
      while i < total {
        let body = md_trim(lines[i])
        if body == "" || !body.contains("|") {
          break
        }
        rows.push(md_split_row(body))
        i = i + 1
      }
      blocks.push(MDTable(aligns, head, rows))
      continue
    }
    if line[0] == '>' {
      if para != "" {
        blocks.push(MDParagraph(para))
        para = ""
      }
      let inner = md_trim(line[1:].to_owned())
      if quote == "" {
        quote = inner
      } else {
        quote = quote + " " + inner
      }
      i = i + 1
      continue
    }
    match md_list(line) {
      Some(MDBullet(_, item)) => {
        if para != "" {
          blocks.push(MDParagraph(para))
          para = ""
        }
        if quote != "" {
          blocks.push(MDQuote(quote))
          quote = ""
        }
        let depth = md_spaces_of(raw) / 2
        blocks.push(MDBullet(depth, item))
        i = i + 1
        continue
      }
      Some(MDNumbered(_, number, item)) => {
        if para != "" {
          blocks.push(MDParagraph(para))
          para = ""
        }
        if quote != "" {
          blocks.push(MDQuote(quote))
          quote = ""
        }
        let depth = md_spaces_of(raw) / 2
        blocks.push(MDNumbered(depth, number, item))
        i = i + 1
        continue
      }
      _ => ()
    }
    if quote != "" {
      // A paragraph after a quote closes the quote first.
      blocks.push(MDQuote(quote))
      quote = ""
    }
    if para == "" {
      para = line
    } else {
      para = para + " " + line
    }
    i = i + 1
  }
  if para != "" {
    blocks.push(MDParagraph(para))
  }
  if quote != "" {
    blocks.push(MDQuote(quote))
  }
  blocks
}

///|
fn md_number_of(text : String) -> Int32 {
  let total = text.length()
  let mut value = 0
  let mut at = 0
  while at < total && text[at] >= '0' && text[at] <= '9' {
    value = value * 10 + text[at].to_int() - 48
    at = at + 1
  }
  value
}

///|
fn md_index_of(text : String, needle : String, from : Int32) -> Int32 {
  let span = needle.length()
  let total = text.length()
  let mut at = if from < 0 { 0 } else { from }
  while at + span <= total {
    if text[at:at + span].to_owned() == needle {
      return at
    }
    at = at + 1
  }
  -1
}

///|
fn md_link_scan(text : String, from : Int32) -> (Int32, Int32)? {
  // (where `](` starts, where the matching `)` is)
  let open = md_index_of(text, "](", from)
  if open < 0 {
    return None
  }
  let end = md_index_of(text, ")", open + 2)
  if end < 0 {
    return None
  }
  Some((open, end))
}

///|
fn md_inline(text : String, base : @style.Style) -> Array[@strip.Seg] {
  let segs : Array[@strip.Seg] = []
  let mut bold = false
  let mut italic = false
  let mut code = false
  let mut run_start = 0
  let word = (i : Int32) => {
    guard i >= 0 && i < text.length() else { return false }
    let c = text[i].to_int()
    (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
  }

  let blank = (i : Int32) => i < 0 || i >= text.length() || text[i] == ' '

  let total = text.length()
  let mut at = 0
  fn md_style() -> @style.Style {
    let mut st = base
    if code {
      st = st.merge(@style.Style::new(fg=@style.cyan))
    }
    if bold {
      st = st.merge(@style.Style::new(bold=true))
    }
    if italic {
      st = st.merge(@style.Style::new(italic=true))
    }
    st
  }
  fn cut(end : Int32) -> Unit {
    if end > run_start {
      segs.push(@strip.Seg::new(text[run_start:end].to_owned(), md_style()))
    }
  }
  while at < total {
    let ch = text[at]
    if ch == '\\' && at + 1 < total && text[at + 1].to_int() < 128 {
      cut(at)
      segs.push(@strip.Seg::new(text_of(text[at + 1].to_int()), md_style()))
      at = at + 2
      run_start = at
      continue
    }
    // Backtick runs pair by length; the inside is literal.
    if ch == '`' {
      let run = md_run(text, at, '`')
      match md_closing_run(text, at + run, run) {
        Some(close) => {
          cut(at)
          let inner = text[at + run:close].to_owned()
          let inner = if inner.length() > 1 &&
            inner[0] == ' ' &&
            inner[inner.length() - 1] == ' ' {
            inner[1:inner.length() - 1].to_owned()
          } else {
            inner
          }
          code = true
          segs.push(@strip.Seg::new(inner, md_style()))
          code = false
          at = close + run
          run_start = at
        }
        None => at = at + run
      }
      continue
    }
    if ch == '*' && at + 1 < total && text[at + 1] == '*' {
      if (!bold && !blank(at + 2)) || (bold && !blank(at - 1)) {
        cut(at)
        bold = !bold
        at = at + 2
        run_start = at
      } else {
        at = at + 2
      }
      continue
    }
    if ch == '*' {
      if (!italic && !blank(at + 1)) || (italic && !blank(at - 1)) {
        cut(at)
        italic = !italic
        at = at + 1
        run_start = at
      } else {
        at = at + 1
      }
      continue
    }
    if ch == '_' {
      let opens = !italic && !blank(at + 1) && !word(at - 1)
      let closes = italic && !blank(at - 1) && !word(at + 1)
      if opens || closes {
        cut(at)
        italic = !italic
        at = at + 1
        run_start = at
      } else {
        at = at + 1
      }
      continue
    }
    if ch == '[' {
      match md_link_scan(text, at) {
        Some((open, end)) => {
          cut(at)
          let label = text[at + 1:open].to_owned()
          if label != "" {
            segs.push(
              @strip.Seg::new(
                label,
                base.merge(@style.Style::new(underline=true)),
              ),
            )
          }
          at = end + 1
          run_start = at
          continue
        }
        None => ()
      }
    }
    at = at + 1
  }
  cut(total)
  segs
}

///|
/// Inline markup laid out in lines no wider than `width`, broken at spaces and
/// carrying each word's style across the break; a word wider than a line is
/// cut where the line ends.
fn md_wrap(
  text : String,
  width : Int32,
  base : @style.Style,
) -> Array[@strip.Strip] {
  let lines : Array[@strip.Strip] = []
  let line : Array[@strip.Seg] = []
  let mut used = 0
  let mut gap : @strip.Seg? = None
  fn flush() {
    lines.push(@strip.Strip::from_segs(line.copy()))
    line.clear()
    used = 0
  }
  for seg in md_inline(text, base) {
    for piece in md_pieces(seg.text) {
      let cells = @strip.str_cells(piece)
      if piece.trim() == "" {
        if used > 0 {
          gap = Some(@strip.Seg::new(" ", seg.style))
        }
        continue
      }
      let space = if gap is Some(_) { 1 } else { 0 }
      if used > 0 && used + space + cells > width {
        flush()
        gap = None
      }
      if gap is Some(g) && used > 0 {
        line.push(g)
        used += 1
      }
      gap = None
      let mut rest = piece
      while used + @strip.str_cells(rest) > width && width > 0 {
        let cut = @strip.cut_at(rest, width - used)
        let cut = if cut == 0 { @strip.cut_at(rest, width) } else { cut }
        line.push(@strip.Seg::new(rest[:cut].to_owned(), seg.style))
        flush()
        rest = rest[cut:].to_owned()
      }
      if rest != "" {
        line.push(@strip.Seg::new(rest, seg.style))
        used += @strip.str_cells(rest)
      }
    }
  }
  if line.length() > 0 || lines.length() == 0 {
    flush()
  }
  lines
}

///|
/// Words and the runs of spaces between them, in order.
fn md_pieces(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  for i in 0..<text.length() {
    if i > start && (text[i] == ' ') != (text[i - 1] == ' ') {
      out.push(text[start:i].to_owned())
      start = i
    }
  }
  if start < text.length() {
    out.push(text[start:].to_owned())
  }
  out
}

///|
fn md_marker(depth : Int32, bullet : Bool, number : Int32) -> String {
  let out = StringBuilder()
  let mut spaces = depth * 2
  while spaces > 0 {
    out.write_char(' ')
    spaces = spaces - 1
  }
  if bullet {
    out.write_string("• ")
  } else {
    out.write_string("\{number}. ")
  }
  out.to_string()
}

///|
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
} derive(Eq, Debug)

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
  let head_style = self.heading_style.merge(self.style)
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
        out.append(md_wrap(text, safe, style.merge(self.style)))
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
  let mut next = self.offset_y + lines
  if next > count - 1 {
    next = count - 1
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

///|
fn md_run(text : String, at : Int32, ch : Char) -> Int32 {
  let mut n = 0
  while at + n < text.length() && text[at + n].to_int() == ch.to_int() {
    n = n + 1
  }
  n
}

///|
/// Where a run of exactly `len` backticks starts at or after `from`.
fn md_closing_run(text : String, from : Int32, len : Int32) -> Int32? {
  let mut at = from
  while at < text.length() {
    if text[at] == '`' {
      let run = md_run(text, at, '`')
      if run == len {
        return Some(at)
      }
      at = at + run
    } else {
      at = at + 1
    }
  }
  None
}
