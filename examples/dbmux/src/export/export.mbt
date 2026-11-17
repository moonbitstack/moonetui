// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A page of a table as CSV, RFC 4180: a field is quoted when it holds a
/// comma, a quote or a line break, quotes inside are doubled, and lines end
/// in CRLF so a spreadsheet on any system reads the file the same way. NULL
/// is the empty field, which is what a database export usually means by it.
pub fn csv(headers : Array[String], rows : Array[Array[@table.Cell]]) -> String {
  let buf = StringBuilder()
  let head : Array[String] = []
  for header in headers {
    head.push(field(header))
  }
  buf.write_string(head.join(","))
  buf.write_string("\r\n")
  for row in rows {
    let line : Array[String] = []
    for cell in row {
      line.push(field(if cell.is_null { "" } else { cell.text }))
    }
    buf.write_string(line.join(","))
    buf.write_string("\r\n")
  }
  buf.to_string()
}

///|
fn field(text : String) -> String {
  if text.contains_char(',') ||
    text.contains_char('"') ||
    text.contains_char('\n') ||
    text.contains_char('\r') {
    "\"" + text.replace_all(old="\"", new="\"\"") + "\""
  } else {
    text
  }
}

///|
/// A page of a table as a JSON array of objects, one per row, the column
/// names as keys and NULL as `null`. Numbers and booleans stay strings: the
/// driver's text is what the table showed, and guessing a type back from it
/// would change a value that happened to look like a number.
pub fn json(
  headers : Array[String],
  rows : Array[Array[@table.Cell]],
) -> String {
  let out : Array[@json.Json] = []
  for row in rows {
    let fields : Map[String, @json.Json] = Map([])
    let mut i = 0
    while i < headers.length() && i < row.length() {
      let cell = row[i]
      fields[headers[i]] = if cell.is_null {
        @json.Json::null()
      } else {
        @json.Json::string(cell.text)
      }
      i = i + 1
    }
    out.push(@json.Json::object(fields))
  }
  @moonjson.dumps(@json.Json::array(out), indent=2)
}
