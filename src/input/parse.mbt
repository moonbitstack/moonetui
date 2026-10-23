// Copyright 2026 Heke Cheng
// SPDX-License-Identifier: Apache-2.0

///|
const MAX_SEQ : Int32 = 32

///|
let alt : @event.Mods = { ctrl: false, alt: true, shift: false, }

///|
pub struct Parser {
  mut buf : Array[Int32]
  mut head : Int32
  mut pasting : Bool
  pasted : StringBuilder
}

///|
pub fn Parser::new() -> Parser {
  { buf: [], head: 0, pasting: false, pasted: StringBuilder(), }
}

///|
pub fn Parser::reset(self : Parser) -> Unit {
  self.buf = []
  self.head = 0
  self.pasting = false
  self.pasted.reset()
}

///|
pub fn Parser::pending(self : Parser) -> Int32 {
  self.buf.length() - self.head
}

///|
pub fn Parser::feed(
  self : Parser,
  data : Bytes,
  out : Array[@event.Event],
) -> Unit {
  for i in 0..<data.length() {
    self.buf.push(data[i].to_int())
  }
  self.drain(out)
}

///|
pub fn Parser::idle(self : Parser, out : Array[@event.Event]) -> Unit {
  if self.pending() == 1 && self.at(0) == 0x1B {
    out.push(Key(@event.Key::of(Escape)))
    self.consume(1)
  }
  // Input stopped inside a multi-byte character: it will not be finished.
  while !self.pasting && self.pending() > 0 && self.at(0) >= 0x80 {
    out.push(Key(@event.Key::of(Char(0xFFFD))))
    self.consume(1)
    self.drain(out)
  }
}

///|
fn Parser::drain(self : Parser, out : Array[@event.Event]) -> Unit {
  while self.pending() > 0 {
    let used = self.step(out)
    if used == 0 {
      break
    }
    self.consume(used)
  }
  self.compact()
}

///|
fn Parser::step(self : Parser, out : Array[@event.Event]) -> Int32 {
  if self.pasting {
    return self.step_paste(out)
  }
  let first = self.at(0)
  if first != 0x1B {
    return self.step_text(first, out)
  }
  if self.pending() < 2 {
    return 0
  }
  match self.at(1) {
    0x5B => self.step_csi(out)
    0x4F => self.step_ss3(out)
    0x1B => {
      out.push(Key(@event.Key::with_mods(Escape, alt)))
      2
    }
    next if next < 0x20 || next == 0x7F => {
      let key = control_key(next)
      out.push(Key({ ..key, mods: { ..key.mods, alt: true, }, }))
      2
    }
    _ =>
      match decode(self.buf, self.head + 1, self.buf.length()) {
        Some((code, size)) => {
          out.push(Key(@event.Key::with_mods(Char(code), alt)))
          1 + size
        }
        None => 0
      }
  }
}

///|
fn Parser::step_text(
  self : Parser,
  first : Int32,
  out : Array[@event.Event],
) -> Int32 {
  if first < 0x20 || first == 0x7F {
    out.push(Key(control_key(first)))
    return 1
  }
  match decode(self.buf, self.head, self.buf.length()) {
    Some((code, size)) => {
      out.push(Key(@event.Key::char(code)))
      size
    }
    None => 0
  }
}

///|
fn Parser::step_paste(self : Parser, out : Array[@event.Event]) -> Int32 {
  let close = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]
  let mut i = 0
  while i < self.pending() {
    if self.starts_with(i, close) {
      out.push(Paste(self.pasted.to_string()))
      self.pasted.reset()
      self.pasting = false
      return i + close.length()
    }
    if self.prefix_of(i, close) {
      break
    }
    match decode(self.buf, self.head + i, self.buf.length()) {
      Some((code, size)) => {
        write_code(self.pasted, code)
        i = i + size
      }
      None => break
    }
  }
  if i == 0 {
    0
  } else {
    i
  }
}

///|
fn Parser::step_ss3(self : Parser, out : Array[@event.Event]) -> Int32 {
  if self.pending() < 3 {
    return 0
  }
  let code : @event.KeyCode? = match self.at(2) {
    0x41 => Some(Up)
    0x42 => Some(Down)
    0x43 => Some(Right)
    0x44 => Some(Left)
    0x48 => Some(Home)
    0x46 => Some(End)
    0x50 => Some(F(1))
    0x51 => Some(F(2))
    0x52 => Some(F(3))
    0x53 => Some(F(4))
    _ => None
  }
  if code is Some(c) {
    out.push(Key(@event.Key::of(c)))
  }
  3
}

///|
priv struct Csi {
  private_marker : Int32
  intermediate : Bool
  params : Array[Int32]
  last : Int32
  length : Int32
}

///|
fn Parser::step_csi(self : Parser, out : Array[@event.Event]) -> Int32 {
  match self.scan_csi() {
    None =>
      if self.pending() >= MAX_SEQ {
        out.push(Key(@event.Key::of(Escape)))
        1
      } else {
        0
      }
    Some(csi) => {
      self.emit_csi(csi, out)
      csi.length
    }
  }
}

///|
fn Parser::scan_csi(self : Parser) -> Csi? {
  let mut i = 2
  let mut marker = 0
  if i < self.pending() {
    let c = self.at(i)
    if c == 0x3C || c == 0x3F || c == 0x3D || c == 0x3E {
      marker = c
      i = i + 1
    }
  }
  let params : Array[Int32] = []
  let mut value = -1
  let mut intermediate = false
  while i < self.pending() {
    let c = self.at(i)
    if c >= 0x20 && c <= 0x2F {
      intermediate = true
      i = i + 1
    } else if c >= 0x30 && c <= 0x39 {
      value = (if value < 0 { 0 } else { value }) * 10 + (c - 0x30)
      i = i + 1
    } else if c == 0x3B || c == 0x3A {
      params.push(if value < 0 { 0 } else { value })
      value = -1
      i = i + 1
    } else if c >= 0x40 && c <= 0x7E {
      if value >= 0 {
        params.push(value)
      }
      return Some({
        private_marker: marker,
        intermediate,
        params,
        last: c,
        length: i + 1,
      })
    } else {
      return None
    }
  }
  None
}

///|
fn Parser::emit_csi(
  self : Parser,
  csi : Csi,
  out : Array[@event.Event],
) -> Unit {
  if csi.intermediate {
    return
  }
  if csi.private_marker == 0x3C {
    if mouse_of(csi) is Some(m) {
      out.push(Mouse(m))
    }
    return
  }
  if csi.private_marker != 0 {
    return
  }
  let first = param(csi, 0, 1)
  let mods = @event.Mods::of_param(param(csi, 1, 1))
  match csi.last {
    0x41 => out.push(Key(@event.Key::with_mods(Up, mods)))
    0x42 => out.push(Key(@event.Key::with_mods(Down, mods)))
    0x43 => out.push(Key(@event.Key::with_mods(Right, mods)))
    0x44 => out.push(Key(@event.Key::with_mods(Left, mods)))
    0x46 => out.push(Key(@event.Key::with_mods(End, mods)))
    0x48 => out.push(Key(@event.Key::with_mods(Home, mods)))
    0x5A => out.push(Key(@event.Key::with_mods(BackTab, mods)))
    0x49 => out.push(FocusIn)
    0x4F => out.push(FocusOut)
    0x74 =>
      if first == 48 && csi.params.length() >= 3 {
        out.push(Resize(param(csi, 2, 0), param(csi, 1, 0)))
      }
    0x75 => out.push(Key(@event.Key::with_mods(Char(first), mods)))
    0x7E =>
      match first {
        200 => self.pasting = true
        201 => ()
        _ =>
          match tilde_key(first) {
            Some(code) => out.push(Key(@event.Key::with_mods(code, mods)))
            None => ()
          }
      }
    _ => ()
  }
}

///|
fn mouse_of(csi : Csi) -> @event.Mouse? {
  if csi.params.length() < 3 {
    return None
  }
  let code = csi.params[0]
  let x = csi.params[1] - 1
  let y = csi.params[2] - 1
  let mods : @event.Mods = {
    shift: code / 4 % 2 == 1,
    alt: code / 8 % 2 == 1,
    ctrl: code / 16 % 2 == 1,
  }
  let released = csi.last == 0x6D
  let button = code % 4
  if code / 64 % 2 == 1 {
    let kind = match button {
      0 => @event.MouseKind::ScrollUp
      1 => @event.MouseKind::ScrollDown
      2 => @event.MouseKind::ScrollLeft
      _ => @event.MouseKind::ScrollRight
    }
    return Some({ kind, button, x, y, mods, })
  }
  let moving = code / 32 % 2 == 1
  let kind = if moving {
    @event.MouseKind::Move
  } else if released {
    @event.MouseKind::Up
  } else {
    @event.MouseKind::Down
  }
  Some({ kind, button, x, y, mods, })
}

///|
fn tilde_key(number : Int32) -> @event.KeyCode? {
  match number {
    1 => Some(Home)
    2 => Some(Insert)
    3 => Some(Delete)
    4 => Some(End)
    5 => Some(PageUp)
    6 => Some(PageDown)
    7 => Some(Home)
    8 => Some(End)
    11 => Some(F(1))
    12 => Some(F(2))
    13 => Some(F(3))
    14 => Some(F(4))
    15 => Some(F(5))
    17 => Some(F(6))
    18 => Some(F(7))
    19 => Some(F(8))
    20 => Some(F(9))
    21 => Some(F(10))
    23 => Some(F(11))
    24 => Some(F(12))
    _ => None
  }
}

///|
fn control_key(byte : Int32) -> @event.Key {
  let ctrl : @event.Mods = { ctrl: true, alt: false, shift: false, }
  match byte {
    0x09 => @event.Key::of(Tab)
    0x0A => @event.Key::of(Enter)
    0x0D => @event.Key::of(Enter)
    0x7F => @event.Key::of(Backspace)
    0x08 => @event.Key::with_mods(Backspace, ctrl)
    0x00 => @event.Key::with_mods(Char(0x20), ctrl)
    _ =>
      if byte >= 0x01 && byte <= 0x1A {
        @event.Key::with_mods(Char(byte + 0x60), ctrl)
      } else {
        @event.Key::with_mods(Char(byte + 0x40), ctrl)
      }
  }
}

///|
fn param(csi : Csi, index : Int32, fallback : Int32) -> Int32 {
  if index < csi.params.length() {
    csi.params[index]
  } else {
    fallback
  }
}

///|
fn Parser::at(self : Parser, index : Int32) -> Int32 {
  self.buf[self.head + index]
}

///|
fn Parser::consume(self : Parser, count : Int32) -> Unit {
  self.head = self.head + count
}

///|
fn Parser::compact(self : Parser) -> Unit {
  if self.head == 0 {
    return
  }
  if self.head < 256 && self.pending() > 0 {
    return
  }
  let rest : Array[Int32] = []
  for i in self.head..<self.buf.length() {
    rest.push(self.buf[i])
  }
  self.buf = rest
  self.head = 0
}

///|
fn Parser::starts_with(
  self : Parser,
  offset : Int32,
  pattern : Array[Int32],
) -> Bool {
  if self.pending() - offset < pattern.length() {
    return false
  }
  for i in 0..<pattern.length() {
    if self.at(offset + i) != pattern[i] {
      return false
    }
  }
  true
}

///|
fn Parser::prefix_of(
  self : Parser,
  offset : Int32,
  pattern : Array[Int32],
) -> Bool {
  let left = self.pending() - offset
  if left <= 0 || left >= pattern.length() {
    return false
  }
  for i in 0..<left {
    if self.at(offset + i) != pattern[i] {
      return false
    }
  }
  true
}

///|
fn decode(buf : Array[Int32], at : Int32, end : Int32) -> (Int32, Int32)? {
  let first = buf[at]
  if first < 0x80 {
    return Some((first, 1))
  }
  let size = if first >= 0xF8 {
    return Some((0xFFFD, 1))
  } else if first >= 0xF0 {
    4
  } else if first >= 0xE0 {
    3
  } else if first >= 0xC0 {
    2
  } else {
    return Some((0xFFFD, 1))
  }
  // A byte that cannot continue the sequence settles it now, whatever follows.
  for i in 1..<size {
    if at + i < end && (buf[at + i] < 0x80 || buf[at + i] >= 0xC0) {
      return Some((0xFFFD, 1))
    }
  }
  if at + size > end {
    return None
  }
  let mut code = match size {
    2 => first - 0xC0
    3 => first - 0xE0
    _ => first - 0xF0
  }
  for i in 1..<size {
    let byte = buf[at + i]
    if byte < 0x80 || byte >= 0xC0 {
      return Some((0xFFFD, 1))
    }
    code = (code << 6) | (byte - 0x80)
  }
  Some((code, size))
}

///|
fn write_code(out : StringBuilder, code : Int32) -> Unit {
  match code.to_char() {
    Some(c) => out.write_char(c)
    None => out.write_string("\u{FFFD}")
  }
}
