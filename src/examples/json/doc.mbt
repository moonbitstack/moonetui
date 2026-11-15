// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A document opened the way a JSON browser opens one: the path to the cursor
// across the top, the keys folded or open, the type and size of what is under
// the cursor at the foot, and a query that greys out everything it does not
// match. The document is a fixture, so the same cursor lands on the same key.

///|
pub struct Node {
  depth : Int32
  key : String
  kind : String
  text : String
  line : Int32
  mut open : Bool
}

///|
/// The document as a flat list of lines, each with its depth, its key and what
/// it holds. Folding is a flag on a line and a walk over the depths under it.
fn outline() -> Array[Node] {
  let rows : Array[(Int32, String, String, String)] = [
    (0, "", "object", "4 keys"),
    (1, "name", "string", "moonetui"),
    (1, "version", "string", "0.4.0"),
    (1, "license", "string", "Apache-2.0"),
    (1, "keywords", "array", "23 items"),
    (2, "[0]", "string", "terminal"),
    (2, "[1]", "string", "tui"),
    (2, "[2]", "string", "widget"),
    (1, "engines", "object", "1 key"),
    (2, "moon", "string", ">=0.6.0"),
    (1, "targets", "object", "4 keys"),
    (2, "native", "object", "3 keys"),
    (3, "driver", "string", "tty"),
    (3, "width", "number", "78"),
    (3, "colour", "boolean", "true"),
    (2, "wasm", "object", "1 key"),
    (3, "driver", "string", "canvas"),
    (2, "node", "object", "1 key"),
    (3, "driver", "string", "ansi"),
    (2, "serial", "object", "1 key"),
    (3, "driver", "string", "bytes"),
    (1, "packages", "array", "3 items"),
    (2, "[0]", "string", "app"),
    (2, "[1]", "string", "widget"),
    (2, "[2]", "string", "driver"),
  ]
  let out : Array[Node] = []
  let mut line = 1
  for row in rows {
    let (depth, key, kind, text) = row
    out.push({ depth, key, kind, text, line, open: true, })
    line = line + 1
  }
  out
}

///|
pub struct Doc {
  nodes : Array[Node]
  mut cursor : Int32
  mut typing : Bool
  mut query : String
  mut note : String
}

///|
pub fn Doc::new() -> Doc {
  {
    nodes: outline(),
    cursor: 0,
    typing: false,
    query: "",
    note: "← folds · / finds · esc quits",
  }
}

///|
pub fn Doc::at(self : Doc) -> Node {
  self.nodes[self.cursor]
}

///|
/// The lines a reader can see: a folded container hides the lines under it
/// until one at its own depth or above comes along.
pub fn Doc::visible(self : Doc) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut closed = -1
  for i in 0..<self.nodes.length() {
    let node = self.nodes[i]
    if closed >= 0 && node.depth > closed {
      continue
    }
    let folds = node.kind == "object" || node.kind == "array"
    closed = if folds && !node.open { node.depth } else { -1 }
    out.push(i)
  }
  out
}

///|
pub fn Doc::fold(self : Doc) -> Unit {
  let node = self.nodes[self.cursor]
  if node.kind == "object" || node.kind == "array" {
    node.open = !node.open
    self.note = if node.open {
      "opened " + label(node)
    } else {
      "folded " + label(node)
    }
  } else {
    self.note = label(node) + " is a " + node.kind + ", nothing to fold"
  }
  self.settle()
}

///|
fn label(node : Node) -> String {
  if node.key.length() == 0 {
    "the document"
  } else {
    node.key
  }
}

///|
/// The arrows walk the lines that are open, and the cursor skips what is folded
/// away.
pub fn Doc::walk(self : Doc, delta : Int32) -> Unit {
  let rows = self.visible()
  if rows.length() == 0 {
    return
  }
  let mut at = 0
  let mut i = 0
  while i < rows.length() {
    if rows[i] == self.cursor {
      at = i
    }
    i = i + 1
  }
  let mut next = at + delta
  if next < 0 {
    next = 0
  }
  if next > rows.length() - 1 {
    next = rows.length() - 1
  }
  self.cursor = rows[next]
}

///|
/// The path to the cursor, from the outermost key down, the way a reader would
/// type it into a query.
pub fn Doc::path(self : Doc) -> String {
  let keys : Array[String] = []
  let mut depth = self.nodes[self.cursor].depth + 1
  let mut i = self.cursor
  while i >= 0 {
    let node = self.nodes[i]
    if node.depth < depth {
      if node.key.length() > 0 {
        keys.push(node.key)
      }
      depth = node.depth
      if depth == 0 {
        break
      }
    }
    i = i - 1
  }
  if keys.length() == 0 {
    return "$"
  }
  let out = StringBuilder()
  let mut k = keys.length() - 1
  let mut first = true
  while k >= 0 {
    if !first {
      out.write_string(".")
    }
    out.write_string(keys[k])
    first = false
    k = k - 1
  }
  "$." + out.to_string()
}

///|
fn Doc::matches(self : Doc, node : Node) -> Bool {
  if self.query.length() == 0 {
    return true
  }
  holds(node.key, self.query) || holds(node.text, self.query)
}

///|
fn holds(text : String, part : String) -> Bool {
  if part.length() == 0 {
    return true
  }
  if part.length() > text.length() {
    return false
  }
  let mut i = 0
  while i + part.length() <= text.length() {
    if text[i:i + part.length()].to_owned() == part {
      return true
    }
    i = i + 1
  }
  false
}

///|
pub fn Doc::begin(self : Doc) -> Unit {
  self.typing = true
  self.query = ""
  self.note = "type to find · enter keeps it"
}

///|
pub fn Doc::letter(self : Doc, ch : Int32) -> Unit {
  let out = StringBuilder()
  out.write_string(self.query)
  out.write_char(ch.unsafe_to_char())
  self.query = out.to_string()
}

///|
pub fn Doc::rub(self : Doc) -> Unit {
  if self.query.length() > 0 {
    self.query = self.query[0:self.query.length() - 1].to_owned()
  }
}

///|
pub fn Doc::settle(self : Doc) -> Unit {
  self.typing = false
  if self.query.length() == 0 {
    self.note = "← folds · / finds · esc quits"
  } else {
    self.note = "finding " + self.query
  }
}

///|
pub fn Doc::clear(self : Doc) -> Unit {
  self.typing = false
  self.query = ""
  self.note = "query cleared"
}
