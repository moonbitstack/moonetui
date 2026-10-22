// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct Input {
  mut text : String
  mut cursor : Int32
  mut offset : Int32
  mut focused : Bool
  placeholder : String
  style : @style.Style
  placeholder_style : @style.Style
  cursor_style : @style.Style
}

///|
pub fn Input::new(
  placeholder~ : String = "",
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
pub fn Input::cursor_column(self : Input, width : Int32) -> Int32 {
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
      ctx.emit(Submitted(id=ctx.id, value=self.text))
      false
    }
    _ => false
  }
}

///|
pub fn Input::insert(self : Input, text : String) -> Unit {
  self.text = self.text[0:self.cursor].to_owned() +
    text +
    self.text[self.cursor:].to_owned()
  self.cursor = self.cursor + text.length()
}

///|
fn Input::prev(self : Input, index : Int32) -> Int32 {
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
fn Input::next(self : Input, index : Int32) -> Int32 {
  if index >= self.text.length() {
    return self.text.length()
  }
  let (_, used) = @strip.code_at(self.text, index)
  index + used
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
  while @strip.cells_before(self.text, self.cursor) -
        @strip.cells_before(self.text, self.offset) >=
        width {
    let (_, used) = @strip.code_at(self.text, self.offset)
    self.offset = self.offset + used
  }
}

///|
fn text_of(code : Int32) -> String {
  let out = StringBuilder()
  match code.to_char() {
    Some(c) => out.write_char(c)
    None => ()
  }
  out.to_string()
}

///|
pub extend Input with Widget::{focusable, handle, hint, render_line}
