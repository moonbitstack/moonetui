// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Where the character before `index` starts, so a caret never lands between
/// the halves of a surrogate pair.
fn prev_char(text : String, index : Int32) -> Int32 {
  if index <= 0 {
    return 0
  }
  let low = text[index - 1].to_int()
  if index >= 2 && low >= 0xDC00 && low <= 0xDFFF {
    let high = text[index - 2].to_int()
    if high >= 0xD800 && high <= 0xDBFF {
      return index - 2
    }
  }
  index - 1
}

///|
/// Where the character after the one at `index` starts.
fn next_char(text : String, index : Int32) -> Int32 {
  if index >= text.length() {
    return text.length()
  }
  let (_, used) = @strip.code_at(text, index)
  index + used
}

///|
/// Letters, digits, the underscore and everything outside ASCII make words;
/// the rest of ASCII is punctuation.
fn word_char(code : Int32) -> Bool {
  (code >= 0x30 && code <= 0x39) ||
  (code >= 0x41 && code <= 0x5A) ||
  (code >= 0x61 && code <= 0x7A) ||
  code == 0x5F ||
  code >= 0x80
}

///|
fn blank_char(code : Int32) -> Bool {
  code == 0x20 || code == 0x09
}

///|
fn code_before(text : String, index : Int32) -> Int32 {
  @strip.code_at(text, prev_char(text, index)).0
}

///|
/// The start of the word, or run of punctuation, before `index`, passing over
/// the blanks in between first.
fn word_start(text : String, index : Int32) -> Int32 {
  let mut at = index
  while at > 0 && blank_char(code_before(text, at)) {
    at = prev_char(text, at)
  }
  if at == 0 {
    return 0
  }
  let kind = word_char(code_before(text, at))
  while at > 0 {
    let code = code_before(text, at)
    if blank_char(code) || word_char(code) != kind {
      break
    }
    at = prev_char(text, at)
  }
  at
}

///|
/// The end of the word, or run of punctuation, after `index`, passing over the
/// blanks in between first.
fn word_end(text : String, index : Int32) -> Int32 {
  let mut at = index
  while at < text.length() && blank_char(@strip.code_at(text, at).0) {
    at = next_char(text, at)
  }
  if at >= text.length() {
    return text.length()
  }
  let kind = word_char(@strip.code_at(text, at).0)
  while at < text.length() {
    let code = @strip.code_at(text, at).0
    if blank_char(code) || word_char(code) != kind {
      break
    }
    at = next_char(text, at)
  }
  at
}
