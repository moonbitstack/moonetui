// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The SQL editor's two modes. Vim is the default; `vim = false` in the
/// keymap file starts every editor in insert.
#derive(Eq)
pub(all) enum EditMode {
  Normal
  Insert
}

///|
pub extend EditMode with Eq::{equal, not_equal}

///|
/// A modal line editor: a buffer of lines, a cursor, and the motions and
/// operators that make Vim worth having in a SQL pane. It is a widget because
/// the keys come from the pane that holds it, and a value because everything
/// it does is a function of its own state.
pub struct Editor {
  mut lines : Array[String]
  mut row : Int32
  mut col : Int32
  mut mode : EditMode
  mut pending : String
  mut yank : Array[String]
  undo : Array[(Array[String], Int32, Int32)]
  mut message : String
  /// What the word under the cursor could become, and where that word starts.
  offers : Array[@sqlkit.Candidate]
  mut offer_at : Int32
  mut offer_pick : Int32
}

///|
pub fn Editor::new() -> Editor {
  {
    lines: [""],
    row: 0,
    col: 0,
    mode: Normal,
    pending: "",
    yank: [],
    undo: [],
    message: "",
    offers: [],
    offer_at: 0,
    offer_pick: 0,
  }
}

///|
pub fn Editor::set_mode(self : Editor, mode : EditMode) -> Unit {
  self.mode = mode
}

///|
pub fn Editor::is_insert(self : Editor) -> Bool {
  self.mode is Insert
}

///|
/// The buffer as one string, which is what a query runs.
pub fn Editor::text(self : Editor) -> String {
  self.lines.join("\n")
}

///|
pub fn Editor::set_text(self : Editor, text : String) -> Unit {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_owned())
  }
  self.lines = lines
  if self.lines.length() == 0 {
    self.lines = [""]
  }
  self.row = 0
  self.col = 0
}

///|
/// The line the cursor is on.
fn Editor::line(self : Editor) -> String {
  if self.row < self.lines.length() {
    self.lines[self.row]
  } else {
    ""
  }
}

///|
fn Editor::line_chars(self : Editor) -> Array[Char] {
  self.line().to_array()
}

///|
/// Keep the cursor on a character: the last one on the line, unless the line
/// is empty.
fn Editor::clamp_col(self : Editor, insert : Bool) -> Unit {
  let n = self.line_chars().length()
  let limit = if insert { n } else if n > 0 { n - 1 } else { 0 }
  if self.col > limit {
    self.col = limit
  }
}

///|
fn Editor::remember(self : Editor) -> Unit {
  self.undo.push((self.lines.copy(), self.row, self.col))
  if self.undo.length() > 100 {
    ignore(self.undo.remove(0))
  }
}

///|
pub fn Editor::undo_step(self : Editor) -> Unit {
  if self.undo.length() > 0 {
    let (lines, row, col) = self.undo.pop().unwrap()
    self.lines = lines
    self.row = row
    self.col = col
    self.clamp_col(false)
  }
}

///|
/// A key, consumed. `false` means the pane above wants it.
pub fn Editor::press(self : Editor, key : String) -> Bool {
  if self.mode is Insert {
    return self.press_insert(key)
  }
  self.press_normal(key)
}

///|
fn Editor::press_insert(self : Editor, key : String) -> Bool {
  // An offer takes the keys that choose from it, and any other key closes it
  // and then does its own work, so typing never has to be paused to dismiss a
  // popup that a reader has moved on from.
  if self.offers.length() > 0 {
    if key == "C-n" || key == "down" {
      if self.offer_pick + 1 < self.offers.length() {
        self.offer_pick = self.offer_pick + 1
      }
      return true
    }
    if key == "C-p" || key == "up" {
      if self.offer_pick > 0 {
        self.offer_pick = self.offer_pick - 1
      }
      return true
    }
    if key == "enter" || key == "tab" {
      self.accept_offer()
      return true
    }
    if key == "esc" {
      self.offers.clear()
      return true
    }
    self.offers.clear()
  }
  if key == "esc" {
    self.mode = Normal
    if self.col > 0 {
      self.col = self.col - 1
    }
    self.clamp_col(false)
    true
  } else if key == "enter" {
    let chars = self.line_chars()
    let head = slice_text(chars, 0, self.col)
    let tail = slice_text(chars, self.col, chars.length())
    self.lines[self.row] = head
    self.lines.insert(self.row + 1, tail)
    self.row = self.row + 1
    self.col = 0
    true
  } else if key == "backspace" {
    if self.col > 0 {
      let chars = self.line_chars()
      let head = slice_text(chars, 0, self.col - 1)
      let tail = slice_text(chars, self.col, chars.length())
      self.lines[self.row] = head + tail
      self.col = self.col - 1
    } else if self.row > 0 {
      let tail = self.line()
      self.row = self.row - 1
      self.col = self.line_chars().length()
      self.lines[self.row] = self.line() + tail
      ignore(self.lines.remove(self.row + 1))
    }
    true
  } else if key == "tab" {
    self.insert_text("  ")
    true
  } else if key.length() == 1 {
    self.insert_text(key)
    true
  } else {
    false
  }
}

///|
/// Where the cursor is in the buffer as one number, which is what a word is
/// looked up against.
pub fn Editor::offset(self : Editor) -> Int32 {
  let mut at = 0
  for i in 0..<self.row {
    if i < self.lines.length() {
      at = at + self.lines[i].length() + 1
    }
  }
  at + self.col
}

///|
/// Offer what the word at `at` could become. An empty list closes the popup.
pub fn Editor::offer(
  self : Editor,
  offers : Array[@sqlkit.Candidate],
  at : Int32,
) -> Unit {
  self.offers.clear()
  for offer in offers {
    self.offers.push(offer)
  }
  self.offer_at = at
  self.offer_pick = 0
}

///|
pub fn Editor::offers(self : Editor) -> Array[@sqlkit.Candidate] {
  self.offers
}

///|
pub fn Editor::offer_at(self : Editor) -> Int32 {
  self.offer_at
}

///|
pub fn Editor::offer_pick(self : Editor) -> Int32 {
  self.offer_pick
}

///|
pub fn Editor::close_offers(self : Editor) -> Unit {
  self.offers.clear()
}

///|
/// Take the chosen word: the word the cursor is in is replaced by it, and the
/// cursor lands after it so the next key types on.
pub fn Editor::accept_offer(self : Editor) -> Unit {
  if self.offers.length() == 0 {
    return
  }
  let pick = if self.offer_pick < self.offers.length() {
    self.offers[self.offer_pick].text
  } else {
    ""
  }
  if pick != "" {
    self.remember()
    let chars = self.line_chars()
    let head = slice_text(chars, 0, self.offer_at)
    let tail = slice_text(chars, self.col, chars.length())
    self.lines[self.row] = head + pick + tail
    self.col = self.offer_at + pick.length()
  }
  self.offers.clear()
}

///|
/// The offers, as one row under the query: the chosen one reversed, the rest
/// with the letter that says where each came from.
pub fn Editor::offer_line(self : Editor, width : Int32) -> @strip.Strip {
  let plain = quiet
  let taken = cursor
  let parts : Array[@strip.Strip] = [@strip.Strip::of(" ▸ ", plain)]
  for i in 0..<self.offers.length() {
    let offer = self.offers[i]
    let style = if i == self.offer_pick { taken } else { plain }
    parts.push(
      @strip.Strip::of(
        if i == self.offer_pick {
          " " + offer.text + " "
        } else {
          offer.text
        },
        style,
      ),
    )
    parts.push(@strip.Strip::of(" ", plain))
  }
  @strip.Strip::join(parts).crop(0, width).pad_to(width, plain)
}

///|
pub fn Editor::insert_text(self : Editor, text : String) -> Unit {
  let chars = self.line_chars()
  let head = slice_text(chars, 0, self.col)
  let tail = slice_text(chars, self.col, chars.length())
  self.lines[self.row] = head + text + tail
  self.col = self.col + text.to_array().length()
}

///|
fn Editor::press_normal(self : Editor, key : String) -> Bool {
  // Two-key commands: dd, yy, gg.
  if self.pending == "d" {
    self.pending = ""
    if key == "d" {
      self.remember()
      self.yank = [self.line()]
      if self.lines.length() > 1 {
        ignore(self.lines.remove(self.row))
        if self.row >= self.lines.length() {
          self.row = self.lines.length() - 1
        }
      } else {
        self.lines[0] = ""
      }
      self.col = 0
      self.clamp_col(false)
    }
    return true
  }
  if self.pending == "y" {
    self.pending = ""
    if key == "y" {
      self.yank = [self.line()]
      self.message = "1 line yanked"
    }
    return true
  }
  if self.pending == "g" {
    self.pending = ""
    if key == "g" {
      self.row = 0
      self.col = 0
    }
    return true
  }
  match key {
    "h" => if self.col > 0 { self.col = self.col - 1 }
    "l" =>
      if self.col + 1 < self.line_chars().length() {
        self.col = self.col + 1
      }
    "j" =>
      if self.row + 1 < self.lines.length() {
        self.row = self.row + 1
        self.clamp_col(false)
      }
    "k" =>
      if self.row > 0 {
        self.row = self.row - 1
        self.clamp_col(false)
      }
    "0" => self.col = 0
    "$" => self.col = self.line_chars().length() - 1
    "w" => self.word_forward()
    "b" => self.word_back()
    "i" => self.mode = Insert
    "a" => {
      self.col = self.col + 1
      self.clamp_col(true)
      if self.col > self.line_chars().length() - 1 {
        self.col = self.line_chars().length()
      }
      self.mode = Insert
    }
    "I" => {
      self.col = 0
      self.mode = Insert
    }
    "A" => {
      self.col = self.line_chars().length()
      self.mode = Insert
    }
    "o" => {
      self.remember()
      self.lines.insert(self.row + 1, "")
      self.row = self.row + 1
      self.col = 0
      self.mode = Insert
    }
    "O" => {
      self.remember()
      self.lines.insert(self.row, "")
      self.col = 0
      self.mode = Insert
    }
    "x" => {
      self.remember()
      let chars = self.line_chars()
      if self.col < chars.length() {
        self.lines[self.row] = slice_text(chars, 0, self.col) +
          slice_text(chars, self.col + 1, chars.length())
        self.clamp_col(false)
      }
    }
    "d" => self.pending = "d"
    "y" => self.pending = "y"
    "g" => self.pending = "g"
    "G" => {
      self.row = self.lines.length() - 1
      self.col = 0
    }
    "p" =>
      if self.yank.length() > 0 {
        self.remember()
        self.lines.insert(self.row + 1, self.yank[0])
        self.row = self.row + 1
        self.col = 0
      }
    "u" => self.undo_step()
    _ => return false
  }
  true
}

///|
fn Editor::word_forward(self : Editor) -> Unit {
  let chars = self.line_chars()
  let mut i = self.col
  while i < chars.length() && is_word(chars[i]) {
    i = i + 1
  }
  while i < chars.length() && !is_word(chars[i]) {
    i = i + 1
  }
  self.col = if i < chars.length() { i } else { chars.length() - 1 }
  if self.col < 0 {
    self.col = 0
  }
}

///|
fn Editor::word_back(self : Editor) -> Unit {
  let chars = self.line_chars()
  let mut i = self.col
  if i > 0 {
    i = i - 1
  }
  while i > 0 && !is_word(chars[i]) {
    i = i - 1
  }
  while i > 0 && is_word(chars[i - 1]) {
    i = i - 1
  }
  self.col = i
}

///|
/// The characters from `start` to `end`, as a string. Slicing an array gives
/// a view, and a view's `to_string` is a debug form, not the text.
fn slice_text(chars : Array[Char], start : Int32, end : Int32) -> String {
  let out : Array[Char] = []
  let mut i = if start < 0 { 0 } else { start }
  while i < end && i < chars.length() {
    out.push(chars[i])
    i = i + 1
  }
  String::from_array(out)
}

///|
fn is_word(c : Char) -> Bool {
  ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) ||
  c == '_'
}

///|
/// One line of the buffer: the line number in the gutter and the SQL coloured
/// by what each word is. The cursor is the terminal's own, put there by
/// `spot`. Past the last line there is nothing to number.
pub fn Editor::render_line(
  self : Editor,
  index : Int32,
  size : @geom.Size,
  style : @style.Style,
) -> @strip.Strip {
  if index >= self.lines.length() {
    return @strip.Strip::blank(size.width, style)
  }
  let here = index == self.row
  let number = (index + 1).to_string()
  let gutter = @strip.Strip::of(
    " ".repeat(@cmp.maximum(0, 3 - number.length())) + number + "  ",
    if here {
      quiet
    } else {
      dim
    },
  )
  let chars = self.lines[index].to_array()
  let styles = colours(chars, style)
  let segs : Array[@strip.Seg] = []
  for i in 0..<chars.length() {
    segs.push(@strip.Seg::new(String::from_array([chars[i]]), styles[i]))
  }
  @strip.Strip::join([gutter, @strip.Strip::from_segs(segs)]).pad_to(
    size.width,
    style,
  )
}

///|
/// SQL's own words, for colouring; what `C-n` offers is in `sqlkit`.
let keywords : Array[String] = [
  "select", "from", "where", "and", "or", "not", "insert", "into", "values", "update",
  "set", "delete", "join", "left", "right", "inner", "outer", "full", "cross", "on",
  "group", "by", "order", "having", "limit", "offset", "as", "distinct", "union",
  "all", "create", "table", "drop", "alter", "index", "view", "null", "is", "in",
  "like", "between", "case", "when", "then", "else", "end", "asc", "desc", "with",
  "returning", "exists", "primary", "key", "default", "begin", "commit", "rollback",
]

///|
/// A style per character: keywords in the accent, strings green, numbers
/// amber, a `--` comment faint, the rest in `style`.
fn colours(chars : Array[Char], style : @style.Style) -> Array[@style.Style] {
  let word = @style.Style::new(fg=look.primary, bold=true)
  let string = @style.Style::new(fg=look.success)
  let number = @style.Style::new(fg=look.warning)
  let out = Array::make(chars.length(), style)
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '-' && i + 1 < chars.length() && chars[i + 1] == '-' {
      for j in i..<chars.length() {
        out[j] = dim
      }
      break
    } else if c == '\'' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != '\'' {
        j = j + 1
      }
      for k in i..<@cmp.minimum(j + 1, chars.length()) {
        out[k] = string
      }
      i = j + 1
    } else if c.is_ascii_digit() {
      let mut j = i
      while j < chars.length() && (chars[j].is_ascii_digit() || chars[j] == '.') {
        out[j] = number
        j = j + 1
      }
      i = j
    } else if c.is_ascii_alphabetic() || c == '_' {
      let mut j = i
      while j < chars.length() &&
            (
              chars[j].is_ascii_alphabetic() ||
              chars[j].is_ascii_digit() ||
              chars[j] == '_'
            ) {
        j = j + 1
      }
      let text = String::from_array(chars[i:j].to_owned()).to_lower()
      if keywords.contains(text) {
        for k in i..<j {
          out[k] = word
        }
      }
      i = j
    } else {
      i = i + 1
    }
  }
  out
}

///|
/// The cursor's column and row in the editor's area: past the gutter, by the
/// cells of the characters before it.
pub fn Editor::spot(self : Editor) -> (Int32, Int32) {
  let number = (self.row + 1).to_string()
  let gutter = @cmp.maximum(3, number.length()) + 2
  let line = if self.row < self.lines.length() {
    self.lines[self.row]
  } else {
    ""
  }
  (gutter + @strip.cells_before(line, self.col), self.row)
}
