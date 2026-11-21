// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The words inside a block: emphasis, code spans and links turned into styled
// segments, and the wrapping that fits them into the width a pane has.

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
