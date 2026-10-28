// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a message box is telling the user, which sets the mark beside the
/// text and the colour it is drawn in.
pub(all) enum DialogKind {
  Info
  Question
  Warning
  Error
} derive(Eq, Debug)

///|
pub fn DialogKind::mark(self : DialogKind) -> String {
  match self {
    Info => "i"
    Question => "?"
    Warning => "!"
    Error => "×"
  }
}

///|
pub fn DialogKind::style(self : DialogKind) -> @style.Style {
  match self {
    Info => @style.Style::new(fg=@style.cyan, bold=true)
    Question => @style.Style::new(fg=@style.blue, bold=true)
    Warning => @style.Style::new(fg=@style.yellow, bold=true)
    Error => @style.Style::new(fg=@style.red, bold=true)
  }
}

///|
/// The buttons a dialog usually carries, as labels.
pub let ok : Array[String] = ["OK"]

///|
pub let ok_cancel : Array[String] = ["OK", "Cancel"]

///|
pub let yes_no : Array[String] = ["Yes", "No"]

///|
pub let yes_no_cancel : Array[String] = ["Yes", "No", "Cancel"]

///|
/// A message and a row of buttons inside a frame with a title: the dialog a
/// program puts up to ask something and wait for the answer.
///
/// The keys are the arrows to move between the buttons, Enter to take the one
/// highlighted, the first letter of a button's label to take it, and Escape
/// to close without answering.
pub struct MessageBox {
  mut title : String
  mut message : String
  kind : DialogKind
  buttons : Array[String]
  mut highlighted : Int32
  mut answered : Int32
  mut focused : Bool
  style : @style.Style
  border_style : @style.Style
  title_style : @style.Style
  highlight : @style.Style
}

///|
pub fn MessageBox::new(
  title~ : String = "",
  message~ : String = "",
  kind~ : DialogKind = Info,
  buttons~ : Array[String] = ok,
  style~ : @style.Style = @style.default,
  border_style~ : @style.Style = @style.default,
  title_style~ : @style.Style = @style.Style::new(bold=true),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
) -> MessageBox {
  {
    title,
    message,
    kind,
    buttons,
    highlighted: 0,
    answered: -1,
    focused: false,
    style,
    border_style,
    title_style,
    highlight,
  }
}

///|
pub fn MessageBox::set_message(self : MessageBox, message : String) -> Unit {
  self.message = message
}

///|
pub fn MessageBox::set_title(self : MessageBox, title : String) -> Unit {
  self.title = title
}

///|
/// The button taken, if any has been.
pub fn MessageBox::chosen(self : MessageBox) -> Int32? {
  if self.answered >= 0 && self.answered < self.buttons.length() {
    Some(self.answered)
  } else {
    None
  }
}

///|
pub fn MessageBox::is_answered(self : MessageBox) -> Bool {
  self.answered >= 0
}

///|
/// The label of the button taken, which is what a caller usually tests.
pub fn MessageBox::label(self : MessageBox) -> String? {
  match self.chosen() {
    Some(index) => Some(self.buttons[index])
    None => None
  }
}

///|
pub fn MessageBox::highlighted(self : MessageBox) -> Int32 {
  if self.buttons.length() == 0 {
    -1
  } else {
    self.highlighted
  }
}

///|
pub impl Widget for MessageBox with fn render_line(self, row, size) {
  if size.width < 2 || size.height < 2 {
    return @strip.Strip::blank(size.width, self.style)
  }
  if row == 0 || row == size.height - 1 {
    return frame_edge(
      size,
      self.title,
      self.border_style,
      self.title_style,
      top=row == 0,
    )
  }
  let inner_w = size.width - 2
  let inner_h = size.height - 2
  let at = row - 1
  let body = if inner_h > 0 && at == inner_h - 1 {
    button_row(
      self.buttons,
      self.highlighted,
      inner_w,
      self.style,
      self.highlight,
    )
  } else {
    let lines = self.lines(inner_w - 2)
    if at >= 0 && at < lines.length() {
      let lead = if at == 0 {
        @strip.Strip::of(self.kind.mark() + " ", self.kind.style())
      } else {
        @strip.Strip::blank(2, self.style)
      }
      @strip.Strip::join([lead, @strip.Strip::of(lines[at], self.style)]).pad_to(
        inner_w,
        self.style,
      )
    } else {
      @strip.Strip::blank(inner_w, self.style)
    }
  }
  @strip.Strip::join([
    @strip.Strip::of("│", self.border_style),
    body.pad_to(inner_w, self.style),
    @strip.Strip::of("│", self.border_style),
  ])
}

///|
pub impl Widget for MessageBox with fn hint(self, size) {
  let buttons = button_width(self.buttons)
  let widest = widest_line(self.message)
  let wanted = (if widest > buttons { widest } else { buttons }) + 6
  let width = if wanted < size.width { wanted } else { size.width }
  let lines = wrap_words(self.message, at_least_zero(width - 4)).length()
  @geom.Size::new(width, smallest(lines + 4, size.height))
}

///|
pub impl Widget for MessageBox with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key)
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let inner_w = at_least_zero(ctx.size.width - 2)
          if ctx.size.height >= 3 && mouse.y == ctx.size.height - 2 {
            match button_at(self.buttons, inner_w, mouse.x - 1) {
              Some(index) => self.choose(index, ctx)
              None => ()
            }
          }
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for MessageBox with fn focusable(_self) {
  true
}

///|
fn MessageBox::key(self : MessageBox, ctx : Ctx, key : @event.Key) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  match key.code {
    Left | Up => self.move_to(self.highlighted - 1, ctx)
    Right | Down | Tab => self.move_to(self.highlighted + 1, ctx)
    Enter | Char(32) => {
      self.choose(self.highlighted, ctx)
      true
    }
    Escape => {
      ctx.emit(Dismissed(id=ctx.id))
      true
    }
    Char(code) =>
      match code.to_char() {
        Some(letter) => self.by_letter(letter.to_string(), ctx)
        None => false
      }
    _ => false
  }
}

///|
/// Take the first button whose label starts with this letter.
fn MessageBox::by_letter(self : MessageBox, letter : String, ctx : Ctx) -> Bool {
  let needle = letter.to_lower()
  for i in 0..<self.buttons.length() {
    if self.buttons[i].length() > 0 &&
      self.buttons[i].to_lower().view(start_offset=0, end_offset=1) == needle {
      self.choose(i, ctx)
      return true
    }
  }
  false
}

///|
fn MessageBox::move_to(self : MessageBox, index : Int32, ctx : Ctx) -> Bool {
  let count = self.buttons.length()
  if count == 0 {
    return false
  }
  let next = constrain(index, 0, count - 1)
  if next == self.highlighted {
    return true
  }
  self.highlighted = next
  ctx.repaint()
  true
}

///|
/// Answer with `index` and say so: the button taken, then that the dialog is
/// done.
fn MessageBox::choose(self : MessageBox, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 || index >= self.buttons.length() {
    return
  }
  self.answered = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.emit(Dismissed(id=ctx.id))
  ctx.repaint()
}

///|
fn MessageBox::lines(self : MessageBox, width : Int32) -> Array[String] {
  wrap_words(self.message, width)
}

///|
/// A prompt, a one-line field and a row of buttons: the dialog that asks for
/// a string.
///
/// Typing goes to the field, whatever button is highlighted; the arrows and
/// Tab move between the buttons, Enter takes the one highlighted and Escape
/// takes the last.
pub struct InputBox {
  mut title : String
  mut prompt : String
  field : Input
  buttons : Array[String]
  mut highlighted : Int32
  mut answered : Int32
  style : @style.Style
  border_style : @style.Style
  title_style : @style.Style
  highlight : @style.Style
}

///|
pub fn InputBox::new(
  title~ : String = "",
  prompt~ : String = "",
  value~ : String = "",
  buttons~ : Array[String] = ok_cancel,
  style~ : @style.Style = @style.default,
  border_style~ : @style.Style = @style.default,
  title_style~ : @style.Style = @style.Style::new(bold=true),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
) -> InputBox {
  let field = Input::new(style~)
  if value.length() > 0 {
    field.set(value)
  }
  {
    title,
    prompt,
    field,
    buttons,
    highlighted: 0,
    answered: -1,
    style,
    border_style,
    title_style,
    highlight,
  }
}

///|
pub fn InputBox::set_title(self : InputBox, title : String) -> Unit {
  self.title = title
}

///|
pub fn InputBox::set_prompt(self : InputBox, prompt : String) -> Unit {
  self.prompt = prompt
}

///|
/// What the field holds now.
pub fn InputBox::text(self : InputBox) -> String {
  self.field.text()
}

///|
pub fn InputBox::set(self : InputBox, value : String) -> Unit {
  self.field.set(value)
}

///|
/// The button taken, if any has been.
pub fn InputBox::chosen(self : InputBox) -> Int32? {
  if self.answered >= 0 && self.answered < self.buttons.length() {
    Some(self.answered)
  } else {
    None
  }
}

///|
pub fn InputBox::is_answered(self : InputBox) -> Bool {
  self.answered >= 0
}

///|
pub fn InputBox::label(self : InputBox) -> String? {
  match self.chosen() {
    Some(index) => Some(self.buttons[index])
    None => None
  }
}

///|
pub impl Widget for InputBox with fn render_line(self, row, size) {
  if size.width < 2 || size.height < 2 {
    return @strip.Strip::blank(size.width, self.style)
  }
  if row == 0 || row == size.height - 1 {
    return frame_edge(
      size,
      self.title,
      self.border_style,
      self.title_style,
      top=row == 0,
    )
  }
  let inner_w = size.width - 2
  let inner_h = size.height - 2
  let at = row - 1
  let body = if at == 0 {
    align_line(self.prompt, inner_w, Left, self.style)
  } else if inner_h > 1 && at == inner_h - 1 {
    button_row(
      self.buttons,
      self.highlighted,
      inner_w,
      self.style,
      self.highlight,
    )
  } else if inner_h > 2 && at == 1 {
    self.field.render_line(0, @geom.Size::new(inner_w, 1)).apply(self.style)
  } else {
    @strip.Strip::blank(inner_w, self.style)
  }
  @strip.Strip::join([
    @strip.Strip::of("│", self.border_style),
    body.pad_to(inner_w, self.style),
    @strip.Strip::of("│", self.border_style),
  ])
}

///|
pub impl Widget for InputBox with fn hint(_self, _size) {
  @geom.Size::new(40, 5)
}

///|
pub impl Widget for InputBox with fn handle(self, ctx, msg) {
  let inner_w = at_least_zero(ctx.size.width - 2)
  match msg {
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          if ctx.size.height >= 3 && mouse.y == ctx.size.height - 2 {
            match button_at(self.buttons, inner_w, mouse.x - 1) {
              Some(index) => self.choose(index, ctx)
              None => ()
            }
          } else {
            self.feed_field(ctx, inner_w, Focus(true)) |> ignore
            ctx.repaint()
          }
          true
        }
        _ => false
      }
    Key(key) => self.key(ctx, key)
    Paste(text) => {
      self.feed_field(ctx, inner_w, Paste(text)) |> ignore
      ctx.repaint()
      true
    }
    Focus(gained) => {
      self.feed_field(ctx, inner_w, Focus(gained)) |> ignore
      ctx.repaint()
      true
    }
    _ => false
  }
}

///|
/// Hand a message to the field and pass on what it asks for, minus its own
/// repaints, which the dialog answers with one of its own.
fn InputBox::feed_field(
  self : InputBox,
  ctx : Ctx,
  width : Int32,
  msg : Msg,
) -> Bool {
  let inner = Ctx::new(ctx.id, @geom.Size::new(width, 1), focused=true)
  let took = self.field.handle(inner, msg)
  for out in inner.asked() {
    match out {
      Repaint(..) => ()
      Changed(id~, value~) => ctx.emit(Changed(id~, value~))
      _ => ctx.emit(out)
    }
  }
  took
}

///|
pub impl Widget for InputBox with fn focusable(_self) {
  true
}

///|
fn InputBox::key(self : InputBox, ctx : Ctx, key : @event.Key) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  match key.code {
    Tab | Left | Right | Up | Down =>
      if self.buttons.length() == 0 {
        false
      } else {
        let step = match key.code {
          Left | Up => -1
          _ => 1
        }
        let count = self.buttons.length()
        self.highlighted = (self.highlighted + step + count) % count
        ctx.repaint()
        true
      }
    Enter => {
      self.choose(self.highlighted, ctx)
      true
    }
    Escape => {
      self.choose(self.buttons.length() - 1, ctx)
      true
    }
    _ => {
      let inner_w = at_least_zero(ctx.size.width - 2)
      let took = self.feed_field(ctx, inner_w, Key(key))
      if took {
        ctx.repaint()
      }
      took
    }
  }
}

///|
/// Answer with `index`: what the field held is read with `text`.
fn InputBox::choose(self : InputBox, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 || index >= self.buttons.length() {
    return
  }
  self.answered = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.emit(Dismissed(id=ctx.id))
  ctx.repaint()
}

///|
/// The top or bottom edge of a dialog, with its title let into the top one.
fn frame_edge(
  size : @geom.Size,
  title : String,
  style : @style.Style,
  title_style : @style.Style,
  top~ : Bool,
) -> @strip.Strip {
  let start = if top { thin.top_left } else { thin.bottom_left }
  let end = if top { thin.top_right } else { thin.bottom_right }
  let edge = if top { thin.top } else { thin.bottom }
  if size.width < 2 {
    return @strip.Strip::of(start, style)
  }
  let span = size.width - 2
  if !top || title.length() == 0 {
    return @strip.Strip::of(start + repeat_glyph(edge, span) + end, style)
  }
  let label = " " + title + " "
  if @strip.str_cells(label) >= span {
    return @strip.Strip::join([
      @strip.Strip::of(start, style),
      @strip.Strip::of(clip_to(title, span), title_style).pad_to(
        span, title_style,
      ),
      @strip.Strip::of(end, style),
    ])
  }
  let slack = span - @strip.str_cells(label)
  @strip.Strip::of(
    start +
    repeat_glyph(edge, slack / 2) +
    label +
    repeat_glyph(edge, slack - slack / 2) +
    end,
    style,
  )
}

///|
/// Where each button starts and ends on its row, and how far in the row of
/// them sits.
fn button_layout(
  buttons : Array[String],
  width : Int32,
) -> (Int32, Array[(Int32, Int32)]) {
  let spans : Array[(Int32, Int32)] = []
  let mut at = 0
  for i in 0..<buttons.length() {
    if i > 0 {
      at = at + 2
    }
    let span = @strip.str_cells(buttons[i]) + 2
    spans.push((at, at + span))
    at = at + span
  }
  let left = if at < width { (width - at) / 2 } else { 0 }
  (left, spans)
}

///|
fn button_row(
  buttons : Array[String],
  highlighted : Int32,
  width : Int32,
  style : @style.Style,
  highlight : @style.Style,
) -> @strip.Strip {
  let (left, spans) = button_layout(buttons, width)
  let segs : Array[@strip.Strip] = [@strip.Strip::blank(left, style)]
  let mut at = 0
  for i in 0..<buttons.length() {
    let (start, _) = spans[i]
    segs.push(@strip.Strip::blank(at_least_zero(start - at), style))
    segs.push(
      @strip.Strip::of(
        " " + buttons[i] + " ",
        if i == highlighted {
          highlight
        } else {
          style
        },
      ),
    )
    at = spans[i].1
  }
  segs.push(@strip.Strip::blank(at_least_zero(width - at - left), style))
  @strip.Strip::join(segs)
}

///|
/// The button under `x` on a row `width` wide, if there is one.
fn button_at(buttons : Array[String], width : Int32, x : Int32) -> Int32? {
  let (left, spans) = button_layout(buttons, width)
  for i in 0..<spans.length() {
    let (start, end) = spans[i]
    if x >= left + start && x < left + end {
      return Some(i)
    }
  }
  None
}

///|
fn button_width(buttons : Array[String]) -> Int32 {
  let mut total = 0
  for i in 0..<buttons.length() {
    if i > 0 {
      total = total + 2
    }
    total = total + @strip.str_cells(buttons[i]) + 2
  }
  total
}

///|
fn widest_line(text : String) -> Int32 {
  let mut widest = 0
  for line in split_lines(text) {
    let cells = @strip.str_cells(line)
    if cells > widest {
      widest = cells
    }
  }
  widest
}

///|
/// Words wrapped to `width`, a line at a time, so nothing is cut mid-word
/// while it still fits.
fn wrap_words(text : String, width : Int32) -> Array[String] {
  let out : Array[String] = []
  if width <= 0 {
    return out
  }
  for line in split_lines(text) {
    let words = split_words(line)
    if words.length() == 0 {
      out.push("")
      continue
    }
    let mut current = ""
    for word in words {
      let alone = @strip.str_cells(word)
      if current.length() == 0 {
        current = if alone <= width { word } else { clip_to(word, width) }
        continue
      }
      if @strip.str_cells(current) + 1 + alone <= width {
        current = current + " " + word
      } else {
        out.push(current)
        current = if alone <= width { word } else { clip_to(word, width) }
      }
    }
    out.push(current)
  }
  out
}

///|
fn split_words(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut at = 0
  while at < text.length() {
    let mut end = at
    while end < text.length() && text[end] != ' ' {
      end = end + 1
    }
    if end > at {
      out.push(text[at:end].to_owned())
    }
    at = end + 1
  }
  out
}

///|
pub extend DialogKind with Debug::{to_repr}

///|
pub extend DialogKind with Eq::{not_equal, equal}

///|
pub extend MessageBox with Widget::{focusable, handle, hint, render_line}

///|
pub extend InputBox with Widget::{focusable, handle, hint, render_line}
