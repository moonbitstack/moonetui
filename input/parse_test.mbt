// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Bytes from code values, which is how a terminal's output is written down in
/// documentation and how it is easiest to read back here.
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The bytes of an ASCII string.
fn ascii(text : String) -> Bytes {
  let out : Array[Int] = []
  for i in 0..<text.length() {
    out.push(text[i].to_int())
  }
  bytes(out)
}

///|
/// Everything one chunk resolves to, with a final idle so that a trailing lone
/// escape becomes the Escape key.
fn parse(data : Bytes) -> Array[@event.Event] {
  let p = @input.Parser::new()
  let out : Array[@event.Event] = []
  p.feed(data, out)
  p.idle(out)
  out
}

///|
/// The same input delivered one byte at a time.
fn parse_split(data : Bytes) -> Array[@event.Event] {
  let p = @input.Parser::new()
  let out : Array[@event.Event] = []
  for i in 0..<data.length() {
    p.feed(bytes([data[i].to_int()]), out)
  }
  p.idle(out)
  out
}

///|
let no_mods : @event.Mods = @event.none

///|
let ctrl : @event.Mods = { ctrl: true, alt: false, shift: false, }

///|
test "printable characters come through as themselves" {
  assert_eq(parse(ascii("hi")), [
    Key({ code: Char(104), mods: no_mods, }),
    Key({ code: Char(105), mods: no_mods, }),
  ])
}

///|
test "a multi-byte character is one key" {
  // The Chinese character 中 is three bytes of UTF-8 and one key press.
  let data = bytes([0xE4, 0xB8, 0xAD])
  assert_eq(parse(data), [Key({ code: Char(0x4E2D), mods: no_mods, })])
  // Split across three reads it is still one key, and nothing is emitted until
  // the last byte arrives.
  assert_eq(parse_split(data), parse(data))
}

///|
test "the control codes map to the keys that have no character" {
  assert_eq(parse(bytes([0x0D])), [Key({ code: Enter, mods: no_mods, })])
  assert_eq(parse(bytes([0x09])), [Key({ code: Tab, mods: no_mods, })])
  assert_eq(parse(bytes([0x7F])), [Key({ code: Backspace, mods: no_mods, })])
  // Control-A arrives as the byte one.
  assert_eq(parse(bytes([0x01])), [Key({ code: Char(97), mods: ctrl, })])
  assert_eq(parse(bytes([0x08])), [Key({ code: Backspace, mods: ctrl, })])
}

///|
test "escape followed by a character is that character with alt held" {
  let alt : @event.Mods = { ctrl: false, alt: true, shift: false, }
  assert_eq(parse(bytes([0x1B, 0x61])), [Key({ code: Char(97), mods: alt, })])
}

///|
test "a lone escape resolves only when the caller says input stopped" {
  let p = @input.Parser::new()
  let out : Array[@event.Event] = []
  p.feed(bytes([0x1B]), out)
  // Still ambiguous: the rest of a sequence may be on its way.
  assert_eq(out.length(), 0)
  assert_eq(p.pending(), 1)
  p.idle(out)
  assert_eq(out, [Key({ code: Escape, mods: no_mods, })])
  assert_eq(p.pending(), 0)
}

///|
test "arrow keys, with and without modifiers" {
  assert_eq(parse(ascii("\u{1b}[A")), [Key({ code: Up, mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[B")), [Key({ code: Down, mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[C")), [Key({ code: Right, mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[D")), [Key({ code: Left, mods: no_mods, })])
  // The modifier parameter is one plus a bit per modifier: five is control.
  assert_eq(parse(ascii("\u{1b}[1;5A")), [Key({ code: Up, mods: ctrl, })])
  let shift_alt : @event.Mods = { ctrl: false, alt: true, shift: true, }
  assert_eq(parse(ascii("\u{1b}[1;4C")), [
    Key({ code: Right, mods: shift_alt, }),
  ])
}

///|
test "function keys arrive in both spellings terminals use" {
  assert_eq(parse(ascii("\u{1b}OP")), [Key({ code: F(1), mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[15~")), [Key({ code: F(5), mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[24~")), [Key({ code: F(12), mods: no_mods, })])
}

///|
test "navigation keys and shift-tab" {
  assert_eq(parse(ascii("\u{1b}[3~")), [Key({ code: Delete, mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[5~")), [Key({ code: PageUp, mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[H")), [Key({ code: Home, mods: no_mods, })])
  assert_eq(parse(ascii("\u{1b}[Z")), [Key({ code: BackTab, mods: no_mods, })])
}

///|
test "focus reports are events, not keys" {
  assert_eq(parse(ascii("\u{1b}[I")), [FocusIn])
  assert_eq(parse(ascii("\u{1b}[O")), [FocusOut])
}

///|
test "mouse reports carry zero-based coordinates" {
  // Terminals count from one; everything above this package counts from zero.
  assert_eq(parse(ascii("\u{1b}[<0;10;5M")), [
    Mouse({ kind: Down, button: 0, x: 9, y: 4, mods: no_mods, }),
  ])
  assert_eq(parse(ascii("\u{1b}[<0;10;5m")), [
    Mouse({ kind: Up, button: 0, x: 9, y: 4, mods: no_mods, }),
  ])
  // Motion sets bit five on the button code.
  assert_eq(parse(ascii("\u{1b}[<35;3;3M")), [
    Mouse({ kind: Move, button: 3, x: 2, y: 2, mods: no_mods, }),
  ])
}

///|
test "the wheel is reported as buttons that never release" {
  assert_eq(parse(ascii("\u{1b}[<64;1;1M")), [
    Mouse({ kind: ScrollUp, button: 0, x: 0, y: 0, mods: no_mods, }),
  ])
  assert_eq(parse(ascii("\u{1b}[<65;1;1M")), [
    Mouse({ kind: ScrollDown, button: 1, x: 0, y: 0, mods: no_mods, }),
  ])
}

///|
test "an in-band size report becomes a resize" {
  // CSI 48 ; rows ; columns t — rows first, which is the opposite of the order
  // the rest of the library uses.
  assert_eq(parse(ascii("\u{1b}[48;24;80t")), [Resize(80, 24)])
}

///|
test "a bracketed paste arrives as one piece of text" {
  assert_eq(parse(ascii("\u{1b}[200~hello\u{1b}[201~")), [Paste("hello")])
  // Text around the paste is still keys.
  assert_eq(parse(ascii("a\u{1b}[200~x\u{1b}[201~b")), [
    Key({ code: Char(97), mods: no_mods, }),
    Paste("x"),
    Key({ code: Char(98), mods: no_mods, }),
  ])
}

///|
test "a paste split across reads is still one event" {
  let data = ascii("\u{1b}[200~one two\u{1b}[201~")
  assert_eq(parse_split(data), [Paste("one two")])
}

///|
test "an escape sequence nobody recognises does not stall the parser" {
  // Thirty-two bytes is the limit; past it the escape is reported and the rest
  // is read as text rather than swallowed.
  let filler = "\u{1b}[" + "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
  let events = parse(ascii(filler))
  assert_eq(events[0], Key({ code: Escape, mods: no_mods, }))
  assert_eq(events.length() > 1, true)
}

///|
test "every sequence parses the same whether split or whole" {
  let corpus = [
    ascii("hello"),
    ascii("\u{1b}[A"),
    ascii("\u{1b}[1;5A"),
    ascii("\u{1b}OP"),
    ascii("\u{1b}[15~"),
    ascii("\u{1b}[Z"),
    ascii("\u{1b}[I"),
    ascii("\u{1b}[<0;10;5M"),
    ascii("\u{1b}[48;24;80t"),
    ascii("\u{1b}[200~pasted\u{1b}[201~"),
    ascii("\u{1b}a"),
    bytes([0xE4, 0xB8, 0xAD, 0x0D, 0x1B, 0x5B, 0x42]),
  ]
  for sample in corpus {
    assert_eq(parse_split(sample), parse(sample))
  }
}
