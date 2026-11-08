// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a line of a difference is: unchanged, added, removed, a hunk heading,
/// a file heading, or the note above one.
#derive(Eq, Debug)
pub(all) enum LineKind {
  Context
  Added
  Removed
  Hunk
  Header
  Meta
}

///|
/// One line, with what it is.
#derive(Eq, Debug)
pub(all) struct DiffLine {
  kind : LineKind
  text : String
}

///|
pub fn DiffLine::new(
  kind~ : LineKind = Context,
  text~ : String = "",
) -> DiffLine {
  { kind, text, }
}

///|
pub fn DiffLine::kind(self : DiffLine) -> LineKind {
  self.kind
}

///|
pub fn DiffLine::text(self : DiffLine) -> String {
  self.text
}

///|
/// A difference as a reader of patches expects it: one line a row, added lines
/// marked and coloured, removed lines the other way, headings picked out.
///
/// The arrows walk a line or a screen, Home and End go to the ends, and the
/// wheel moves a line.
#derive(Eq, Debug)
pub struct Diff {
  mut lines : Array[DiffLine]
  mut offset : Int32
  mut focused : Bool
  style : @style.Style
  added_style : @style.Style
  removed_style : @style.Style
  hunk_style : @style.Style
  header_style : @style.Style
  meta_style : @style.Style
}

///|
pub fn Diff::new(
  lines~ : Array[DiffLine] = [],
  offset~ : Int32 = 0,
  style~ : @style.Style = @style.default,
  added_style~ : @style.Style = @style.Style::new(fg=@style.green),
  removed_style~ : @style.Style = @style.Style::new(fg=@style.red),
  hunk_style~ : @style.Style = @style.Style::new(fg=@style.cyan),
  header_style~ : @style.Style = @style.Style::new(bold=true),
  meta_style~ : @style.Style = @style.Style::new(dim=true),
) -> Diff {
  let diff : Diff = {
    lines,
    offset: 0,
    focused: false,
    style,
    added_style,
    removed_style,
    hunk_style,
    header_style,
    meta_style,
  }
  diff.set_offset(offset)
  diff
}

///|
/// Read a unified difference: the `---` and `+++` pair, the `@@` headings, the
/// `+` and `-` lines, and the git notes above them.
///
/// A unified difference prefixes every line it carries, so a blank line is the
/// one byte of padding above or below a patch and is dropped. A line that starts
/// with none of those marks reads as context.
pub fn Diff::of_unified(
  text : String,
  style~ : @style.Style = @style.default,
  added_style~ : @style.Style = @style.Style::new(fg=@style.green),
  removed_style~ : @style.Style = @style.Style::new(fg=@style.red),
  hunk_style~ : @style.Style = @style.Style::new(fg=@style.cyan),
  header_style~ : @style.Style = @style.Style::new(bold=true),
  meta_style~ : @style.Style = @style.Style::new(dim=true),
) -> Diff {
  let lines : Array[DiffLine] = []
  for line in split_lines(text) {
    if line == "" {
      continue
    }
    let kind = if line.has_prefix("--- ") || line.has_prefix("+++ ") {
      Header
    } else if line.has_prefix("@@") {
      Hunk
    } else if line.has_prefix("diff ") || line.has_prefix("index ") {
      Meta
    } else if line.has_prefix("+") {
      Added
    } else if line.has_prefix("-") {
      Removed
    } else {
      Context
    }
    let body = match kind {
      Header => line[4:].to_owned()
      Added | Removed => line[1:].to_owned()
      Context if line.has_prefix(" ") => line[1:].to_owned()
      _ => line
    }
    lines.push({ kind, text: body, })
  }
  Diff::new(
    lines~,
    style~,
    added_style~,
    removed_style~,
    hunk_style~,
    header_style~,
    meta_style~,
  )
}

///|
pub fn Diff::lines(self : Diff) -> Array[DiffLine] {
  self.lines
}

///|
pub fn Diff::set_lines(self : Diff, lines : Array[DiffLine]) -> Unit {
  self.lines = lines
  self.offset = constrain(
    self.offset,
    0,
    at_least_zero(self.lines.length() - 1),
  )
}

///|
/// The line the view starts at.
pub fn Diff::offset(self : Diff) -> Int32 {
  self.offset
}

///|
pub fn Diff::set_offset(self : Diff, offset : Int32) -> Unit {
  self.offset = constrain(offset, 0, at_least_zero(self.lines.length() - 1))
}

///|
/// How many lines were added and how many removed.
pub fn Diff::stats(self : Diff) -> (Int32, Int32) {
  let mut added = 0
  let mut removed = 0
  for line in self.lines {
    match line.kind {
      Added => added = added + 1
      Removed => removed = removed + 1
      _ => ()
    }
  }
  (added, removed)
}

///|
/// The mark in front of a line: a plus, a minus, or the space that keeps the
/// three kinds in one column.
fn mark(kind : LineKind) -> String {
  match kind {
    Added => "+"
    Removed => "-"
    _ => " "
  }
}

///|
fn Diff::ink(self : Diff, kind : LineKind) -> @style.Style {
  match kind {
    Added => self.added_style
    Removed => self.removed_style
    Hunk => self.hunk_style
    Header => self.header_style
    Meta => self.meta_style
    Context => self.style
  }
}

///|
pub impl Widget for Diff with fn render_line(self, row, size) {
  if size.width <= 0 || row < 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let at = self.offset + row
  if at < 0 || at >= self.lines.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let line = self.lines[at]
  let ink = self.ink(line.kind)
  let body = match line.kind {
    Context | Added | Removed => mark(line.kind) + " " + line.text
    _ => line.text
  }
  @strip.Strip::of(clip_to(body, size.width), ink).pad_to(
    size.width,
    self.style,
  )
}

///|
pub impl Widget for Diff with fn hint(_self, size) {
  @geom.Size::new(size.width, size.height)
}

///|
pub impl Widget for Diff with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        let by = match key.code {
          Up => -1
          Down => 1
          PageUp => -at_least_one(ctx.size.height - 1)
          PageDown => at_least_one(ctx.size.height - 1)
          Home => -self.lines.length()
          End => self.lines.length()
          _ => return false
        }
        self.move_to(self.offset + by, ctx)
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          true
        }
        ScrollUp => self.move_to(self.offset - 1, ctx)
        ScrollDown => self.move_to(self.offset + 1, ctx)
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Diff with fn focusable(_self) {
  true
}

///|
fn Diff::move_to(self : Diff, offset : Int32, ctx : Ctx) -> Bool {
  let next = constrain(offset, 0, at_least_zero(self.lines.length() - 1))
  if next == self.offset {
    return false
  }
  self.offset = next
  ctx.emit(Scrolled(id=ctx.id, x=0, y=next))
  ctx.repaint()
  true
}

///|
pub extend LineKind with Debug::{to_repr}

///|
pub extend LineKind with Eq::{not_equal, equal}

///|
pub extend DiffLine with Debug::{to_repr}

///|
pub extend DiffLine with Eq::{not_equal, equal}

///|
pub extend Diff with Debug::{to_repr}

///|
pub extend Diff with Eq::{not_equal, equal}

///|
pub extend Diff with Widget::{focusable, handle, hint, render_line}
