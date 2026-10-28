// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a list knows and the caller keeps: which row is chosen and how far
/// the view has been scrolled. A widget that takes one is drawn from it and
/// moves it, so two widgets can share a choice and a caller can set either
/// without asking the widget.
pub(all) struct ListState {
  mut selected : Int32
  mut offset : Int32
  mut seen : Int32
  mut followed : Bool
} derive(Eq, Debug)

///|
pub fn ListState::new(selected~ : Int32 = -1, offset~ : Int32 = 0) -> ListState {
  { selected, offset, seen: 0, followed: false, }
}

///|
/// The row chosen, or -1 when none is.
pub fn ListState::selected(self : ListState) -> Int32 {
  self.selected
}

///|
pub fn ListState::offset(self : ListState) -> Int32 {
  self.offset
}

///|
/// How many rows the view last showed.
pub fn ListState::seen(self : ListState) -> Int32 {
  self.seen
}

///|
pub fn ListState::is_set(self : ListState) -> Bool {
  self.selected >= 0
}

///|
pub fn ListState::clear(self : ListState) -> Unit {
  self.selected = -1
}

///|
/// Choose a row, held to the ones there are.
pub fn ListState::select(
  self : ListState,
  index : Int32,
  count : Int32,
) -> Bool {
  let next = if count <= 0 { -1 } else { constrain(index, 0, count - 1) }
  if next == self.selected {
    return false
  }
  self.selected = next
  self.followed = true
  true
}

///|
/// Move the choice by `by` rows, held to the ones there are.
pub fn ListState::move_by(self : ListState, by : Int32, count : Int32) -> Bool {
  if count <= 0 {
    return false
  }
  let from = if self.selected < 0 {
    if by > 0 {
      -1
    } else {
      count
    }
  } else {
    self.selected
  }
  self.select(from + by, count)
}

///|
/// Scroll the view without touching the choice, which is what a wheel does.
pub fn ListState::scroll_by(
  self : ListState,
  dy : Int32,
  count : Int32,
) -> Bool {
  let most = max_offset(count, self.seen)
  let next = constrain(self.offset + dy, 0, most)
  if next == self.offset {
    return false
  }
  self.offset = next
  self.followed = false
  true
}

///|
/// Bring the choice back into view, but only once for each move of it: a view
/// the wheel put somewhere else is left where it is.
pub fn ListState::follow(self : ListState, rows : Int32, count : Int32) -> Unit {
  self.seen = if rows < 0 { 0 } else { rows }
  self.offset = constrain(self.offset, 0, max_offset(count, self.seen))
  if !self.followed || self.selected < 0 || self.seen <= 0 {
    self.followed = false
    return
  }
  if self.selected < self.offset {
    self.offset = self.selected
  } else if self.selected >= self.offset + self.seen {
    self.offset = self.selected - self.seen + 1
  }
  self.followed = false
}

///|
/// What a table knows and the caller keeps: the cell it is on, and how far
/// the rows have been scrolled.
pub(all) struct TableState {
  mut row : Int32
  mut column : Int32
  mut offset : Int32
  mut seen : Int32
  mut followed : Bool
} derive(Eq, Debug)

///|
pub fn TableState::new(
  row~ : Int32 = -1,
  column~ : Int32 = -1,
  offset~ : Int32 = 0,
) -> TableState {
  { row, column, offset, seen: 0, followed: false, }
}

///|
pub fn TableState::row(self : TableState) -> Int32 {
  self.row
}

///|
pub fn TableState::column(self : TableState) -> Int32 {
  self.column
}

///|
pub fn TableState::offset(self : TableState) -> Int32 {
  self.offset
}

///|
pub fn TableState::is_set(self : TableState) -> Bool {
  self.row >= 0 && self.column >= 0
}

///|
pub fn TableState::clear(self : TableState) -> Unit {
  self.row = -1
  self.column = -1
}

///|
/// Go to a cell, held to the ones there are.
pub fn TableState::select(
  self : TableState,
  row : Int32,
  column : Int32,
  rows : Int32,
  columns : Int32,
) -> Bool {
  let next_row = if rows <= 0 { -1 } else { constrain(row, 0, rows - 1) }
  let next_column = if columns <= 0 {
    -1
  } else {
    constrain(column, 0, columns - 1)
  }
  if next_row == self.row && next_column == self.column {
    return false
  }
  self.row = next_row
  self.column = next_column
  self.followed = true
  true
}

///|
pub fn TableState::move_by(
  self : TableState,
  dy : Int32,
  dx : Int32,
  rows : Int32,
  columns : Int32,
) -> Bool {
  if rows <= 0 || columns <= 0 {
    return false
  }
  let from_row = if self.row < 0 {
    if dy > 0 {
      -1
    } else {
      rows
    }
  } else {
    self.row
  }
  let from_column = if self.column < 0 { 0 } else { self.column }
  self.select(from_row + dy, from_column + dx, rows, columns)
}

///|
pub fn TableState::scroll_by(
  self : TableState,
  dy : Int32,
  rows : Int32,
) -> Bool {
  let most = max_offset(rows, self.seen)
  let next = constrain(self.offset + dy, 0, most)
  if next == self.offset {
    return false
  }
  self.offset = next
  self.followed = false
  true
}

///|
pub fn TableState::follow(
  self : TableState,
  seen : Int32,
  rows : Int32,
) -> Unit {
  self.seen = if seen < 0 { 0 } else { seen }
  self.offset = constrain(self.offset, 0, max_offset(rows, self.seen))
  if !self.followed || self.row < 0 || self.seen <= 0 {
    self.followed = false
    return
  }
  if self.row < self.offset {
    self.offset = self.row
  } else if self.row >= self.offset + self.seen {
    self.offset = self.row - self.seen + 1
  }
  self.followed = false
}

///|
/// A list of words drawn from a state the caller keeps: the choice and the
/// scroll are the caller's, so two lists can share them or a caller can set
/// them between frames.
///
/// The arrows move the choice and pull the view to it, a click chooses the row
/// under the pointer, and the wheel scrolls the view on its own.
pub struct StatefulList {
  mut items : Array[String]
  state : ListState
  mut focused : Bool
  style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
}

///|
pub fn StatefulList::new(
  items~ : Array[String] = [],
  state~ : ListState = ListState::new(),
  style~ : @style.Style = @style.default,
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
) -> StatefulList {
  { items, state, focused: false, style, highlight, blurred_highlight, }
}

///|
pub fn StatefulList::items(self : StatefulList) -> Array[String] {
  self.items
}

///|
pub fn StatefulList::set_items(
  self : StatefulList,
  items : Array[String],
) -> Unit {
  self.items = items
}

///|
/// The state this list draws from and moves.
pub fn StatefulList::state(self : StatefulList) -> ListState {
  self.state
}

///|
pub impl Widget for StatefulList with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 {
    return @strip.Strip::empty()
  }
  self.state.follow(size.height, self.items.length())
  let at = self.state.offset + row
  if at < 0 || at >= self.items.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let on = at == self.state.selected
  let ground = if on {
    if self.focused {
      self.highlight
    } else {
      self.blurred_highlight
    }
  } else {
    self.style
  }
  @strip.Strip::of(clip_to(self.items[at], size.width), ground).pad_to(
    size.width,
    ground,
  )
}

///|
pub impl Widget for StatefulList with fn hint(_self, size) {
  @geom.Size::new(size.width, size.height)
}

///|
pub impl Widget for StatefulList with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key, ctx.size.height)
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let at = self.state.offset + mouse.y
          if self.state.select(at, self.items.length()) {
            self.state.follow(ctx.size.height, self.items.length())
            ctx.emit(Selected(id=ctx.id, index=self.state.selected))
            ctx.repaint()
          }
          true
        }
        ScrollUp =>
          if self.state.scroll_by(-1, self.items.length()) {
            ctx.repaint()
            true
          } else {
            false
          }
        ScrollDown =>
          if self.state.scroll_by(1, self.items.length()) {
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
pub impl Widget for StatefulList with fn focusable(_self) {
  true
}

///|
fn StatefulList::key(
  self : StatefulList,
  ctx : Ctx,
  key : @event.Key,
  rows : Int32,
) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  let by = match key.code {
    Up => -1
    Down => 1
    PageUp => -at_least_one(rows - 1)
    PageDown => at_least_one(rows - 1)
    _ =>
      match key.code {
        Home => {
          if self.state.select(0, self.items.length()) {
            self.state.follow(rows, self.items.length())
            ctx.emit(Selected(id=ctx.id, index=self.state.selected))
            ctx.repaint()
          }
          return true
        }
        End => {
          if self.state.select(self.items.length() - 1, self.items.length()) {
            self.state.follow(rows, self.items.length())
            ctx.emit(Selected(id=ctx.id, index=self.state.selected))
            ctx.repaint()
          }
          return true
        }
        _ => return false
      }
  }
  if self.state.move_by(by, self.items.length()) {
    self.state.follow(rows, self.items.length())
    ctx.emit(Selected(id=ctx.id, index=self.state.selected))
    ctx.repaint()
  }
  true
}

///|
/// A table of cells drawn from a state the caller keeps, in the same way.
pub struct StatefulTable {
  mut header : Array[String]
  mut rows : Array[Array[String]]
  state : TableState
  widths : Array[Int32]?
  mut focused : Bool
  style : @style.Style
  header_style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
  column_highlight : @style.Style
}

///|
pub fn StatefulTable::new(
  rows~ : Array[Array[String]] = [],
  header~ : Array[String] = [],
  state~ : TableState = TableState::new(),
  widths~ : Array[Int32]? = None,
  style~ : @style.Style = @style.default,
  header_style~ : @style.Style = @style.Style::new(bold=true),
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
  column_highlight~ : @style.Style = @style.Style::new(underline=true),
) -> StatefulTable {
  {
    header,
    rows,
    state,
    widths,
    focused: false,
    style,
    header_style,
    highlight,
    blurred_highlight,
    column_highlight,
  }
}

///|
pub fn StatefulTable::rows(self : StatefulTable) -> Array[Array[String]] {
  self.rows
}

///|
pub fn StatefulTable::set_rows(
  self : StatefulTable,
  rows : Array[Array[String]],
) -> Unit {
  self.rows = rows
}

///|
pub fn StatefulTable::set_header(
  self : StatefulTable,
  header : Array[String],
) -> Unit {
  self.header = header
}

///|
pub fn StatefulTable::state(self : StatefulTable) -> TableState {
  self.state
}

///|
/// How many columns there are: the widest row, or the header when it is
/// longer.
pub fn StatefulTable::columns(self : StatefulTable) -> Int32 {
  let mut widest = self.header.length()
  for row in self.rows {
    if row.length() > widest {
      widest = row.length()
    }
  }
  widest
}

///|
pub impl Widget for StatefulTable with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 {
    return @strip.Strip::empty()
  }
  let head = if self.header.length() > 0 { 1 } else { 0 }
  if head > 0 && row == 0 {
    return self.header_row(size)
  }
  let body = at_least_zero(size.height - head)
  self.state.follow(body, self.rows.length())
  let at = self.state.offset + row - head
  if at < 0 || at >= self.rows.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  self.cell_row(self.rows[at], at, size)
}

///|
pub impl Widget for StatefulTable with fn hint(_self, size) {
  @geom.Size::new(size.width, size.height)
}

///|
pub impl Widget for StatefulTable with fn handle(self, ctx, msg) {
  let head = if self.header.length() > 0 { 1 } else { 0 }
  let body = at_least_zero(ctx.size.height - head)
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => {
      if !key.mods.is_none() {
        return false
      }
      let (dy, dx) = match key.code {
        Up => (-1, 0)
        Down => (1, 0)
        Left => (0, -1)
        Right => (0, 1)
        PageUp => (-at_least_one(body - 1), 0)
        PageDown => (at_least_one(body - 1), 0)
        _ => return false
      }
      if self.state.move_by(dy, dx, self.rows.length(), self.columns()) {
        self.state.follow(body, self.rows.length())
        ctx.emit(
          CellHighlighted(id=ctx.id, row=self.state.row, col=self.state.column),
        )
        ctx.repaint()
      }
      true
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          if head > 0 && mouse.y == 0 {
            match self.column_at(mouse.x, ctx.size.width) {
              Some(column) => ctx.emit(HeaderSelected(id=ctx.id, col=column))
              None => ()
            }
            return true
          }
          let at = self.state.offset + mouse.y - head
          match self.column_at(mouse.x, ctx.size.width) {
            Some(column) =>
              if self.state.select(
                  at,
                  column,
                  self.rows.length(),
                  self.columns(),
                ) {
                self.state.follow(body, self.rows.length())
                ctx.emit(
                  CellSelected(id=ctx.id, row=self.state.row, col=column),
                )
                ctx.repaint()
              }
            None => ()
          }
          true
        }
        ScrollUp =>
          if self.state.scroll_by(-1, self.rows.length()) {
            ctx.repaint()
            true
          } else {
            false
          }
        ScrollDown =>
          if self.state.scroll_by(1, self.rows.length()) {
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
pub impl Widget for StatefulTable with fn focusable(_self) {
  true
}

///|
fn StatefulTable::header_row(
  self : StatefulTable,
  size : @geom.Size,
) -> @strip.Strip {
  let spans = self.spans(size.width)
  let segs : Array[@strip.Strip] = []
  for i in 0..<self.header.length() {
    let (_, width) = spans[i]
    let ink = if i == self.state.column {
      self.header_style.merge(self.column_highlight)
    } else {
      self.header_style
    }
    segs.push(
      @strip.Strip::of(clip_to(self.header[i], width), ink).pad_to(width, ink),
    )
  }
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
fn StatefulTable::cell_row(
  self : StatefulTable,
  cells : Array[String],
  row : Int32,
  size : @geom.Size,
) -> @strip.Strip {
  let spans = self.spans(size.width)
  let segs : Array[@strip.Strip] = []
  for i in 0..<spans.length() {
    let (_, width) = spans[i]
    let text = if i < cells.length() { cells[i] } else { "" }
    let ink = if i == self.state.column && row == self.state.row {
      if self.focused {
        self.highlight
      } else {
        self.blurred_highlight
      }
    } else if i == self.state.column {
      self.column_highlight
    } else {
      self.style
    }
    segs.push(@strip.Strip::of(clip_to(text, width), ink).pad_to(width, ink))
  }
  @strip.Strip::join(segs).pad_to(size.width, self.style)
}

///|
/// Where each column starts and how wide it is: what the caller gave, or the
/// width shared out evenly.
fn StatefulTable::spans(
  self : StatefulTable,
  width : Int32,
) -> Array[(Int32, Int32)] {
  let count = self.columns()
  let out : Array[(Int32, Int32)] = []
  if count <= 0 {
    return out
  }
  let mut at = 0
  for i in 0..<count {
    let span = match self.widths {
      Some(given) => if i < given.length() { given[i] } else { 0 }
      None => width / count + (if i < width % count { 1 } else { 0 })
    }
    let span = if span < 0 { 0 } else { span }
    out.push((at, span))
    at = at + span
  }
  out
}

///|
fn StatefulTable::column_at(
  self : StatefulTable,
  x : Int32,
  width : Int32,
) -> Int32? {
  let spans = self.spans(width)
  for i in 0..<spans.length() {
    let (start, width) = spans[i]
    if width > 0 && x >= start && x < start + width {
      return Some(i)
    }
  }
  None
}

///|
fn max_offset(count : Int32, seen : Int32) -> Int32 {
  let slack = count - seen
  if slack < 0 {
    0
  } else {
    slack
  }
}

///|
pub extend ListState with Debug::{to_repr}

///|
pub extend ListState with Eq::{not_equal, equal}

///|
pub extend TableState with Debug::{to_repr}

///|
pub extend TableState with Eq::{not_equal, equal}

///|
pub extend StatefulList with Widget::{focusable, handle, hint, render_line}

///|
pub extend StatefulTable with Widget::{focusable, handle, hint, render_line}
