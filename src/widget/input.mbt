// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A single-line text field.
///
/// The keys are Textual's: the arrows and Home and End move, Control with an
/// arrow moves by words, Control-A and Control-E go to either end, Backspace
/// and Delete take a character, Control-W and Control-F a word, Control-U and
/// Control-K everything on that side of the cursor, and Enter submits.
pub struct Input {
  mut text : String
  mut cursor : Int32
  mut offset : Int32
  mut focused : Bool
  placeholder : String
  password : Bool
  max_length : Int32
  style : @style.Style
  placeholder_style : @style.Style
  cursor_style : @style.Style
}

///|
/// An empty field. `password` shows a dot for every character; `max_length`
/// caps how many characters it takes, and zero means no cap.
pub fn Input::new(
  placeholder~ : String = "",
  password~ : Bool = false,
  max_length~ : Int32 = 0,
  style~ : @style.Style = @style.Style::new(),
  placeholder_style~ : @style.Style = @style.Style::new(dim=true),
  cursor_style~ : @style.Style = @style.Style::new(reverse=true),
) -> Input {
  {
    text: "",
    cursor: 0,
    offset: 0,
    focused: false,
    placeholder,
    password,
    max_length,
    style,
    placeholder_style,
    cursor_style,
  }
}

///|
pub fn Input::text(self : Input) -> String {
  self.text
}

///|
/// Replace the text and put the cursor after it.
pub fn Input::set(self : Input, text : String) -> Unit {
  self.text = text
  self.cursor = text.length()
  self.offset = 0
}

///|
pub fn Input::cursor(self : Input) -> Int32 {
  self.cursor
}

///|
/// The column the cursor shows in, once the field is `width` wide.
pub fn Input::cursor_column(self : Input, width : Int32) -> Int32 {
  self.scroll_to_fit(width)
  let shown = self.shown()
  @strip.cells_before(shown, self.shown_index(self.cursor)) -
  @strip.cells_before(shown, self.shown_index(self.offset))
}

///|
pub impl Widget for Input with fn render_line(self, row, size) {
  if row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  if self.text.length() == 0 && !self.focused {
    return align_line(
      clip_to(self.placeholder, size.width),
      size.width,
      Left,
      self.placeholder_style,
    )
  }
  self.scroll_to_fit(size.width)
  let shown = self.shown()
  let visible = shown[self.shown_index(self.offset):].to_owned()
  let body = @strip.Strip::of(clip_to(visible, size.width), self.style).pad_to(
    size.width,
    self.style,
  )
  if !self.focused {
    return body
  }
  let column = self.cursor_column(size.width)
  if column < 0 || column >= size.width {
    return body
  }
  @strip.Strip::join([
    body.crop(0, column),
    body.crop(column, column + 1).apply(self.cursor_style),
    body.crop(column + 1, size.width),
  ])
}

///|
pub impl Widget for Input with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Input with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Paste(text) => {
      let first = match text.find("\n") {
        Some(at) => text[:at].to_owned()
        None => text
      }
      self.edit(ctx, () => self.insert(first.trim_end(chars="\r").to_owned()))
      true
    }
    Key(key) => self.key(ctx, key)
    _ => false
  }
}

///|
pub impl Widget for Input with fn focusable(_self) {
  true
}

///|
fn Input::key(self : Input, ctx : Ctx, key : @event.Key) -> Bool {
  let { ctrl, alt, .. } = key.mods
  if alt {
    return false
  }
  match (key.code, ctrl) {
    (Char(code), false) => self.edit(ctx, () => self.insert(text_of(code)))
    (Left, false) => self.move_to(ctx, prev_char(self.text, self.cursor))
    (Right, false) => self.move_to(ctx, next_char(self.text, self.cursor))
    (Left, true) => self.move_to(ctx, word_start(self.text, self.cursor))
    (Right, true) => self.move_to(ctx, word_end(self.text, self.cursor))
    (Home, _) | (Char(0x61), true) => self.move_to(ctx, 0)
    (End, _) | (Char(0x65), true) => self.move_to(ctx, self.text.length())
    (Backspace, false) =>
      self.edit(ctx, () => {
        self.cut(prev_char(self.text, self.cursor), self.cursor)
      })
    (Backspace, true) | (Char(0x77), true) =>
      self.edit(ctx, () => {
        self.cut(word_start(self.text, self.cursor), self.cursor)
      })
    (Char(0x75), true) => self.edit(ctx, () => self.cut(0, self.cursor))
    (Delete, false) | (Char(0x64), true) =>
      self.edit(ctx, () => {
        self.cut(self.cursor, next_char(self.text, self.cursor))
      })
    (Delete, true) | (Char(0x66), true) =>
      self.edit(ctx, () => {
        self.cut(self.cursor, word_end(self.text, self.cursor))
      })
    (Char(0x6B), true) =>
      self.edit(ctx, () => self.cut(self.cursor, self.text.length()))
    (Enter, false) => {
      ctx.emit(Changed(id=ctx.id, value=self.text))
      ctx.emit(Submitted(id=ctx.id, value=self.text))
      return false
    }
    _ => return false
  }
  true
}

///|
/// Run an edit, and report the text only if the edit changed it.
fn Input::edit(self : Input, ctx : Ctx, change : () -> Unit) -> Unit {
  let before = self.text
  change()
  if self.text != before {
    ctx.emit(Changed(id=ctx.id, value=self.text))
  }
  ctx.repaint()
}

///|
fn Input::move_to(self : Input, ctx : Ctx, index : Int32) -> Unit {
  self.cursor = index
  ctx.repaint()
}

///|
fn Input::cut(self : Input, from : Int32, until : Int32) -> Unit {
  if until <= from {
    return
  }
  self.text = self.text[0:from].to_owned() + self.text[until:].to_owned()
  self.cursor = from
}

///|
/// Insert `text` at the cursor, as much of it as `max_length` leaves room for.
pub fn Input::insert(self : Input, text : String) -> Unit {
  let room = if self.max_length > 0 {
    self.max_length - chars(self.text)
  } else {
    chars(text)
  }
  if room <= 0 {
    return
  }
  let mut end = 0
  let mut taken = 0
  while end < text.length() && taken < room {
    end = next_char(text, end)
    taken += 1
  }
  self.text = self.text[0:self.cursor].to_owned() +
    text[:end].to_owned() +
    self.text[self.cursor:].to_owned()
  self.cursor = self.cursor + end
}

///|
/// The text as it is drawn: itself, or a dot for every character.
fn Input::shown(self : Input) -> String {
  if !self.password {
    return self.text
  }
  let out = StringBuilder()
  for _ in 0..<chars(self.text) {
    out.write_string("•")
  }
  out.to_string()
}

///|
/// Where `index` in the text falls in what is drawn.
fn Input::shown_index(self : Input, index : Int32) -> Int32 {
  if self.password {
    chars(self.text[:index].to_owned())
  } else {
    index
  }
}

///|
fn Input::scroll_to_fit(self : Input, width : Int32) -> Unit {
  if width <= 0 {
    self.offset = 0
    return
  }
  if self.cursor < self.offset {
    self.offset = self.cursor
    return
  }
  let shown = self.shown()
  let column = (index : Int32) => {
    @strip.cells_before(shown, self.shown_index(index))
  }
  while column(self.cursor) - column(self.offset) >= width {
    self.offset = next_char(self.text, self.offset)
  }
}

///|
fn chars(text : String) -> Int32 {
  let mut count = 0
  let mut at = 0
  while at < text.length() {
    at = next_char(text, at)
    count += 1
  }
  count
}

///|
fn text_of(code : Int32) -> String {
  match code.to_char() {
    Some(c) => c.to_string()
    None => ""
  }
}

///|
pub extend Input with Widget::{focusable, handle, hint, render_line}
