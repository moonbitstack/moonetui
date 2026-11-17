// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What the keys asked the host to run, collected until the frame ends. The
/// widget tree is synchronous and a database is not, so the pane fills this
/// and the host empties it.
pub struct Bus {
  mut queue : Array[@shell.Command]
}

///|
pub fn Bus::new() -> Bus {
  { queue: [], }
}

///|
pub fn Bus::push(self : Bus, commands : Array[@shell.Command]) -> Unit {
  self.queue.append(commands)
}

///|
pub fn Bus::take(self : Bus) -> Array[@shell.Command] {
  let out = self.queue
  self.queue = []
  out
}

///|
/// The pane that has the keyboard: the grid, the editor, or a dialog drawn
/// over either. Every key of the window arrives here, so the state machine —
/// not the widget tree — decides what a key means.
pub struct Router {
  pane : Int32
  state : @shell.State
  bus : Bus
  list : @widget.ListView
  mut table : @widget.DataTable
  editor : Editor
  style : @style.Style
  cursor_style : @style.Style
  dim_style : @style.Style
}

///|
pub fn Router::new(
  pane : Int32,
  state : @shell.State,
  list : @widget.ListView,
) -> Router {
  {
    pane,
    state,
    bus: Bus::new(),
    list,
    table: @widget.DataTable::new(zebra=true),
    editor: Editor::new(),
    style: @style.Style::new(fg=@style.bright_white),
    cursor_style: @style.Style::new(reverse=true),
    dim_style: @style.Style::new(fg=@style.bright_black),
  }
}

///|
pub fn Router::bus(self : Router) -> Bus {
  self.bus
}

///|
pub fn Router::editor(self : Router) -> Editor {
  self.editor
}

///|
/// Rebuild the table the pane draws from the grid the state holds. The table
/// is a renderer: the cursor and the scroll follow `move_cursor`, and every
/// edit goes through the state first.
pub fn Router::sync(self : Router) -> Unit {
  match self.state.grid_of(self.pane) {
    None => ()
    Some(grid) => {
      let table = @widget.DataTable::new(zebra=true)
      let widths = column_widths(grid)
      let mut at = 0
      for column in grid.visible() {
        let mark = grid.sort_mark(column)
        let label = if mark == "" { column } else { column + " " + mark }
        ignore(table.add_column(label, width=widths[at]))
        at = at + 1
      }
      for row in 0..<grid.row_count() {
        let cells : Array[String] = []
        for column in grid.visible() {
          let cell = grid.cell(row, column)
          cells.push(if cell.is_null { "NULL" } else { cell.text })
        }
        let mark = if grid.is_marked(row) {
          "−"
        } else if grid.changed_rows().contains(row) {
          "*"
        } else {
          ""
        }
        ignore(table.add_row(cells, label=mark))
      }
      table.move_cursor(row=grid.cursor_row, col=grid.cursor_col)
      self.table = table
    }
  }
}

///|
/// A column's width: the header and the longest value on this page, within a
/// readable range, so a note does not take the window and an id is not cut.
fn column_widths(grid : @table.Grid) -> Array[Int32] {
  let columns = grid.visible()
  let out : Array[Int32] = []
  for column in columns {
    let mut width = column.length() + 2
    for row in 0..<grid.row_count() {
      let cell = grid.cell(row, column)
      let text = if cell.is_null { 4 } else { cell.text.length() }
      if text + 2 > width {
        width = text + 2
      }
    }
    out.push(if width > 30 { 30 } else { width })
  }
  out
}

///|
/// Put the cursor where the state says it is, after a key moved it.
fn Router::follow(self : Router) -> Unit {
  match self.state.grid_of(self.pane) {
    None => ()
    Some(grid) => {
      self.table.move_cursor(row=grid.cursor_row, col=grid.cursor_col)
      self.list.select(self.state.tree_at)
    }
  }
}

///|
/// A key, as text. This is the one place the window's keys become the state
/// machine's words.
pub fn Router::press(self : Router, key : String) -> Bool {
  // A control byte arrives with a stray ctrl-space beside it; it is not a key
  // anyone pressed.
  if key == "C- " {
    return true
  }
  // A dialog takes every key but its own.
  match self.state.mode {
    @shell.Mode::Typing
    | @shell.Mode::Preview
    | @shell.Mode::Confirm
    | @shell.Mode::Help
    | @shell.Mode::Palette => {
      let commands = self.state.press(key)
      self.bus.push(commands)
      return true
    }
    @shell.Mode::Browse => ()
  }
  if key == "C-r" {
    let text = self.editor.text().trim().to_owned()
    if text != "" {
      self.bus.push([@shell.Command::RunQuery(text~)])
    }
    return true
  }
  // The editor steps through the queries that ran, newest first, and past the newest to empty.
  if self.state.focus is @shell.Focus::Editor &&
    (key == "C-up" || key == "C-down") {
    let step = if key == "C-up" {
      self.state.history.back()
    } else {
      self.state.history.forward()
    }
    if step is Some(text) {
      self.editor.set_text(text)
    }
    return true
  }
  // `C-n` offers what the word at the cursor could become: the tables the
  // connection lists, the columns of the table that is open, and SQL's own
  // words. What is typed next narrows it; enter takes the chosen one.
  if self.state.focus is @shell.Focus::Editor && key == "C-n" {
    let (at, word) = @sqlkit.word_before(
      self.editor.text(),
      self.editor.offset(),
    )
    let tables : Array[String] = []
    for info in self.state.tables {
      tables.push(info.name)
    }
    let columns : Array[String] = match self.state.grid() {
      Some(grid) => grid.visible()
      None => []
    }
    let offers = @sqlkit.complete(word, tables~, columns~)
    self.editor.offer(offers, at)
    return true
  }
  if self.state.focus is @shell.Focus::Editor {
    if self.editor.press(key) {
      return true
    }
    return false
  }
  if self.state.focus is @shell.Focus::Tree {
    match key {
      "j" | "down" => {
        if self.state.tree_at + 1 < self.state.tables.length() {
          self.state.tree_at = self.state.tree_at + 1
          self.list.select(self.state.tree_at)
        }
        return true
      }
      "k" | "up" => {
        if self.state.tree_at > 0 {
          self.state.tree_at = self.state.tree_at - 1
          self.list.select(self.state.tree_at)
        }
        return true
      }
      _ => ()
    }
  }
  let commands = self.state.press(key)
  self.bus.push(commands)
  self.follow()
  true
}

///|
pub extend Router with @widget.Widget::{focusable, handle, hint, render_line}

///|
/// The strip of tabs above the pane: every tab of this pane, the showing one
/// reversed. It takes the first line; the grid starts under it.
fn Router::tabs_line(self : Router, width : Int32) -> @strip.Strip {
  let parts : Array[@strip.Strip] = []
  match self.state.pane_of(self.pane) {
    None => ()
    Some(pane) => {
      let mut i = 0
      for tab in pane.tabs {
        let label = " " + (i + 1).to_string() + " " + tab.table + " "
        let style = if i == pane.tab {
          @style.Style::new(reverse=true)
        } else {
          @style.Style::new(fg=@style.bright_black)
        }
        parts.push(@strip.Strip::of(label, style))
        i = i + 1
      }
    }
  }
  if parts.length() == 0 {
    parts.push(
      @strip.Strip::of(
        " no tab · enter on a table opens one",
        @style.Style::new(fg=@style.bright_black),
      ),
    )
  }
  @strip.Strip::join(parts).pad_to(width, self.style)
}

///|
/// The lines of a dialog: the preview, the confirmation, the keys, or the
/// palette. Returned as strips so the pane can draw them like any other line.
fn Router::overlay_line(
  self : Router,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let lines : Array[@strip.Strip] = []
  match self.state.mode {
    @shell.Mode::Preview => {
      lines.push(
        @strip.Strip::of("Save", @style.Style::new(bold=true, fg=@style.yellow)),
      )
      for line in self.state.preview.split("\n") {
        let line = line.to_owned()
        lines.push(@strip.Strip::of(line, self.style))
      }
      lines.push(
        @strip.Strip::of("y runs it, any other key cancels", self.dim_style),
      )
    }
    @shell.Mode::Confirm =>
      lines.push(
        @strip.Strip::of(
          self.state.confirm,
          @style.Style::new(bold=true, fg=@style.red),
        ),
      )
    @shell.Mode::Help => {
      lines.push(
        @strip.Strip::of("Keys", @style.Style::new(bold=true, fg=@style.cyan)),
      )
      for (key, action) in self.state.keymap.rows() {
        lines.push(
          @strip.Strip::of("  " + pad_right(key, 10) + action, self.style),
        )
      }
      lines.push(@strip.Strip::of("esc closes", self.dim_style))
    }
    @shell.Mode::Palette => {
      lines.push(
        @strip.Strip::of(
          "> " + self.state.palette_query,
          @style.Style::new(bold=true, fg=@style.cyan),
        ),
      )
      let matches = self.state.palette_matches()
      let mut i = 0
      for item in matches {
        if i > 12 {
          break
        }
        let mark = if i == self.state.palette_pick { "> " } else { "  " }
        lines.push(
          @strip.Strip::of(
            mark + item,
            if i == self.state.palette_pick {
              @style.Style::new(reverse=true)
            } else {
              self.style
            },
          ),
        )
        i = i + 1
      }
    }
    @shell.Mode::Typing =>
      lines.push(
        @strip.Strip::of(
          self.state.prompt + self.state.draft + "▏",
          self.style,
        ),
      )
    @shell.Mode::Browse => ()
  }
  if index < lines.length() {
    lines[index].pad_to(width, self.style)
  } else {
    @strip.Strip::blank(width, self.style)
  }
}

///|
fn pad_right(text : String, width : Int32) -> String {
  if text.length() >= width {
    text
  } else {
    text + String::make(width - text.length(), ' ')
  }
}

///|
pub impl @widget.Widget for Router with fn focusable(_self) {
  true
}

///|
pub impl @widget.Widget for Router with fn hint(self, size) {
  ignore(self)
  size
}

///|
pub impl @widget.Widget for Router with fn handle(self, ctx, msg) {
  match msg {
    @widget.Msg::Key(key) => {
      let text = @keymap.key_text(key)
      if text == "tab" {
        self.state.focus = match self.state.focus {
          @shell.Focus::Tree => @shell.Focus::Grid
          @shell.Focus::Grid => @shell.Focus::Editor
          @shell.Focus::Editor => @shell.Focus::Tree
        }
        return true
      }
      let handled = self.press(text)
      ctx.repaint()
      handled
    }
    @widget.Msg::Paste(text) =>
      if self.state.focus is @shell.Focus::Editor {
        self.editor.insert_text(text)
        ctx.repaint()
        true
      } else {
        false
      }
    _ => false
  }
}

///|
pub impl @widget.Widget for Router with fn render_line(self, index, size) {
  // Line zero is the pane's tab strip; the grid or the editor starts under it.
  let body = if index == 0 {
    @strip.Strip::empty()
  } else if self.state.focus is @shell.Focus::Editor {
    if index == size.height - 1 && self.editor.offers().length() > 0 {
      self.editor.offer_line(size.width)
    } else {
      self.editor.render_line(index - 1, size, self.style, self.cursor_style)
    }
  } else {
    self.table.render_line(index - 1, size)
  }
  match self.state.mode {
    @shell.Mode::Browse =>
      if index == 0 {
        self.tabs_line(size.width)
      } else {
        body
      }
    @shell.Mode::Typing =>
      if index == 0 {
        self.overlay_line(0, size.width)
      } else {
        body
      }
    _ => self.overlay_line(index, size.width)
  }
}
