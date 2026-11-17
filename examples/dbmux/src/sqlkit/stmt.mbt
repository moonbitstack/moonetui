// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The statements of a script, split at each `;` that is outside a string, a
/// comment and parentheses. Each piece keeps its own text exactly as written,
/// without the `;` that ended it; pieces with nothing in them but blanks and
/// comments are dropped, so an empty line between two statements is not one.
pub fn statements(text : String, dialect : Dialect) -> Array[String] {
  let out : Array[String] = []
  let mut buf = StringBuilder()
  let mut has_code = false
  for token in lex(text, dialect) {
    if token.kind == Punct && token.text == ";" && token.depth == 0 {
      push_statement(buf, has_code, out)
      buf = StringBuilder()
      has_code = false
      continue
    }
    buf.write_string(token.text)
    if token.kind == Word || token.kind == Quoted {
      has_code = true
    }
    if token.kind == Punct && token.text != ";" && token.text != "," {
      has_code = true
    }
  }
  push_statement(buf, has_code, out)
  out
}

///|
fn push_statement(
  buf : StringBuilder,
  has_code : Bool,
  out : Array[String],
) -> Unit {
  if has_code {
    let piece = buf.to_string().trim().to_owned()
    if piece != "" {
      out.push(piece)
    }
  }
}

///|
/// The first word of a statement, lowercased: `select`, `update`, `with`. A
/// leading parenthesis or a `/*!` version comment is stepped over.
pub fn first_word(text : String, dialect : Dialect) -> String {
  for token in lex(text, dialect) {
    if token.kind == Word {
      return token.text.to_lower()
    }
    if token.kind == Quoted {
      return token.text.to_lower()
    }
  }
  ""
}

///|
/// Whether a script writes: any statement whose first word is not a read-only
/// one starts a write as far as this check is concerned. It reads the words,
/// so a write inside a function body is not caught; a read-only account, or
/// the server's own read-only session, is the boundary that holds.
pub fn writes(text : String, dialect : Dialect) -> Bool {
  for piece in statements(text, dialect) {
    if !is_read(piece, dialect) {
      return true
    }
  }
  false
}

///|
/// Whether a single statement only reads. `WITH` is a read when the statement
/// it introduces is one; `EXPLAIN` without `ANALYZE` reads, and with it runs.
pub fn is_read(text : String, dialect : Dialect) -> Bool {
  let head = first_word(text, dialect)
  match head {
    "select" | "show" | "describe" | "desc" | "pragma" | "values" | "table" =>
      true
    "explain" => {
      for token in lex(text, dialect) {
        if token.kind == Word && token.text.to_lower() == "analyze" {
          return false
        }
      }
      true
    }
    "with" => {
      let ws = words(text, dialect)
      let mut i = 0
      while i < ws.length() {
        match ws[i] {
          (w, 0) =>
            if w == "select" || w == "values" || w == "table" {
              return true
            } else if w == "insert" ||
              w == "update" ||
              w == "delete" ||
              w == "merge" {
              return false
            }
          _ => ()
        }
        i = i + 1
      }
      false
    }
    _ => false
  }
}
