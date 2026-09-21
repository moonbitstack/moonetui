// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A single line of editable text.
///
/// The cursor is an index into the text measured in code units, and the view
/// scrolls horizontally to keep it visible. Editing works on code points, so a
/// character that takes two code units — an emoji — is deleted whole, and a wide
/// character moves the cursor two columns while being one character.
pub struct Input {
  mut text : String
  mut cursor : Int
  mut offset : Int
  mut focused : Bool
  placeholder : String
  style : @style.Style
  placeholder_style : @style.Style
  cursor_style : @style.Style
}

///|
/// An empty input, with optional placeholder text shown while it is empty.
pub fn Input::new(
  placeholder? : String = "",
  style? : @style.Style = @style.Style::new(),
  placeholder_style? : @style.Style = @style.Style::new(dim=true),
  cursor_style? : @style.Style = @style.Style::new(reverse=true),
) -> Input {
  {
    text: "",
    cursor: 0,
    offset: 0,
    focused: false,
    placeholder,
    style,
    placeholder_style,
    cursor_style,
  }
}

///|
/// The text as it stands.
pub fn Input::text(self : Input) -> String {
  self.text
}

///|
/// Replace the text, putting the cursor at the end.
pub fn Input::set(self : Input, text : String) -> Unit {
  self.text = text
  self.cursor = text.length()
  self.offset = 0
}

///|
/// Where the cursor sits, as a code unit index.
pub fn Input::cursor(self : Input) -> Int {
  self.cursor
}

///|
/// The column the cursor occupies on screen, given the width it is drawn at.
pub fn Input::cursor_column(self : Input, width : Int) -> Int {
  self.scroll_to_fit(width)
  @strip.cells_before(self.text, self.cursor) -
  @strip.cells_before(self.text, self.offset)
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
  let visible = self.text[self.offset:].to_owned()
  let shown = clip_to(visible, size.width)
  let body = @strip.Strip::of(shown, self.style).pad_to(size.width, self.style)
  if !self.focused {
    return body
  }
  // The cursor is drawn by inverting the column it sits on, which is what a
  // terminal without a real cursor — a recording, a browser grid — still shows
  // correctly.
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
      self.insert(text)
      ctx.emit(Changed(id=ctx.id, value=self.text))
      ctx.repaint()
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
  if key.mods.ctrl || key.mods.alt {
    return false
  }
  match key.code {
    Char(code) => {
      self.insert(text_of(code))
      ctx.emit(Changed(id=ctx.id, value=self.text))
      ctx.repaint()
      true
    }
    Backspace => {
      if self.cursor == 0 {
        return true
      }
      let start = self.prev(self.cursor)
      self.text = self.text[0:start].to_owned() +
        self.text[self.cursor:].to_owned()
      self.cursor = start
      ctx.emit(Changed(id=ctx.id, value=self.text))
      ctx.repaint()
      true
    }
    Delete => {
      if self.cursor >= self.text.length() {
        return true
      }
      let after = self.next(self.cursor)
      self.text = self.text[0:self.cursor].to_owned() +
        self.text[after:].to_owned()
      ctx.emit(Changed(id=ctx.id, value=self.text))
      ctx.repaint()
      true
    }
    Left => {
      self.cursor = self.prev(self.cursor)
      ctx.repaint()
      true
    }
    Right => {
      self.cursor = self.next(self.cursor)
      ctx.repaint()
      true
    }
    Home => {
      self.cursor = 0
      ctx.repaint()
      true
    }
    End => {
      self.cursor = self.text.length()
      ctx.repaint()
      true
    }
    Enter => {
      ctx.emit(Changed(id=ctx.id, value=self.text))
      false
    }
    _ => false
  }
}

///|
/// Insert text at the cursor and leave the cursor after it.
pub fn Input::insert(self : Input, text : String) -> Unit {
  self.text = self.text[0:self.cursor].to_owned() +
    text +
    self.text[self.cursor:].to_owned()
  self.cursor = self.cursor + text.length()
}

///|
/// The code unit index before `index`, respecting surrogate pairs.
fn Input::prev(self : Input, index : Int) -> Int {
  if index <= 0 {
    return 0
  }
  let mut i = 0
  let mut last = 0
  while i < index {
    let (_, used) = @strip.code_at(self.text, i)
    last = i
    i = i + used
  }
  last
}

///|
/// The code unit index after `index`.
fn Input::next(self : Input, index : Int) -> Int {
  if index >= self.text.length() {
    return self.text.length()
  }
  let (_, used) = @strip.code_at(self.text, index)
  index + used
}

///|
/// Scroll the view so the cursor is inside it.
fn Input::scroll_to_fit(self : Input, width : Int) -> Unit {
  if width <= 0 {
    self.offset = 0
    return
  }
  if self.cursor < self.offset {
    self.offset = self.cursor
    return
  }
  // Walk the start of the view forward until the cursor fits, which keeps the
  // view anchored to a character boundary rather than a column.
  while @strip.cells_before(self.text, self.cursor) -
        @strip.cells_before(self.text, self.offset) >=
        width {
    let (_, used) = @strip.code_at(self.text, self.offset)
    self.offset = self.offset + used
  }
}

///|
fn text_of(code : Int) -> String {
  let out = StringBuilder()
  match code.to_char() {
    Some(c) => out.write_char(c)
    None => ()
  }
  out.to_string()
}

///|
pub extend Input with Widget::{focusable, handle, hint, render_line}
