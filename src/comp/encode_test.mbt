// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "encoding moves the cursor and emits only the style changes" {
  let spans : Array[@comp.Span] = [
    { y: 0, x: 2, line: @strip.Strip::of("hi", plain), },
    { y: 1, x: 0, line: @strip.Strip::of("x", red), },
  ]
  let text = @comp.encode(spans, plain)
  assert_eq(
    text, "\u{1b}[0;39;49m\u{1b}[1;3Hhi\u{1b}[2;1H\u{1b}[31mx\u{1b}[39m",
  )
}

///|
test "encoding nothing writes nothing" {
  let empty : Array[@comp.Span] = []
  assert_eq(@comp.encode(empty, plain), "")
}

///|
test "cursor and screen control sequences" {
  assert_eq(@comp.cursor_to(0, 0), "\u{1b}[1;1H")
  assert_eq(@comp.cursor_to(23, 79), "\u{1b}[24;80H")
  assert_eq(@comp.show_cursor(false), "\u{1b}[?25l")
  assert_eq(@comp.clear, "\u{1b}[2J\u{1b}[H")
}

///|
test "the stream encoder writes whole rows without control sequences" {
  let rows = [@strip.Strip::of("hi", plain), @strip.Strip::blank(3, plain)]
  let text = @comp.encode_stream(@comp.full(rows))
  assert_eq(text, "hi\r\n   \r\n")
  assert_eq(text.contains("\u{1b}"), false)
}
