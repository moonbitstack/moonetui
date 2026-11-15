// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Why a statement needs a confirmation before it runs, or `None` when it does
/// not. The check reads the words: a DELETE or UPDATE with no WHERE of its own
/// (a CTE's, a parenthesised one, and a subquery's all count separately), a
/// TRUNCATE, a DROP, an ALTER TABLE that drops a column, SQL Server's EXEC
/// (it runs whatever the procedure says), and PostgreSQL's EXPLAIN ANALYZE of
/// any of them. What a function body does is invisible here; a guard against
/// slips is not a permission.
pub fn danger(text : String, dialect : Dialect) -> String? {
  let ws = words(text, dialect)
  if ws.length() == 0 {
    return None
  }
  match ws[0].0 {
    "truncate" => return Some("TRUNCATE removes every row")
    "drop" => return Some("DROP removes the object")
    "exec" | "execute" =>
      if dialect == SqlServer {
        return Some("EXEC runs whatever the procedure holds")
      }
    "alter" =>
      if drops_column(ws) {
        return Some("ALTER TABLE ... DROP removes a column")
      }
    "explain" =>
      if dialect == Postgres {
        let mut analyze = false
        for w in ws {
          if w.0 == "analyze" {
            analyze = true
          }
        }
        if analyze {
          // The statement after the options is the one that would run.
          let mut i = 1
          while i < ws.length() && !starts_statement(ws[i].0) {
            i = i + 1
          }
          if i < ws.length() {
            if has_whereless_write_from(ws, i) ||
              ws[i].0 == "truncate" ||
              ws[i].0 == "drop" {
              return Some("EXPLAIN ANALYZE runs the statement")
            }
          }
        }
      }
    _ => ()
  }
  if has_whereless_write_from(ws, 0) {
    return Some("a write with no WHERE touches every row")
  }
  None
}

///|
/// Whether a word begins a statement, so the scan past EXPLAIN's options
/// knows where the statement it explains starts.
fn starts_statement(w : String) -> Bool {
  w == "select" ||
  w == "insert" ||
  w == "update" ||
  w == "delete" ||
  w == "merge" ||
  w == "values" ||
  w == "table" ||
  w == "with" ||
  w == "truncate" ||
  w == "drop" ||
  w == "alter" ||
  w == "create" ||
  w == "exec" ||
  w == "execute"
}

///|
/// Whether any DELETE or UPDATE among the words carries no WHERE of its own,
/// at the depth it sits at: a WHERE deeper belongs to a subquery, and one
/// past the end of the parenthesis the write is in is another statement's.
fn has_whereless_write_from(ws : Array[(String, Int32)], from : Int32) -> Bool {
  for i in from..<ws.length() {
    let (w, d) = ws[i]
    if w != "delete" && w != "update" {
      continue
    }
    let mut j = i + 1
    let mut found = false
    let mut ended = false
    while j < ws.length() && !ended {
      let (v, dj) = ws[j]
      if dj < d {
        ended = true
      } else if dj == d && v == "where" {
        found = true
        ended = true
      }
      j = j + 1
    }
    if !found {
      return true
    }
  }
  false
}

///|
/// Whether an ALTER TABLE takes a column away. A DROP right after a column's
/// name in `ALTER COLUMN x DROP DEFAULT` changes the column and removes no
/// data, so it does not count; a following CONSTRAINT/INDEX/KEY/PRIMARY/
/// FOREIGN/CHECK drops a rule, not a column.
fn drops_column(ws : Array[(String, Int32)]) -> Bool {
  if ws.length() < 2 || ws[1].0 != "table" {
    return false
  }
  let keeps : Array[String] = [
    "constraint", "index", "key", "primary", "foreign", "check",
  ]
  for i in 2..<ws.length() {
    if ws[i].0 != "drop" {
      continue
    }
    let prev2 = if i >= 3 { ws[i - 2].0 } else { "" }
    let prev3 = if i >= 4 { ws[i - 3].0 } else { "" }
    // ALTER COLUMN <name> DROP DEFAULT changes the column, and ALTER <name>
    // DROP <option> does the same; neither takes data away.
    if (prev2 == "column" && prev3 == "alter") || prev2 == "alter" {
      continue
    }
    let next = if i + 1 < ws.length() { ws[i + 1].0 } else { "" }
    if next == "" || !keeps.contains(next) {
      return true
    }
  }
  false
}
