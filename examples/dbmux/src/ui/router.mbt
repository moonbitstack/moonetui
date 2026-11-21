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
  mut table : @widget.DataTable
  editor : Editor
  style : @style.Style
  cursor_style : @style.Style
  dim_style : @style.Style
}

///|
pub fn Router::new(pane : Int32, state : @shell.State) -> Router {
  {
    pane,
    state,
    bus: Bus::new(),
    table: grid_table(active=false),
    editor: Editor::new(),
    style: body,
    cursor_style: cursor,
    dim_style: quiet,
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
      let table = grid_table(active=self.has_keys())
      let widths = column_widths(grid)
      let mut at = 0
      for column in grid.visible() {
        let mark = grid.sort_mark(column)
        let label = if mark == "" { column } else { column + " " + mark }
        let align : @widget.Align = if numeric(grid, column) {
          Right
        } else {
          Left
        }
        ignore(table.add_column(label, width=widths[at], align~))
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
/// Whether this pane is the one the keys go to, with the grid in front.
fn Router::has_keys(self : Router) -> Bool {
  self.state.pane == self.pane && self.state.focus is @shell.Focus::Grid
}

///|
/// A column every value of which on this page is a number reads from the
/// right, so the digits of a total line up.
fn numeric(grid : @table.Grid, column : String) -> Bool {
  let mut seen = false
  for row in 0..<grid.row_count() {
    let cell = grid.cell(row, column)
    if cell.is_null || cell.text == "" {
      continue
    }
    if !is_number(cell.text) {
      return false
    }
    seen = true
  }
  seen
}

///|
fn is_number(text : String) -> Bool {
  let mut digits = 0
  let mut at = 0
  for c in text {
    match c {
      '0'..<='9' => digits = digits + 1
      '-' | '+' if at == 0 => ()
      '.' | ',' | '_' => ()
      _ => return false
    }
    at = at + 1
  }
  digits > 0
}

///|
/// Put the cursor where the state says it is, after a key moved it.
fn Router::follow(self : Router) -> Unit {
  match self.state.grid_of(self.pane) {
    None => ()
    Some(grid) =>
      self.table.move_cursor(row=grid.cursor_row, col=grid.cursor_col)
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
        }
        return true
      }
      "k" | "up" => {
        if self.state.tree_at > 0 {
          self.state.tree_at = self.state.tree_at - 1
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
/// The head of the pane: its tabs, the showing one raised, a hairline to the
/// edge, and how many rows the page holds. The pane with the keys raises its
/// tab in the accent.
fn Router::tabs_line(self : Router, width : Int32) -> @strip.Strip {
  let segs : Array[@strip.Seg] = []
  let active = self.state.pane == self.pane
  let mut rows = ""
  match self.state.pane_of(self.pane) {
    None => ()
    Some(pane) => {
      let mut i = 0
      for tab in pane.tabs {
        let label = " " + (i + 1).to_string() + " " + tab.table + " "
        let style = if i != pane.tab {
          quiet
        } else if active {
          cursor
        } else {
          picked
        }
        segs.push(@strip.Seg::new(label, style))
        segs.push(@strip.Seg::new(" ", body))
        i = i + 1
      }
    }
  }
  match self.state.grid_of(self.pane) {
    Some(grid) => rows = " " + grid.row_count().to_string() + " rows"
    None => ()
  }
  if segs.length() == 0 {
    segs.push(
      @strip.Seg::new("no table open · enter on a table opens one ", quiet),
    )
  }
  let lead = @strip.Strip::from_segs(segs)
  let tally = @strip.Strip::of(rows, dim)
  let room = width -
    @strip.str_cells(lead.text()) -
    @strip.str_cells(tally.text())
  @strip.Strip::join([
    lead,
    @strip.Strip::of("─".repeat(@cmp.maximum(0, room)), look.fg(Border)),
    tally,
  ])
  .crop(0, width)
  .pad_to(width, self.style)
}

///|
/// The lines of a dialog: the preview, the confirmation, the keys, or the
/// palette, each under a head of its own and drawn like any other line.
fn Router::overlay_line(
  self : Router,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let lines : Array[@strip.Strip] = []
  match self.state.mode {
    @shell.Mode::Preview => {
      let statements = self.state.preview.split("\n").to_array()
      lines.push(
        head(
          "save",
          count=statements.length().to_string() + " statements",
          width~,
          active=true,
          tone=Some(look.warning),
        ),
      )
      lines.push(@strip.Strip::empty())
      for line in statements {
        lines.push(@strip.Strip::of(" " + line.to_owned(), self.style))
      }
      lines.push(@strip.Strip::empty())
      lines.push(hint([("y", "run them"), ("any other key", "cancel")]))
    }
    @shell.Mode::Confirm => {
      lines.push(head("confirm", width~, active=true, tone=Some(look.error)))
      lines.push(@strip.Strip::empty())
      lines.push(
        @strip.Strip::of(
          " " + self.state.confirm,
          @style.Style::new(fg=look.error, bold=true),
        ),
      )
    }
    @shell.Mode::Help => {
      let rows = self.state.keymap.rows()
      lines.push(
        head("keys", count=rows.length().to_string(), width~, active=true),
      )
      lines.push(@strip.Strip::empty())
      // Two columns once the pane is wide enough, so the list fits a terminal.
      let half = if width >= 64 {
        (rows.length() + 1) / 2
      } else {
        rows.length()
      }
      for i in 0..<half {
        let parts = [key_row(rows[i])]
        if half < rows.length() && i + half < rows.length() {
          parts.push(@strip.Strip::of("    ", self.style))
          parts.push(key_row(rows[i + half]))
        }
        lines.push(@strip.Strip::join(parts))
      }
      lines.push(@strip.Strip::empty())
      lines.push(hint([("esc", "close")]))
    }
    @shell.Mode::Palette => {
      let matches = self.state.palette_matches()
      lines.push(
        head(
          "command palette",
          count=matches.length().to_string(),
          width~,
          active=true,
        ),
      )
      lines.push(
        @strip.Strip::join([
          @strip.Strip::of(
            " › ",
            @style.Style::new(fg=look.primary, bold=true),
          ),
          @strip.Strip::of(self.state.palette_query, self.style),
        ]),
      )
      lines.push(@strip.Strip::empty())
      let mut i = 0
      for item in matches {
        if i > 12 {
          break
        }
        lines.push(
          if i == self.state.palette_pick {
            @strip.Strip::join([
              @strip.Strip::of(
                "▌",
                @style.Style::new(fg=look.primary, bg=look.panel),
              ),
              @strip.Strip::of(" " + item, picked).pad_to(
                @cmp.minimum(width - 1, 40),
                picked,
              ),
            ])
          } else {
            @strip.Strip::of("  " + item, self.style)
          },
        )
        i = i + 1
      }
      lines.push(@strip.Strip::empty())
      lines.push(
        hint([("↑↓", "choose"), ("enter", "run"), ("esc", "close")]),
      )
    }
    @shell.Mode::Typing =>
      lines.push(
        @strip.Strip::join([
          @strip.Strip::of(
            self.state.prompt,
            @style.Style::new(fg=look.primary, bold=true),
          ),
          @strip.Strip::of(self.state.draft, self.style),
        ]),
      )
    @shell.Mode::Browse => ()
  }
  if index < lines.length() {
    lines[index].crop(0, width).pad_to(width, self.style)
  } else {
    @strip.Strip::blank(width, self.style)
  }
}

///|
/// One key of the help: the key in the accent, what it does beside it.
fn key_row(row : (String, String)) -> @strip.Strip {
  let (key, action) = row
  @strip.Strip::join([
    @strip.Strip::of(
      " " + pad_right(key, 8),
      @style.Style::new(fg=look.primary, bold=true),
    ),
    @strip.Strip::of(pad_right(action, 22), body),
  ])
}

///|
/// The keys a dialog answers, in the muted line under it.
fn hint(pairs : Array[(String, String)]) -> @strip.Strip {
  let parts : Array[@strip.Strip] = [@strip.Strip::of(" ", quiet)]
  for pair in pairs {
    let (key, meaning) = pair
    parts.push(
      @strip.Strip::of(key, @style.Style::new(fg=look.text, bold=true)),
    )
    parts.push(@strip.Strip::of(" " + meaning + "   ", quiet))
  }
  @strip.Strip::join(parts)
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
      self.editor.render_line(index - 1, size, self.style)
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

///|
/// The terminal's cursor goes where the reader types: the prompt on the head
/// line, the palette's query under its head, or the editor, in the shape the
/// keymap gives each of the editor's modes.
pub impl @widget.Widget for Router with fn caret(self, size) {
  if self.state.pane != self.pane {
    return None
  }
  let keymap = self.state.keymap
  let (x, y, caret) = match self.state.mode {
    @shell.Mode::Typing =>
      (
        @strip.str_cells(self.state.prompt) + @strip.str_cells(self.state.draft),
        0,
        keymap.caret_insert,
      )
    @shell.Mode::Palette =>
      (3 + @strip.str_cells(self.state.palette_query), 1, keymap.caret_insert)
    @shell.Mode::Browse if self.state.focus is @shell.Focus::Editor => {
      let (x, row) = self.editor.spot()
      let caret = if self.editor.mode is Insert {
        keymap.caret_insert
      } else {
        keymap.caret_normal
      }
      (x, row + 1, caret)
    }
    _ => return None
  }
  if x >= size.width || y >= size.height {
    return None
  }
  Some(({ x, y, }, caret))
}
