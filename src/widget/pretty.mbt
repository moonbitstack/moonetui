// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A value to print, as the shapes a caller's own data comes in.
pub(all) enum Value {
  VNil
  VBool(Bool)
  VInt(Int32)
  VNum(Double)
  VStr(String)
  VArr(Array[Value])
  VObj(Array[(String, Value)])
} derive(Eq, Debug)

///|
/// The one-line reading of a value, which is what is printed when the whole
/// thing fits.
pub fn Value::summary(self : Value) -> String {
  match self {
    VNil => "nil"
    VBool(on) => if on { "true" } else { "false" }
    VInt(whole) => whole.to_string()
    VNum(real) => real.to_string()
    VStr(text) => "\"" + text + "\""
    VArr(items) => {
      let parts : Array[String] = []
      for item in items {
        parts.push(item.summary())
      }
      "[" + join_text(parts, ", ") + "]"
    }
    VObj(fields) => {
      let parts : Array[String] = []
      for field in fields {
        parts.push(field.0 + ": " + field.1.summary())
      }
      "{" + join_text(parts, ", ") + "}"
    }
  }
}

///|
/// A value printed the way it reads: laid out with an indent, in the colours
/// of what each part is, and on one line when it fits.
///
/// The arrows scroll a value taller than its box. A caller's own types come in
/// as a `Value`, which is what the printer walks.
pub struct Pretty {
  mut value : Value
  mut offset : Int32
  mut focused : Bool
  indent : Int32
  style : @style.Style
  key_style : @style.Style
  text_style : @style.Style
  number_style : @style.Style
  punct_style : @style.Style
}

///|
pub fn Pretty::new(
  value~ : Value = VNil,
  indent~ : Int32 = 2,
  style~ : @style.Style = @style.default,
  key_style~ : @style.Style = @style.Style::new(fg=@style.cyan),
  text_style~ : @style.Style = @style.Style::new(fg=@style.green),
  number_style~ : @style.Style = @style.Style::new(fg=@style.yellow),
  punct_style~ : @style.Style = @style.Style::new(dim=true),
) -> Pretty {
  {
    value,
    offset: 0,
    focused: false,
    indent,
    style,
    key_style,
    text_style,
    number_style,
    punct_style,
  }
}

///|
pub fn Pretty::set(self : Pretty, value : Value) -> Unit {
  self.value = value
  self.offset = 0
}

///|
pub fn Pretty::value(self : Pretty) -> Value {
  self.value
}

///|
pub fn Pretty::offset(self : Pretty) -> Int32 {
  self.offset
}

///|
/// The printed value as lines of segments, laid out for a box `width` wide.
pub fn Pretty::lines(self : Pretty, width : Int32) -> Array[Array[@strip.Seg]] {
  self.of(self.value, 0, width)
}

///|
pub impl Widget for Pretty with fn render_line(self, row, size) {
  let lines = self.lines(size.width)
  let at = self.offset + row
  if at < 0 || at >= lines.length() || size.width <= 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  @strip.Strip::from_segs(lines[at]).pad_to(size.width, self.style)
}

///|
pub impl Widget for Pretty with fn hint(self, size) {
  @geom.Size::new(size.width, self.lines(size.width).length())
}

///|
pub impl Widget for Pretty with fn handle(self, ctx, msg) {
  let rows = self.lines(ctx.size.width).length()
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        let by = match key.code {
          Up => -1
          Down => 1
          PageUp => -at_least_one(ctx.size.height - 1)
          PageDown => at_least_one(ctx.size.height - 1)
          Home => -rows
          End => rows
          _ => return false
        }
        let most = at_least_zero(rows - ctx.size.height)
        let next = constrain(self.offset + by, 0, most)
        if next == self.offset {
          return true
        }
        self.offset = next
        ctx.repaint()
        true
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          true
        }
        ScrollUp =>
          if self.offset > 0 {
            self.offset = self.offset - 1
            ctx.repaint()
            true
          } else {
            false
          }
        ScrollDown =>
          if self.offset < at_least_zero(rows - ctx.size.height) {
            self.offset = self.offset + 1
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
pub impl Widget for Pretty with fn focusable(_self) {
  true
}

///|
/// One line of segments: the words and the marks around them in their own
/// colours.
fn Pretty::of(
  self : Pretty,
  value : Value,
  depth : Int32,
  width : Int32,
) -> Array[Array[@strip.Seg]] {
  let lead = @strip.Strip::blank(depth * self.indent, self.style).segs
  let room = at_least_zero(width - depth * self.indent)
  let flat = value.summary()
  if @strip.str_cells(flat) <= room {
    return [lead + self.inline(value)]
  }
  let bracket = (text : String) => {
    lead + [@strip.Seg::new(text, self.punct_style)]
  }
  match value {
    VArr(items) => {
      let out : Array[Array[@strip.Seg]] = [bracket("[")]
      for i in 0..<items.length() {
        let part = self.of(items[i], depth + 1, width)
        let last = part.length() - 1
        if i + 1 < items.length() {
          part[last] = part[last] + [@strip.Seg::new(",", self.punct_style)]
        }
        for line in part {
          out.push(line)
        }
      }
      out.push(bracket("]"))
      out
    }
    VObj(fields) => {
      let out : Array[Array[@strip.Seg]] = [bracket("{")]
      for i in 0..<fields.length() {
        let (name, item) = fields[i]
        let part = self.of(item, depth + 1, width)
        // The name goes in front of the value, indented as the value is.
        let own = if part[0].length() > 0 {
          part[0][0:1].to_owned()
        } else {
          []
        }
        let rest = if part[0].length() > 0 {
          part[0][1:].to_owned()
        } else {
          []
        }
        part[0] = own +
          [
            @strip.Seg::new(name, self.key_style),
            @strip.Seg::new(": ", self.punct_style),
          ] +
          rest
        let last = part.length() - 1
        if i + 1 < fields.length() {
          part[last] = part[last] + [@strip.Seg::new(",", self.punct_style)]
        }
        for line in part {
          out.push(line)
        }
      }
      out.push(bracket("}"))
      out
    }
    _ => [lead + @strip.Strip::of(clip_to(flat, room), self.ink(value)).segs]
  }
}

///|
/// The one-line rendering, coloured value by value even when the whole thing
/// fits: brackets and separators are punctuation, keys are keys, and every
/// scalar takes the colour of what it is.
fn Pretty::inline(self : Pretty, value : Value) -> Array[@strip.Seg] {
  match value {
    VArr(items) => {
      let mut segs = [@strip.Seg::new("[", self.punct_style)]
      for i in 0..<items.length() {
        segs = segs + self.inline(items[i])
        if i + 1 < items.length() {
          segs = segs + [@strip.Seg::new(", ", self.punct_style)]
        }
      }
      segs + [@strip.Seg::new("]", self.punct_style)]
    }
    VObj(fields) => {
      let mut segs = [@strip.Seg::new("{", self.punct_style)]
      for i in 0..<fields.length() {
        let (name, item) = fields[i]
        segs = segs +
          [
            @strip.Seg::new(name, self.key_style),
            @strip.Seg::new(": ", self.punct_style),
          ] +
          self.inline(item)
        if i + 1 < fields.length() {
          segs = segs + [@strip.Seg::new(", ", self.punct_style)]
        }
      }
      segs + [@strip.Seg::new("}", self.punct_style)]
    }
    _ => [@strip.Seg::new(value.summary(), self.ink(value))]
  }
}

///|
/// The colour of what this is: words, numbers or nothing at all.
fn Pretty::ink(self : Pretty, value : Value) -> @style.Style {
  match value {
    VStr(_) => self.text_style
    VInt(_) | VNum(_) => self.number_style
    VNil => self.punct_style
    _ => self.style
  }
}

///|
fn join_text(parts : Array[String], between : String) -> String {
  let out = StringBuilder()
  for i in 0..<parts.length() {
    if i > 0 {
      out.write_string(between)
    }
    out.write_string(parts[i])
  }
  out.to_string()
}

///|
pub extend Value with Debug::{to_repr}

///|
pub extend Value with Eq::{not_equal, equal}

///|
pub extend Pretty with Widget::{focusable, handle, hint, render_line}
