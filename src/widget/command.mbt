// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One thing the application can do, as the palette lists it.
pub(all) struct Command {
  name : String
  hint : String
  key : String
} derive(Eq, Debug)

///|
pub fn Command::new(
  name : String,
  hint~ : String = "",
  key~ : String = "",
) -> Command {
  { name, hint, key, }
}

///|
/// A field and a list: what a program puts up when the user is to find one of
/// many commands by typing part of its name.
///
/// Typing narrows the list, the arrows move over what is left, Enter runs the
/// one highlighted and Escape closes. A match is the query's characters
/// appearing in the name in order, so `opn` finds `Open file`.
pub struct CommandPalette {
  commands : Array[Command]
  mut query : String
  mut highlighted : Int32
  mut offset : Int32
  mut seen : Int32
  mut run : Int32
  mut focused : Bool
  style : @style.Style
  hint_style : @style.Style
  key_style : @style.Style
  border_style : @style.Style
  field_style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
}

///|
pub fn CommandPalette::new(
  commands~ : Array[Command] = [],
  style~ : @style.Style = @style.default,
  hint_style~ : @style.Style = @style.Style::new(dim=true),
  key_style~ : @style.Style = @style.Style::new(dim=true),
  border_style~ : @style.Style = @style.default,
  field_style~ : @style.Style = @style.Style::new(reverse=true),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
) -> CommandPalette {
  let palette : CommandPalette = {
    commands,
    query: "",
    highlighted: -1,
    offset: 0,
    seen: 0,
    run: -1,
    focused: false,
    style,
    hint_style,
    key_style,
    border_style,
    field_style,
    highlight,
    blurred_highlight,
  }
  palette.first_match()
  palette
}

///|
pub fn CommandPalette::add(
  self : CommandPalette,
  name : String,
  hint~ : String = "",
  key~ : String = "",
) -> Unit {
  self.commands.push(Command::new(name, hint~, key~))
  self.first_match()
}

///|
pub fn CommandPalette::commands(self : CommandPalette) -> Array[Command] {
  self.commands
}

///|
pub fn CommandPalette::query(self : CommandPalette) -> String {
  self.query
}

///|
pub fn CommandPalette::set_query(self : CommandPalette, query : String) -> Unit {
  self.query = query
  self.first_match()
}

///|
/// The command run, if one has been.
pub fn CommandPalette::run(self : CommandPalette) -> Int32? {
  if self.run >= 0 && self.run < self.commands.length() {
    Some(self.run)
  } else {
    None
  }
}

///|
/// What the query narrows the list to, best first, as places in the list of
/// commands.
pub fn CommandPalette::matches(self : CommandPalette) -> Array[Int32] {
  if self.query.length() == 0 {
    let all : Array[Int32] = []
    for i in 0..<self.commands.length() {
      all.push(i)
    }
    return all
  }
  let scored : Array[(Int32, Int32)] = []
  for i in 0..<self.commands.length() {
    match score_of(self.commands[i].name, self.query) {
      Some(score) => scored.push((score, i))
      None => ()
    }
  }
  scored.sort_by_key(entry => entry.0)
  let out : Array[Int32] = []
  for entry in scored {
    out.push(entry.1)
  }
  out
}

///|
pub impl Widget for CommandPalette with fn render_line(self, row, size) {
  if size.width < 2 || size.height < 2 {
    return @strip.Strip::blank(size.width, self.style)
  }
  if row == 0 || row == size.height - 1 {
    return frame_edge(
      size,
      "",
      self.border_style,
      self.border_style,
      top=row == 0,
    )
  }
  let inner_w = size.width - 2
  let at = row - 1
  let body = if at == 0 {
    @strip.Strip::join([
      @strip.Strip::of("> ", self.style),
      @strip.Strip::of(clip_to(self.query, inner_w - 3), self.style),
      @strip.Strip::of(
        " ",
        if self.focused {
          self.field_style
        } else {
          self.style
        },
      ),
    ])
  } else if at == 1 {
    return @strip.Strip::of(
      "├" + repeat_glyph("─", inner_w) + "┤",
      self.border_style,
    )
  } else {
    let rows = at_least_zero(size.height - 5)
    self.seen = rows
    let found = self.matches()
    let place = self.offset + at - 2
    if at - 2 >= rows || place >= found.length() {
      @strip.Strip::blank(inner_w, self.style)
    } else {
      self.command_row(self.commands[found[place]], found[place], inner_w)
    }
  }
  @strip.Strip::join([
    @strip.Strip::of("│", self.border_style),
    body.pad_to(inner_w, self.style),
    @strip.Strip::of("│", self.border_style),
  ])
}

///|
pub impl Widget for CommandPalette with fn hint(self, size) {
  let found = self.matches().length()
  let listed = if found < 10 { found } else { 10 }
  @geom.Size::new(size.width, smallest(listed + 5, size.height))
}

///|
pub impl Widget for CommandPalette with fn handle(self, ctx, msg) {
  self.seen = at_least_zero(ctx.size.height - 5)
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key)
    Paste(text) => {
      self.query = self.query + text
      self.first_match()
      ctx.emit(Changed(id=ctx.id, value=self.query))
      ctx.repaint()
      true
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let at = mouse.y - 1
          let found = self.matches()
          if at >= 2 {
            match found.iter().nth(self.offset + at - 2) {
              Some(index) => self.choose(index, ctx)
              None => ()
            }
          }
          true
        }
        ScrollUp =>
          if self.offset > 0 {
            self.offset = self.offset - 1
            ctx.repaint()
            true
          } else {
            false
          }
        ScrollDown =>
          if self.offset < self.max_offset() {
            self.offset = self.offset + 1
            ctx.repaint()
            true
          } else {
            false
          }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for CommandPalette with fn focusable(_self) {
  true
}

///|
fn CommandPalette::key(
  self : CommandPalette,
  ctx : Ctx,
  key : @event.Key,
) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  match key.code {
    Up => self.step(-1, ctx)
    Down => self.step(1, ctx)
    Home => self.move_to(0, ctx)
    End => self.move_to(self.matches().length() - 1, ctx)
    PageUp => self.step(-at_least_one(self.page_step()), ctx)
    PageDown => self.step(self.page_step(), ctx)
    Escape => {
      ctx.emit(Dismissed(id=ctx.id))
      true
    }
    Enter =>
      match self.matches().iter().nth(self.highlighted) {
        Some(index) => {
          self.choose(index, ctx)
          true
        }
        None => false
      }
    Backspace =>
      if self.query.length() == 0 {
        false
      } else {
        self.query = self.query[0:self.query.length() - 1].to_owned()
        self.first_match()
        ctx.emit(Changed(id=ctx.id, value=self.query))
        ctx.repaint()
        true
      }
    Char(code) =>
      match code.to_char() {
        Some(letter) => {
          self.query = self.query + letter.to_string()
          self.first_match()
          ctx.emit(Changed(id=ctx.id, value=self.query))
          ctx.repaint()
          true
        }
        None => false
      }
    _ => false
  }
}

///|
fn CommandPalette::command_row(
  self : CommandPalette,
  command : Command,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let on = index == self.current()
  let ground = if on {
    if self.focused {
      self.highlight
    } else {
      self.blurred_highlight
    }
  } else {
    self.style
  }
  let tail = if command.key.length() > 0 { " " + command.key } else { "" }
  let room = at_least_zero(width - 3 - @strip.str_cells(tail))
  let label = if command.hint.length() > 0 {
    command.name + "  " + command.hint
  } else {
    command.name
  }
  @strip.Strip::join([
    @strip.Strip::of(" ", ground),
    @strip.Strip::of(clip_to(label, room), ground).pad_to(room, ground),
    @strip.Strip::of(" ", ground),
    @strip.Strip::of(tail, if on { ground } else { self.key_style }),
    @strip.Strip::of(" ", ground),
  ])
}

///|
/// The command highlighted, as a place in the list of commands.
fn CommandPalette::current(self : CommandPalette) -> Int32 {
  match self.matches().iter().nth(self.highlighted) {
    Some(index) => index
    None => -1
  }
}

///|
fn CommandPalette::first_match(self : CommandPalette) -> Unit {
  let found = self.matches()
  self.highlighted = if found.length() > 0 { 0 } else { -1 }
  self.offset = 0
}

///|
fn CommandPalette::step(self : CommandPalette, by : Int32, ctx : Ctx) -> Bool {
  let count = self.matches().length()
  if count == 0 {
    return false
  }
  let from = if self.highlighted < 0 { 0 } else { self.highlighted }
  let next = constrain(from + by, 0, count - 1)
  if next == self.highlighted {
    return true
  }
  self.highlighted = next
  ctx.repaint()
  true
}

///|
fn CommandPalette::move_to(
  self : CommandPalette,
  place : Int32,
  ctx : Ctx,
) -> Bool {
  let count = self.matches().length()
  if count == 0 {
    return false
  }
  let next = constrain(place, 0, count - 1)
  if next == self.highlighted {
    return true
  }
  self.highlighted = next
  ctx.repaint()
  true
}

///|
fn CommandPalette::choose(
  self : CommandPalette,
  index : Int32,
  ctx : Ctx,
) -> Unit {
  self.run = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.repaint()
}

///|
fn CommandPalette::page_step(self : CommandPalette) -> Int32 {
  if self.seen > 1 {
    self.seen - 1
  } else {
    1
  }
}

///|
fn CommandPalette::max_offset(self : CommandPalette) -> Int32 {
  let slack = self.matches().length() - at_least_zero(self.seen)
  if slack < 0 {
    0
  } else {
    slack
  }
}

///|
/// How well `query` reads out of `name`: the fewer characters skipped over and
/// the earlier it starts, the lower the score. No score at all means the
/// query's characters are not there in order.
fn score_of(name : String, query : String) -> Int32? {
  let text = name.to_lower()
  let needle = query.to_lower()
  if needle.length() == 0 {
    return Some(0)
  }
  if needle.length() > text.length() {
    return None
  }
  let mut at = 0
  let mut score = 0
  let mut last = -1
  for i in 0..<needle.length() {
    let wanted = needle[i]
    let mut found = -1
    while at < text.length() {
      if text[at] == wanted {
        found = at
        break
      }
      at = at + 1
    }
    if found < 0 {
      return None
    }
    if last >= 0 {
      score = score + found - last - 1
    } else {
      score = score + found
    }
    last = found
    at = found + 1
  }
  Some(score)
}

///|
pub extend Command with Debug::{to_repr}

///|
pub extend Command with Eq::{not_equal, equal}

///|
pub extend CommandPalette with Widget::{focusable, handle, hint, render_line}
