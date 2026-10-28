// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One row of a listing, as the caller hands it over. This library never
/// touches a file system: whatever walks the directories is the caller's, and
/// what it finds comes in as this.
pub(all) struct FileEntry {
  name : String
  dir : Bool
  size : Int32
} derive(Eq, Debug)

///|
pub fn FileEntry::new(
  name : String,
  dir~ : Bool = false,
  size~ : Int32 = 0,
) -> FileEntry {
  { name, dir, size, }
}

///|
pub fn FileEntry::is_dir(self : FileEntry) -> Bool {
  self.dir
}

///|
/// Whether to open something that is there, or to name something to write.
pub(all) enum FileMode {
  Open
  Save
} derive(Eq, Debug)

///|
pub fn FileMode::confirm(self : FileMode) -> String {
  match self {
    Open => "Open"
    Save => "Save"
  }
}

///|
/// A listing, a name and two buttons: the dialog that opens or saves a file.
///
/// The entries come from the caller and the caller is told when one is
/// entered, so the walking of directories stays outside this library. The
/// arrows move through the listing, Enter goes into a directory or takes the
/// file named, Escape closes without answering, and a second click on an
/// entry already highlighted goes into it.
pub struct FileDialog {
  mut title : String
  mode : FileMode
  mut path : String
  mut entries : Array[FileEntry]
  mut filter : String
  mut name : String
  mut highlighted : Int32
  mut offset : Int32
  mut seen : Int32
  mut follow : Bool
  mut answered : Int32
  mut focused : Bool
  style : @style.Style
  border_style : @style.Style
  title_style : @style.Style
  dir_style : @style.Style
  size_style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
  field_style : @style.Style
}

///|
pub fn FileDialog::new(
  title~ : String = "",
  path~ : String = "",
  entries~ : Array[FileEntry] = [],
  mode~ : FileMode = Open,
  filter~ : String = "",
  name~ : String = "",
  style~ : @style.Style = @style.default,
  border_style~ : @style.Style = @style.default,
  title_style~ : @style.Style = @style.Style::new(bold=true),
  dir_style~ : @style.Style = @style.Style::new(fg=@style.cyan, bold=true),
  size_style~ : @style.Style = @style.Style::new(dim=true),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
  field_style~ : @style.Style = @style.Style::new(reverse=true),
) -> FileDialog {
  let dialog : FileDialog = {
    title,
    mode,
    path,
    entries,
    filter,
    name,
    highlighted: -1,
    offset: 0,
    seen: 0,
    follow: true,
    answered: -1,
    focused: false,
    style,
    border_style,
    title_style,
    dir_style,
    size_style,
    highlight,
    blurred_highlight,
    field_style,
  }
  dialog.retitle()
  dialog.first_shown()
  dialog
}

///|
pub fn FileDialog::title(self : FileDialog) -> String {
  self.title
}

///|
pub fn FileDialog::set_title(self : FileDialog, title : String) -> Unit {
  self.title = title
}

///|
/// The listing to show, as the caller found it.
pub fn FileDialog::set_entries(
  self : FileDialog,
  entries : Array[FileEntry],
) -> Unit {
  self.entries = entries
  self.first_shown()
}

///|
/// Where the listing was found, as the caller names it.
pub fn FileDialog::set_path(self : FileDialog, path : String) -> Unit {
  self.path = path
}

///|
pub fn FileDialog::path(self : FileDialog) -> String {
  self.path
}

///|
/// Only entries whose name ends this way are listed; directories always are.
pub fn FileDialog::set_filter(self : FileDialog, filter : String) -> Unit {
  self.filter = filter
  self.first_shown()
}

///|
pub fn FileDialog::filter(self : FileDialog) -> String {
  self.filter
}

///|
/// The name to write, which the caller can fill from a listing too.
pub fn FileDialog::set_name(self : FileDialog, name : String) -> Unit {
  self.name = name
}

///|
pub fn FileDialog::name(self : FileDialog) -> String {
  self.name
}

///|
/// The whole answer: the path the caller gave joined to the name.
pub fn FileDialog::value(self : FileDialog) -> String {
  if self.path.length() == 0 {
    return self.name
  }
  if self.path[self.path.length() - 1] == '/' {
    return self.path + self.name
  }
  self.path + "/" + self.name
}

///|
/// The entry highlighted, if the listing has one.
pub fn FileDialog::selected(self : FileDialog) -> FileEntry? {
  match self.shown().iter().nth(self.highlighted) {
    Some(index) => Some(self.entries[index])
    None => None
  }
}

///|
/// The button taken, if any has been.
pub fn FileDialog::chosen(self : FileDialog) -> Int32? {
  if self.answered >= 0 && self.answered < 2 {
    Some(self.answered)
  } else {
    None
  }
}

///|
pub fn FileDialog::is_answered(self : FileDialog) -> Bool {
  self.answered >= 0
}

///|
pub fn FileDialog::buttons(self : FileDialog) -> Array[String] {
  [self.mode.confirm(), "Cancel"]
}

///|
pub impl Widget for FileDialog with fn render_line(self, row, size) {
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
  let shown = self.shown()
  let rows = at_least_zero(inner_h - 3)
  self.seen = rows
  let body = if at == 0 {
    @strip.Strip::of(" " + clip_to(self.path, inner_w - 2), self.title_style).pad_to(
      inner_w,
      self.style,
    )
  } else if inner_h > 1 && at == inner_h - 1 {
    button_row(self.buttons(), 0, inner_w, self.style, self.highlight)
  } else if inner_h > 2 && at == inner_h - 2 {
    self.name_row(inner_w)
  } else {
    let at_entry = at - 1
    let index = match shown.iter().nth(self.offset + at_entry) {
      Some(found) => found
      None => -1
    }
    if index < 0 || at_entry >= rows {
      @strip.Strip::blank(inner_w, self.style)
    } else {
      self.entry_row(self.entries[index], index, inner_w)
    }
  }
  @strip.Strip::join([
    @strip.Strip::of("│", self.border_style),
    body.pad_to(inner_w, self.style),
    @strip.Strip::of("│", self.border_style),
  ])
}

///|
pub impl Widget for FileDialog with fn hint(self, size) {
  let shown = self.shown().length()
  let listed = if shown < 10 { shown } else { 10 }
  @geom.Size::new(size.width, smallest(listed + 5, size.height))
}

///|
pub impl Widget for FileDialog with fn handle(self, ctx, msg) {
  self.seen = at_least_zero(ctx.size.height - 5)
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
          let at = mouse.y - 1
          let inner_h = ctx.size.height - 2
          if ctx.size.height >= 3 && mouse.y == ctx.size.height - 2 {
            match
              button_at(
                self.buttons(),
                at_least_zero(ctx.size.width - 2),
                mouse.x - 1,
              ) {
              Some(index) => self.choose(index, ctx)
              None => ()
            }
          } else if at >= 1 && at <= inner_h - 3 {
            let shown = self.shown()
            match shown.iter().nth(self.offset + at - 1) {
              Some(index) =>
                if index == self.shown_index() {
                  self.enter(index, ctx)
                } else {
                  self.move_to(index, ctx) |> ignore
                }
              None => ()
            }
          }
          true
        }
        ScrollUp =>
          if self.offset > 0 {
            self.offset = self.offset - 1
            self.follow = false
            ctx.repaint()
            true
          } else {
            false
          }
        ScrollDown =>
          if self.offset < self.max_offset() {
            self.offset = self.offset + 1
            self.follow = false
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
pub impl Widget for FileDialog with fn focusable(_self) {
  true
}

///|
fn FileDialog::key(self : FileDialog, ctx : Ctx, key : @event.Key) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  match key.code {
    Up => self.step(-1, ctx)
    Down => self.step(1, ctx)
    PageUp => self.step(-at_least_one(self.page_step()), ctx)
    PageDown => self.step(self.page_step(), ctx)
    Home => self.move_to(0, ctx)
    End => self.move_to(self.shown().length() - 1, ctx)
    Left | Right => {
      ctx.repaint()
      true
    }
    Enter => {
      match self.shown().iter().nth(self.highlighted) {
        Some(index) => self.enter(index, ctx)
        None => self.choose(0, ctx)
      }
      true
    }
    Escape => {
      self.choose(1, ctx)
      true
    }
    Backspace =>
      if self.mode == Save && self.name.length() > 0 {
        self.name = self.name[0:self.name.length() - 1].to_owned()
        ctx.emit(Changed(id=ctx.id, value=self.name))
        ctx.repaint()
        true
      } else {
        false
      }
    Char(code) =>
      match code.to_char() {
        Some(letter) => self.type_char(letter.to_string(), ctx)
        None => false
      }
    _ => false
  }
}

///|
/// In Save, a letter goes into the name; in Open, it jumps to the next entry
/// that starts with it.
fn FileDialog::type_char(self : FileDialog, letter : String, ctx : Ctx) -> Bool {
  if self.mode == Save {
    self.name = self.name + letter
    ctx.emit(Changed(id=ctx.id, value=self.name))
    ctx.repaint()
    return true
  }
  let needle = letter.to_lower()
  let shown = self.shown()
  let from = self.highlighted
  let mut at = 0
  while at < shown.length() {
    let probe = (from + at + 1) % shown.length()
    let entry = self.entries[shown[probe]]
    if entry.name.length() > 0 &&
      entry.name.to_lower().view(start_offset=0, end_offset=1) == needle {
      return self.move_to(probe, ctx)
    }
    at = at + 1
  }
  false
}

///|
/// Enter a directory, or take the file: a directory is reported and left to
/// the caller, which is what walks the tree.
fn FileDialog::enter(self : FileDialog, index : Int32, ctx : Ctx) -> Unit {
  if self.entries[index].dir {
    ctx.emit(Selected(id=ctx.id, index~))
    ctx.repaint()
    return
  }
  self.name = self.entries[index].name
  self.choose(0, ctx)
}

///|
fn FileDialog::step(self : FileDialog, by : Int32, ctx : Ctx) -> Bool {
  let count = self.shown().length()
  if count == 0 {
    return false
  }
  let from = if self.highlighted < 0 { 0 } else { self.highlighted }
  let next = constrain(from + by, 0, count - 1)
  if next == self.highlighted {
    return true
  }
  self.highlighted = next
  self.follow = true
  ctx.repaint()
  true
}

///|
/// Move the highlight to a place in the listing, keeping it in view.
fn FileDialog::move_to(self : FileDialog, place : Int32, ctx : Ctx) -> Bool {
  let count = self.shown().length()
  if count == 0 {
    return false
  }
  let next = constrain(place, 0, count - 1)
  if next == self.highlighted {
    return true
  }
  self.highlighted = next
  self.follow = true
  ctx.repaint()
  true
}

///|
fn FileDialog::choose(self : FileDialog, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 || index >= 2 {
    return
  }
  self.answered = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.emit(Dismissed(id=ctx.id))
  ctx.repaint()
}

///|
fn FileDialog::page_step(self : FileDialog) -> Int32 {
  if self.seen > 1 {
    self.seen - 1
  } else {
    1
  }
}

///|
/// The entries the filter lets through, as places in the listing.
fn FileDialog::shown(self : FileDialog) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in 0..<self.entries.length() {
    if self.entries[i].dir || ends_with(self.entries[i].name, self.filter) {
      out.push(i)
    }
  }
  out
}

///|
fn FileDialog::shown_index(self : FileDialog) -> Int32 {
  match self.shown().iter().nth(self.highlighted) {
    Some(index) => index
    None => -1
  }
}

///|
fn FileDialog::first_shown(self : FileDialog) -> Unit {
  let shown = self.shown()
  self.highlighted = if shown.length() > 0 { 0 } else { -1 }
  self.offset = 0
  self.follow = true
}

///|
fn FileDialog::max_offset(self : FileDialog) -> Int32 {
  let slack = self.shown().length() - at_least_zero(self.seen)
  if slack < 0 {
    0
  } else {
    slack
  }
}

///|
fn FileDialog::retitle(self : FileDialog) -> Unit {
  if self.title.length() == 0 {
    self.title = self.mode.confirm() + " file"
  }
}

///|
fn FileDialog::entry_row(
  self : FileDialog,
  entry : FileEntry,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let on = index == self.shown_index()
  let ground = if on {
    if self.focused {
      self.highlight
    } else {
      self.blurred_highlight
    }
  } else {
    self.style
  }
  let size_text = if entry.dir { "" } else { size_of(entry.size) }
  let room = at_least_zero(width - 2 - 9)
  let label = if entry.dir {
    clip_to(entry.name + "/", room)
  } else {
    clip_to(entry.name, room)
  }
  let name_style = if on {
    ground
  } else if entry.dir {
    self.dir_style
  } else {
    self.style
  }
  let text_style = if on { ground } else { self.size_style }
  let cells = @strip.str_cells(size_text)
  @strip.Strip::join([
    @strip.Strip::of(" ", ground),
    @strip.Strip::of(label, name_style).pad_to(room, ground),
    @strip.Strip::blank(1, ground),
    @strip.Strip::blank(at_least_zero(8 - cells), ground),
    @strip.Strip::of(size_text, text_style),
    @strip.Strip::blank(1, ground),
  ])
}

///|
/// The name row: what will be written, with a caret when it is being typed.
fn FileDialog::name_row(self : FileDialog, width : Int32) -> @strip.Strip {
  let shown = if self.name.length() > 0 {
    self.name
  } else if self.filter.length() > 0 {
    "*." + self.filter
  } else {
    ""
  }
  let room = at_least_zero(width - 3)
  let body = clip_to(shown, room)
  let caret_style = if self.focused { self.field_style } else { self.style }
  @strip.Strip::join([
    @strip.Strip::of("> ", self.style),
    @strip.Strip::of(body, self.style),
    @strip.Strip::of(" ", caret_style),
  ]).pad_to(width, self.style)
}

///|
fn ends_with(text : String, suffix : String) -> Bool {
  if suffix.length() == 0 {
    return true
  }
  if text.length() < suffix.length() {
    return false
  }
  text.view(start_offset=text.length() - suffix.length()).to_lower() ==
  suffix.to_lower()
}

///|
/// Bytes as a short measure: `812`, `4K`, `3M`.
fn size_of(bytes : Int32) -> String {
  if bytes < 1024 {
    return bytes.to_string() + "B"
  }
  if bytes < 1024 * 1024 {
    return (bytes / 1024).to_string() + "K"
  }
  (bytes / (1024 * 1024)).to_string() + "M"
}

///|
pub extend FileEntry with Debug::{to_repr}

///|
pub extend FileEntry with Eq::{not_equal, equal}

///|
pub extend FileMode with Debug::{to_repr}

///|
pub extend FileMode with Eq::{not_equal, equal}

///|
pub extend FileDialog with Widget::{focusable, handle, hint, render_line}
