// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What the keys do, in columns: a key, right-aligned against its description,
/// so a reader can look one up while a screen of a program is in front of them.
///
/// The panel draws and nothing more. It takes no focus, and a host that wants
/// a binding to act puts the action in its own key handler.
#derive(Eq, Debug)
pub struct KeyPanel {
  mut bindings : Array[(String, String)]
  columns : Int32
  style : @style.Style
  key_style : @style.Style
  note_style : @style.Style
}

///|
pub fn KeyPanel::new(
  bindings~ : Array[(String, String)] = [],
  columns~ : Int32 = 2,
  style~ : @style.Style = @style.default,
  key_style~ : @style.Style = @style.Style::new(bold=true),
  note_style~ : @style.Style = @style.Style::new(dim=true),
) -> KeyPanel {
  { bindings, columns: at_least_one(columns), style, key_style, note_style, }
}

///|
/// The bindings, each a key and what it does.
pub fn KeyPanel::bindings(self : KeyPanel) -> Array[(String, String)] {
  self.bindings
}

///|
pub fn KeyPanel::set_bindings(
  self : KeyPanel,
  bindings : Array[(String, String)],
) -> Unit {
  self.bindings = bindings
}

///|
/// How many columns the panel lays out at a given width: fewer than asked for
/// once a column would be too narrow to read.
fn KeyPanel::columns_at(self : KeyPanel, width : Int32) -> Int32 {
  let roomy = width >= 30 * self.columns
  let fit = at_least_one(width / 30)
  let columns = if roomy { self.columns } else { smallest(self.columns, fit) }
  at_least_one(columns)
}

///|
/// The width of the key field in one column: the longest key, and a space
/// after it, but never more than half a column.
fn KeyPanel::key_field(self : KeyPanel, column : Int32) -> Int32 {
  let mut widest = 0
  for binding in self.bindings {
    let cells = @strip.str_cells(binding.0)
    if cells > widest {
      widest = cells
    }
  }
  let wanted = widest + 1
  let most = at_least_one(column / 2)
  smallest(wanted, most)
}

///|
/// How many rows the whole panel needs at a given width.
pub fn KeyPanel::rows(self : KeyPanel, width : Int32) -> Int32 {
  let columns = self.columns_at(width)
  let count = self.bindings.length()
  if count == 0 {
    0
  } else {
    (count + columns - 1) / columns
  }
}

///|
pub impl Widget for KeyPanel with fn render_line(self, row, size) {
  if size.width <= 0 || row < 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let columns = self.columns_at(size.width)
  let column = size.width / columns
  let field = self.key_field(column)
  let cells : Array[@strip.Strip] = []
  for c in 0..<columns {
    let index = row * columns + c
    if index >= self.bindings.length() {
      cells.push(@strip.Strip::blank(column, self.style))
      continue
    }
    let (key, note) = self.bindings[index]
    let key = clip_to(key, at_least_zero(field - 1))
    let pad = field - @strip.str_cells(key) - 1
    cells.push(
      @strip.Strip::join([
        @strip.Strip::of(repeat_glyph(" ", pad), self.style),
        @strip.Strip::of(key, self.key_style),
        @strip.Strip::of(" ", self.style),
        @strip.Strip::of(
          clip_to(note, at_least_zero(column - field)),
          self.note_style,
        ),
      ]).pad_to(column, self.style),
    )
  }
  @strip.Strip::join(cells).pad_to(size.width, self.style)
}

///|
pub impl Widget for KeyPanel with fn hint(self, size) {
  let rows = self.rows(size.width)
  let height = if rows == 0 { 1 } else { rows }
  @geom.Size::new(size.width, smallest(height, size.height))
}

///|
pub impl Widget for KeyPanel with fn handle(_self, _ctx, _msg) {
  false
}

///|
pub impl Widget for KeyPanel with fn focusable(_self) {
  false
}

///|
pub extend KeyPanel with Debug::{to_repr}

///|
pub extend KeyPanel with Eq::{not_equal, equal}

///|
pub extend KeyPanel with Widget::{focusable, handle, hint, render_line}
