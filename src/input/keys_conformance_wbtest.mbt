// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn vector_bytes(text : String) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<text.length() {
    out.push(text[i].to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The sequence each terminal's own database says it sends becomes the key it
/// names: an arrow in all three spellings, both spellings of Home and End, the
/// function keys of a console, a terminal and a multiplexer, and the two
/// spellings of Backspace.
test "keys parse as the terminal database names them" {
  let mut parsed = 0
  for (_, _, sequence, want) in key_vectors {
    let parser = Parser::new()
    let out : Array[@event.Event] = []
    parser.feed(vector_bytes(sequence), out)
    parser.idle(out)
    assert_eq(out.length(), 1)
    match out[0] {
      Key(key) => assert_eq(key.code, want)
      _ => assert_eq(false, true)
    }
    parsed = parsed + 1
  }
  assert_eq(parsed, key_vectors.length())
}
