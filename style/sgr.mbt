// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Return the terminal to its own colours with no attributes.
pub let reset : String = "\u{1b}[0m"

///|
/// The full escape sequence for a style, starting from a reset. Use it when the
/// style in effect is unknown; use `delta` when it is known, since that emits
/// only what changed.
pub fn render(style : Style) -> String {
  let params = ["0"]
  attr_params(style.attrs, params)
  fg_params(style.fg, params)
  bg_params(style.bg, params)
  sgr(params)
}

///|
/// The shortest escape sequence that turns `prev` into `next`, empty when they
/// are already the same.
///
/// A terminal can switch an attribute on but not off — there is no "stop bold"
/// that leaves everything else alone — so dropping one costs a reset and a full
/// render. Adding attributes and changing colours are incremental.
pub fn delta(prev : Style, next : Style) -> String {
  if prev == next {
    return ""
  }
  if prev.attrs.drops_from(next.attrs) {
    return render(next)
  }
  let params : Array[String] = []
  attr_params(added(prev.attrs, next.attrs), params)
  if prev.fg != next.fg {
    fg_params(next.fg, params)
  }
  if prev.bg != next.bg {
    bg_params(next.bg, params)
  }
  sgr(params)
}

///|
/// The attributes `next` sets that `prev` did not.
fn added(prev : Attrs, next : Attrs) -> Attrs {
  {
    bold: next.bold && !prev.bold,
    dim: next.dim && !prev.dim,
    italic: next.italic && !prev.italic,
    underline: next.underline && !prev.underline,
    blink: next.blink && !prev.blink,
    reverse: next.reverse && !prev.reverse,
    strike: next.strike && !prev.strike,
  }
}

///|
fn sgr(params : Array[String]) -> String {
  if params.length() == 0 {
    return ""
  }
  let out = StringBuilder()
  out.write_string("\u{1b}[")
  for i in 0..<params.length() {
    if i > 0 {
      out.write_string(";")
    }
    out.write_string(params[i])
  }
  out.write_string("m")
  out.to_string()
}

///|
fn attr_params(attrs : Attrs, out : Array[String]) -> Unit {
  if attrs.bold {
    out.push("1")
  }
  if attrs.dim {
    out.push("2")
  }
  if attrs.italic {
    out.push("3")
  }
  if attrs.underline {
    out.push("4")
  }
  if attrs.blink {
    out.push("5")
  }
  if attrs.reverse {
    out.push("7")
  }
  if attrs.strike {
    out.push("9")
  }
}

///|
fn fg_params(color : Color, out : Array[String]) -> Unit {
  match color {
    Default => out.push("39")
    Ansi(i) =>
      if i < 8 {
        out.push((30 + i).to_string())
      } else {
        out.push((82 + i).to_string())
      }
    Ansi256(i) => {
      out.push("38")
      out.push("5")
      out.push(i.to_string())
    }
    Rgb(r, g, b) => {
      out.push("38")
      out.push("2")
      out.push(r.to_string())
      out.push(g.to_string())
      out.push(b.to_string())
    }
  }
}

///|
fn bg_params(color : Color, out : Array[String]) -> Unit {
  match color {
    Default => out.push("49")
    Ansi(i) =>
      if i < 8 {
        out.push((40 + i).to_string())
      } else {
        out.push((92 + i).to_string())
      }
    Ansi256(i) => {
      out.push("48")
      out.push("5")
      out.push(i.to_string())
    }
    Rgb(r, g, b) => {
      out.push("48")
      out.push("2")
      out.push(r.to_string())
      out.push(g.to_string())
      out.push(b.to_string())
    }
  }
}
