// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a lexed piece of a statement is. `Quoted` covers both a string
/// literal and a quoted identifier: neither can end a statement, and neither
/// is a word for the checks that read the text.
#derive(Eq)
pub(all) enum TokenKind {
  Word
  Quoted
  Punct
  Space
  Comment
}

///|
pub extend TokenKind with Eq::{not_equal, equal}

///|
/// One lexed piece, with the parenthesis depth it starts at. `)` is reported
/// at the depth of the `(` it closes, so a WHERE at the same depth as its
/// DELETE is in the same statement and not in a subquery.
pub(all) struct Token {
  kind : TokenKind
  text : String
  depth : Int32
}

///|
fn is_word_char(c : Char) -> Bool {
  ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) ||
  c == '_' ||
  c == '$'
}

///|
/// A cheap lexer: enough to know where a statement ends, which words it
/// starts with, and how deep in parentheses each of them sits. It reads the
/// quoting the dialect understands, so a `;` inside a string or a comment
/// never cuts a statement in two.
pub fn lex(text : String, dialect : Dialect) -> Array[Token] {
  let out : Array[Token] = []
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  let mut depth = 0
  let run = StringBuilder()
  fn flush(
    run : StringBuilder,
    out : Array[Token],
    kind : TokenKind,
    depth : Int32,
  ) {
    if !run.is_empty() {
      out.push({ kind, text: run.to_string(), depth, })
      run.reset()
    }
  }
  while i < n {
    let c = chars[i]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      while i < n &&
            (
              chars[i] == ' ' ||
              chars[i] == '\t' ||
              chars[i] == '\r' ||
              chars[i] == '\n'
            ) {
        run.write_char(chars[i])
        i = i + 1
      }
      flush(run, out, Space, depth)
      continue
    }
    if c == '-' && i + 1 < n && chars[i + 1] == '-' {
      while i < n && chars[i] != '\n' {
        run.write_char(chars[i])
        i = i + 1
      }
      flush(run, out, Comment, depth)
      continue
    }
    if c == '/' && i + 1 < n && chars[i + 1] == '*' {
      let mut nest = 0
      while i < n {
        if chars[i] == '/' && i + 1 < n && chars[i + 1] == '*' {
          nest = nest + 1
          run.write_char('/')
          run.write_char('*')
          i = i + 2
        } else if chars[i] == '*' && i + 1 < n && chars[i + 1] == '/' {
          nest = nest - 1
          run.write_char('*')
          run.write_char('/')
          i = i + 2
          if nest == 0 {
            break
          }
        } else {
          run.write_char(chars[i])
          i = i + 1
        }
      }
      flush(run, out, Comment, depth)
      continue
    }
    if c == '\'' {
      run.write_char(c)
      i = i + 1
      let escapes = dialect == Mysql || dialect == SqlServer
      while i < n {
        let d = chars[i]
        run.write_char(d)
        i = i + 1
        if d == '\\' && escapes && i < n {
          run.write_char(chars[i])
          i = i + 1
        } else if d == '\'' {
          if i < n && chars[i] == '\'' {
            run.write_char('\'')
            i = i + 1
          } else {
            break
          }
        }
      }
      flush(run, out, Quoted, depth)
      continue
    }
    if c == '"' || c == '`' {
      let close = c
      run.write_char(c)
      i = i + 1
      while i < n {
        let d = chars[i]
        run.write_char(d)
        i = i + 1
        if d == close {
          if i < n && chars[i] == close {
            run.write_char(close)
            i = i + 1
          } else {
            break
          }
        }
      }
      flush(run, out, Quoted, depth)
      continue
    }
    if c == '[' && dialect == SqlServer {
      run.write_char(c)
      i = i + 1
      while i < n {
        let d = chars[i]
        run.write_char(d)
        i = i + 1
        if d == ']' {
          if i < n && chars[i] == ']' {
            run.write_char(']')
            i = i + 1
          } else {
            break
          }
        }
      }
      flush(run, out, Quoted, depth)
      continue
    }
    if c == '$' && dialect == Postgres {
      match dollar_tag(chars, i) {
        Some(tag) => {
          let close = "$" + tag + "$"
          run.write_string(close)
          i = i + close.length()
          let body = text_after(chars, i)
          match body.find(close) {
            Some(at) => {
              let end = i + at + close.length()
              while i < end {
                run.write_char(chars[i])
                i = i + 1
              }
            }
            None =>
              while i < n {
                run.write_char(chars[i])
                i = i + 1
              }
          }
          flush(run, out, Quoted, depth)
          continue
        }
        None => ()
      }
    }
    if c == '(' {
      run.write_char(c)
      i = i + 1
      flush(run, out, Punct, depth)
      depth = depth + 1
      continue
    }
    if c == ')' {
      if depth > 0 {
        depth = depth - 1
      }
      run.write_char(c)
      i = i + 1
      flush(run, out, Punct, depth)
      continue
    }
    if is_word_char(c) {
      while i < n && is_word_char(chars[i]) {
        run.write_char(chars[i])
        i = i + 1
      }
      flush(run, out, Word, depth)
      continue
    }
    run.write_char(c)
    i = i + 1
    flush(run, out, Punct, depth)
  }
  out
}

///|
/// The rest of the text from a code-unit offset, for the dollar-quote scan.
fn text_after(chars : Array[Char], from : Int32) -> String {
  let buf = StringBuilder()
  for i in from..<chars.length() {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// A dollar quote's tag holds letters, digits and underscores; the dollars
/// around it are not part of it, which is what makes `$$` its own empty tag.
fn is_tag_char(c : Char) -> Bool {
  ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) ||
  c == '_'
}

///|
/// The `$tag$` opened at `i`, without its dollars; empty when what is there
/// is not a dollar quote. A tag is letters, digits and underscores.
fn dollar_tag(chars : Array[Char], i : Int32) -> String? {
  let n = chars.length()
  let mut j = i + 1
  while j < n && is_tag_char(chars[j]) {
    j = j + 1
  }
  if j < n && chars[j] == '$' {
    let buf = StringBuilder()
    let mut k = i + 1
    while k < j {
      buf.write_char(chars[k])
      k = k + 1
    }
    Some(buf.to_string())
  } else {
    None
  }
}

///|
/// The words of a statement, lowercased, each with its parenthesis depth.
/// Comments, spaces, literals and quoted identifiers are not words.
pub fn words(text : String, dialect : Dialect) -> Array[(String, Int32)] {
  let out : Array[(String, Int32)] = []
  for token in lex(text, dialect) {
    if token.kind == Word {
      out.push((token.text.to_lower(), token.depth))
    }
  }
  out
}
