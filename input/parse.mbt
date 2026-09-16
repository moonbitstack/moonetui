// Copyright 2026 Heke Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// How long a sequence may get before the parser gives up on it. A terminal
/// that sends something unknown must not be able to stall the parser for ever,
/// so past this length the escape is reported as an Escape key and the rest is
/// read as ordinary text.
const MAX_SEQ : Int = 32

///|
/// Incremental parser from terminal bytes to events.
///
/// Bytes arrive in whatever pieces the operating system feels like giving, so a
/// sequence can be split anywhere — including between the two halves of a UTF-8
/// character. `feed` therefore consumes only what it can resolve and keeps the
/// rest; feeding one byte at a time and feeding a whole chunk produce the same
/// events.
pub struct Parser {
  mut buf : Array[Int]
  mut head : Int
  mut pasting : Bool
  pasted : StringBuilder
}

///|
/// A parser with nothing pending.
pub fn Parser::new() -> Parser {
  { buf: [], head: 0, pasting: false, pasted: StringBuilder(), }
}

///|
/// Drop everything pending. Used when a driver restarts the terminal, where any
/// half-read sequence belongs to the old mode.
pub fn Parser::reset(self : Parser) -> Unit {
  self.buf = []
  self.head = 0
  self.pasting = false
  self.pasted.reset()
}

///|
/// How many bytes are waiting for more input to resolve.
pub fn Parser::pending(self : Parser) -> Int {
  self.buf.length() - self.head
}

///|
/// Feed bytes and append whatever they resolve to.
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
/// Tell the parser that no more bytes are coming for now.
///
/// A lone escape byte is ambiguous while input might still arrive: it could be
/// the Escape key, or the start of a sequence whose remainder is still in
/// flight. Only the caller knows that the read timed out, so resolving it is
/// the caller's move to make.
pub fn Parser::idle(self : Parser, out : Array[@event.Event]) -> Unit {
  if self.pending() == 1 && self.at(0) == 0x1B {
    out.push(Key(@event.Key::of(Escape)))
    self.consume(1)
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
/// Resolve one thing at the front of the buffer, returning how many bytes it
/// took, or zero when more input is needed.
fn Parser::step(self : Parser, out : Array[@event.Event]) -> Int {
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
    // CSI: the parameterised sequences, which is nearly all of them.
    0x5B => self.step_csi(out)
    // SS3: the four function keys an application-mode keypad sends.
    0x4F => self.step_ss3(out)
    _ =>
      // Escape followed by anything else is that key with Alt held.
      match decode(self.buf, self.head + 1, self.buf.length()) {
        Some((code, size)) => {
          out.push(
            Key(
              @event.Key::with_mods(Char(code), {
                ctrl: false,
                alt: true,
                shift: false,
              }),
            ),
          )
          1 + size
        }
        None => 0
      }
  }
}

///|
fn Parser::step_text(
  self : Parser,
  first : Int,
  out : Array[@event.Event],
) -> Int {
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
/// Inside a bracketed paste every byte is content until the closing sequence,
/// so the text cannot be mistaken for keys someone typed very fast.
fn Parser::step_paste(self : Parser, out : Array[@event.Event]) -> Int {
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
      // The closing sequence may be split across reads; keep the partial match.
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
fn Parser::step_ss3(self : Parser, out : Array[@event.Event]) -> Int {
  if self.pending() < 3 {
    return 0
  }
  let code = match self.at(2) {
    0x50 => Some(@event.KeyCode::F(1))
    0x51 => Some(@event.KeyCode::F(2))
    0x52 => Some(@event.KeyCode::F(3))
    0x53 => Some(@event.KeyCode::F(4))
    _ => None
  }
  match code {
    Some(c) => {
      out.push(Key(@event.Key::of(c)))
      3
    }
    None => {
      out.push(Key(@event.Key::of(Escape)))
      1
    }
  }
}

///|
/// A parsed control sequence: the private marker if any, the numeric
/// parameters, and the final byte that says what it means.
priv struct Csi {
  private_marker : Int
  params : Array[Int]
  last : Int
  length : Int
}

///|
fn Parser::step_csi(self : Parser, out : Array[@event.Event]) -> Int {
  match self.scan_csi() {
    None =>
      if self.pending() >= MAX_SEQ {
        // Unrecognisable and too long to keep waiting on: report the escape and
        // let the rest be read as text.
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
  let params : Array[Int] = []
  let mut value = -1
  while i < self.pending() {
    let c = self.at(i)
    if c >= 0x30 && c <= 0x39 {
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
      return Some({ private_marker: marker, params, last: c, length: i + 1, })
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
  if csi.private_marker == 0x3C {
    match mouse_of(csi) {
      Some(m) => out.push(Mouse(m))
      None => ()
    }
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
    0x5A => out.push(Key(@event.Key::of(BackTab)))
    0x49 => out.push(FocusIn)
    0x4F => out.push(FocusOut)
    // CSI 48 ; rows ; cols t is the in-band size report a terminal sends when
    // the window changes, which beats waiting for a signal that browsers and
    // Windows do not have.
    0x74 =>
      if first == 48 && csi.params.length() >= 3 {
        out.push(Resize(param(csi, 2, 0), param(csi, 1, 0)))
      }
    // The kitty keyboard protocol reports a code point and its modifiers.
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
    // Anything else — a cursor position report, a device attribute answer — is
    // a reply to something the program asked for, not a key.
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
    // Wheel events arrive as buttons 64 upwards and are never released.
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
fn tilde_key(number : Int) -> @event.KeyCode? {
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
/// The C0 controls a terminal sends for keys that have no character of their
/// own, plus the control-letter combinations.
fn control_key(byte : Int) -> @event.Key {
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
        // Control-A through Control-Z arrive as one through twenty-six.
        @event.Key::with_mods(Char(byte + 0x60), ctrl)
      } else {
        @event.Key::with_mods(Char(byte + 0x40), ctrl)
      }
  }
}

///|
fn param(csi : Csi, index : Int, fallback : Int) -> Int {
  if index < csi.params.length() {
    csi.params[index]
  } else {
    fallback
  }
}

///|
fn Parser::at(self : Parser, index : Int) -> Int {
  self.buf[self.head + index]
}

///|
fn Parser::consume(self : Parser, count : Int) -> Unit {
  self.head = self.head + count
}

///|
/// Drop what has been consumed once it is worth the copy. A long paste would
/// otherwise keep growing the buffer behind the read head.
fn Parser::compact(self : Parser) -> Unit {
  if self.head == 0 {
    return
  }
  if self.head < 256 && self.pending() > 0 {
    return
  }
  let rest : Array[Int] = []
  for i in self.head..<self.buf.length() {
    rest.push(self.buf[i])
  }
  self.buf = rest
  self.head = 0
}

///|
fn Parser::starts_with(
  self : Parser,
  offset : Int,
  pattern : Array[Int],
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
/// True when the bytes from `offset` are a proper prefix of the pattern, which
/// means the rest may still arrive.
fn Parser::prefix_of(self : Parser, offset : Int, pattern : Array[Int]) -> Bool {
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
/// Decode one UTF-8 character, returning it with its length in bytes, or `None`
/// when the buffer holds only part of it. A malformed byte decodes to the
/// replacement character rather than raising: a terminal that sends rubbish
/// should not stop the program.
fn decode(buf : Array[Int], at : Int, end : Int) -> (Int, Int)? {
  let first = buf[at]
  if first < 0x80 {
    return Some((first, 1))
  }
  let size = if first >= 0xF0 {
    4
  } else if first >= 0xE0 {
    3
  } else if first >= 0xC0 {
    2
  } else {
    return Some((0xFFFD, 1))
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
fn write_code(out : StringBuilder, code : Int) -> Unit {
  match code.to_char() {
    Some(c) => out.write_char(c)
    None => out.write_string("\u{FFFD}")
  }
}
