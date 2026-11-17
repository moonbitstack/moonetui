// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// What a word in the editor could become. Three sources, in the order a reader
// wants them: the tables the connection lists, the columns the open table has,
// and the words SQL itself is made of. The list is small on purpose — a popup
// that covers the query is worse than no popup.

///|
/// Where a candidate comes from, which the popup shows as one letter.
pub(all) enum Kind {
  Keyword
  Table
  Column
}

///|
pub(all) struct Candidate {
  text : String
  kind : Kind
}

///|
/// The words a query is written with. Kept in one place so the popup and the
/// syntax highlighter, if there is one, agree.
pub let keywords : Array[String] = [
  "ADD", "ALL", "ALTER", "AND", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASCADE",
  "CASE", "CAST", "COALESCE", "COLUMN", "COMMIT", "CONSTRAINT", "COUNT", "CREATE",
  "CROSS", "DEFAULT", "DELETE", "DESC", "DISTINCT", "DROP", "ELSE", "END", "EXISTS",
  "EXPLAIN", "FOREIGN", "FROM", "FULL", "GROUP", "HAVING", "IN", "INDEX", "INNER",
  "INSERT", "INTO", "IS", "JOIN", "KEY", "LEFT", "LIKE", "LIMIT", "MAX", "MIN", "NOT",
  "NULL", "OFFSET", "ON", "OR", "ORDER", "OUTER", "PRIMARY", "REFERENCES", "RETURNING",
  "RIGHT", "ROLLBACK", "SELECT", "SET", "SUM", "TABLE", "THEN", "TRANSACTION", "UNION",
  "UNIQUE", "UPDATE", "USING", "VALUES", "VIEW", "WHEN", "WHERE", "WITH",
]

///|
/// How many candidates the popup holds: one line's worth.
const MOST : Int32 = 10

///|
/// The word that ends at `at`: the run of letters, digits and underscores a
/// cursor sits at the end of. An escaped quoted name is not one, so a reader
/// typing `"order lines"` is never offered a completion that would break it.
pub fn word_before(text : String, at : Int32) -> (Int32, String) {
  let chars = text.to_array()
  let limit = if at < chars.length() { at } else { chars.length() }
  let mut start = limit
  while start > 0 && word_char(chars[start - 1]) {
    start = start - 1
  }
  (start, text[start:limit].to_owned())
}

///|
fn word_char(c : Char) -> Bool {
  ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) ||
  c == '_'
}

///|
fn lower(text : String) -> String {
  let out = StringBuilder()
  for c in text.to_array() {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn starts_with(text : String, prefix : String) -> Bool {
  text.length() >= prefix.length() &&
  text.exact_view(start=0, end=prefix.length()) == prefix
}

///|
/// The candidates for `word`: everything whose name starts with it, whatever
/// the case, shortest first, and each name once. An empty word offers nothing,
/// because a list of every word in the language is not a completion.
pub fn complete(
  word : String,
  tables~ : Array[String] = [],
  columns~ : Array[String] = [],
) -> Array[Candidate] {
  if word == "" {
    return []
  }
  let wanted = lower(word)
  let out : Array[Candidate] = []
  let seen : Array[String] = []
  for (pool, kind) in [(tables, Table), (columns, Column)] {
    for name in pool {
      let low = lower(name)
      if low.length() <= wanted.length() || !starts_with(low, wanted) {
        continue
      }
      if seen.contains(low) {
        continue
      }
      seen.push(low)
      out.push(Candidate::new(name, kind))
    }
  }
  for word_sql in keywords {
    let low = lower(word_sql)
    if low.length() <= wanted.length() || !starts_with(low, wanted) {
      continue
    }
    if seen.contains(low) {
      continue
    }
    seen.push(low)
    out.push(Candidate::new(word_sql, Keyword))
  }
  let ranked = sort_best(out)
  while ranked.length() > MOST {
    ignore(ranked.pop())
  }
  ranked
}

///|
/// Shortest first, then by name: the word a reader is most likely to want is
/// the one they have already typed the most of.
fn sort_best(list : Array[Candidate]) -> Array[Candidate] {
  let out : Array[Candidate] = []
  for item in list {
    let mut at = out.length()
    while at > 0 && before(item, out[at - 1]) {
      at = at - 1
    }
    out.insert(at, item)
  }
  out
}

///|
fn before(a : Candidate, b : Candidate) -> Bool {
  if a.text.length() != b.text.length() {
    return a.text.length() < b.text.length()
  }
  a.text.compare(b.text) < 0
}

///|
pub fn Candidate::new(text : String, kind : Kind) -> Candidate {
  { text, kind, }
}

///|
pub fn Candidate::letter(self : Candidate) -> String {
  match self.kind {
    Table => "t"
    Column => "c"
    Keyword => "k"
  }
}
