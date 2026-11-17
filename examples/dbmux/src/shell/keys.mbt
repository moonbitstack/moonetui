// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The largest page the LIMIT prompt takes: the rows of one page are all held and drawn.
pub let max_limit : Int32 = 10000

///|
/// What the prompt line is asking for.
#derive(Eq)
pub(all) enum Prompt {
  Filter
  Cell
  Column
}

///|
pub extend Prompt with Eq::{equal, not_equal}

///|
/// Where the save is: the statements written out, waiting for a yes.
pub fn State::press(self : State, key : String) -> Array[Command] {
  let out : Array[Command] = []
  match self.mode {
    Typing =>
      if key == "enter" {
        self.mode = Browse
        let text = self.draft
        self.draft = ""
        out.append(self.apply_prompt(text))
      } else {
        ignore(self.type_key(key))
      }
    Preview =>
      if key == "y" || key == "enter" {
        self.mode = Confirm
        self.confirm = if self.production {
          "Run " +
          self.pending.length().to_string() +
          " statements on PRODUCTION? y / n"
        } else {
          "Run " + self.pending.length().to_string() + " statements? y / n"
        }
      } else if key == "n" || key == "esc" {
        self.mode = Browse
        self.message = "save cancelled"
      }
    Confirm =>
      if key == "y" {
        self.mode = Browse
        out.push(
          Command::Save(statements=self.pending, expected=self.pending_rows),
        )
        self.message = "saving"
      } else if key == "n" || key == "esc" {
        self.mode = Browse
        self.message = "save cancelled"
      }
    Help | Palette =>
      if key == "esc" || key == "q" {
        self.mode = Browse
      } else if self.mode is Palette {
        out.append(self.press_palette(key))
      }
    Browse => out.append(self.press_browse(key))
  }
  out
}

///|
fn State::press_browse(self : State, key : String) -> Array[Command] {
  let out : Array[Command] = []
  match self.keymap.action(key) {
    None => ()
    Some(action) =>
      match action {
        @keymap.Action::Quit => out.push(Command::Quit)
        @keymap.Action::Help => self.mode = Help
        @keymap.Action::Palette => {
          self.mode = Palette
          self.palette_query = ""
          self.palette_pick = 0
        }
        @keymap.Action::FocusNext =>
          self.focus = match self.focus {
            Tree => Grid
            Grid => Editor
            Editor => Tree
          }
        @keymap.Action::FocusLeft | @keymap.Action::FocusRight =>
          self.focus = match self.focus {
            Tree => Grid
            Grid => Tree
            Editor => Grid
          }
        @keymap.Action::Up =>
          match self.focus {
            Tree => if self.tree_at > 0 { self.tree_at = self.tree_at - 1 }
            Grid =>
              match self.grid() {
                Some(grid) => grid.step(-1, 0)
                None => ()
              }
            Editor => ()
          }
        @keymap.Action::Down =>
          match self.focus {
            Tree =>
              if self.tree_at + 1 < self.tables.length() {
                self.tree_at = self.tree_at + 1
              }
            Grid =>
              match self.grid() {
                Some(grid) => grid.step(1, 0)
                None => ()
              }
            Editor => ()
          }
        @keymap.Action::Left =>
          match self.grid() {
            Some(grid) => grid.step(0, -1)
            None => ()
          }
        @keymap.Action::Right =>
          match self.grid() {
            Some(grid) => grid.step(0, 1)
            None => ()
          }
        @keymap.Action::OpenTable =>
          // A Redis keys table opens the key under the cursor; anywhere else
          // the list's selection opens.
          match self.redis_key_under_cursor() {
            Some(name) => out.push(Command::OpenTable(schema=None, table=name))
            None =>
              match self.tree_row() {
                Some(table) =>
                  out.push(
                    Command::OpenTable(schema=table.schema, table=table.name),
                  )
                None => self.message = "no table under the cursor"
              }
          }
        @keymap.Action::Reload => out.push(Command::Reload)
        @keymap.Action::Sort =>
          match self.grid() {
            Some(grid) =>
              match grid.cursor_column() {
                Some(column) => {
                  grid.press_column(column)
                  out.push(Command::Reload)
                }
                None => ()
              }
            None => ()
          }
        @keymap.Action::Filter => {
          self.mode = Typing
          self.draft = match self.grid() {
            Some(grid) => grid.filter
            None => ""
          }
          self.prompt = "WHERE "
        }
        @keymap.Action::FilterCell =>
          match self.grid() {
            Some(grid) =>
              match grid.filter_for_cell(self.dialect) {
                Some(text) => {
                  grid.filter = text
                  grid.offset = 0L
                  out.push(Command::Reload)
                }
                None => ()
              }
            None => ()
          }
        @keymap.Action::ClearFilter =>
          match self.grid() {
            Some(grid) => {
              grid.filter = ""
              grid.offset = 0L
              out.push(Command::Reload)
            }
            None => ()
          }
        @keymap.Action::EditCell =>
          match self.grid() {
            Some(grid) =>
              match grid.cursor_column() {
                Some(column) => {
                  self.mode = Typing
                  self.draft = grid.cell(grid.cursor_row, column).text
                  self.prompt = column + " = "
                  self.pending = [column]
                }
                None => ()
              }
            None => ()
          }
        @keymap.Action::AddRow =>
          match self.grid() {
            Some(grid) => {
              ignore(grid.add_row())
              self.message = "row added"
            }
            None => ()
          }
        @keymap.Action::DeleteRow =>
          match self.grid() {
            Some(grid) => {
              grid.toggle_delete(grid.cursor_row)
              self.message = if grid.is_marked(grid.cursor_row) {
                "row marked for deletion"
              } else {
                "mark taken back"
              }
            }
            None => ()
          }
        @keymap.Action::Save =>
          match self.grid() {
            Some(grid) =>
              if self.read_only {
                self.message = "this connection is read-only"
              } else if !grid.is_dirty() {
                self.message = "nothing to save"
              } else {
                // A Redis key is not a table: what a change means depends on
                // the type it holds, and `redis_plan` writes the command.
                match
                  (if self.engine is @config.Engine::Redis {
                    Ok(@table.redis_plan(grid)) catch {
                      @table.Refused(text~) => Err(text)
                    }
                  } else {
                    Ok(@table.plan(grid, self.dialect)) catch {
                      @table.Refused(text~) => Err(text)
                    }
                  }) {
                  Ok(plan) => {
                    self.pending = plan.statements
                    self.pending_rows = []
                    for _ in plan.statements {
                      self.pending_rows.push(1L)
                    }
                    self.mode = Preview
                    self.preview = plan.summary() +
                      "\n\n" +
                      plan.statements.join(";\n\n")
                  }
                  Err(text) => self.message = text
                }
              }
            None => ()
          }
        @keymap.Action::Revert =>
          match self.grid() {
            Some(grid) => {
              grid.revert()
              self.message = "changes taken back"
            }
            None => ()
          }
        @keymap.Action::Transpose =>
          match self.grid() {
            Some(grid) => grid.transposed = !grid.transposed
            None => ()
          }
        @keymap.Action::Columns =>
          match self.grid() {
            Some(grid) =>
              match grid.cursor_column() {
                Some(column) =>
                  if grid.hidden.contains(column) {
                    grid.hidden = grid.hidden.filter(fn(c) { c != column })
                  } else {
                    grid.hidden.push(column)
                  }
                None => ()
              }
            None => ()
          }
        // The page size and the shown columns are asked on the prompt line, filled with what is
        // in force so that an edit starts from it.
        @keymap.Action::Limit =>
          match self.grid() {
            Some(grid) => {
              self.mode = Typing
              self.prompt = "LIMIT "
              self.draft = grid.limit.to_string()
            }
            None => ()
          }
        @keymap.Action::PickColumns =>
          match self.grid() {
            Some(grid) => {
              self.mode = Typing
              self.prompt = "columns: "
              self.draft = grid.page.columns
                .filter(c => !grid.hidden.contains(c))
                .join(", ")
            }
            None => ()
          }
        @keymap.Action::ExportCsv =>
          match self.grid() {
            Some(grid) =>
              out.push(Command::ExportCsv(path=grid.page.table + ".csv"))
            None => ()
          }
        @keymap.Action::ExportJson =>
          match self.grid() {
            Some(grid) =>
              out.push(Command::ExportJson(path=grid.page.table + ".json"))
            None => ()
          }
        @keymap.Action::RunQuery => ()
        @keymap.Action::NextTab => self.next_tab()
        @keymap.Action::PrevTab => self.prev_tab()
        @keymap.Action::CloseTab => self.close_tab()
        @keymap.Action::SplitRight => self.split(Layout::SplitVertical)
        @keymap.Action::SplitDown => self.split(Layout::SplitHorizontal)
        @keymap.Action::OtherPane => self.other_pane()
        @keymap.Action::ClosePane => self.unsplit()
        @keymap.Action::PageNext =>
          match self.grid() {
            Some(grid) => if grid.turn_page(true) { out.push(Command::Reload) }
            None => ()
          }
        @keymap.Action::PagePrev =>
          match self.grid() {
            Some(grid) => if grid.turn_page(false) { out.push(Command::Reload) }
            None => ()
          }
      }
  }
  out
}

///|
/// The Redis key under the grid's cursor, as the virtual table that shows it,
/// or `None` when the grid is not a list of keys.
pub fn State::redis_key_under_cursor(self : State) -> String? {
  if !(self.engine is @config.Engine::Redis) {
    return None
  }
  match self.grid() {
    None => None
    Some(grid) =>
      if grid.page.table != "keys" || grid.row_count() == 0 {
        None
      } else {
        let cell = grid.cell(grid.cursor_row, "key")
        if cell.is_null || cell.text == "" {
          None
        } else {
          Some("key:" + cell.text)
        }
      }
  }
}

///|
/// The prompt was answered: a filter, a cell's new value, or nothing.
fn State::apply_prompt(self : State, text : String) -> Array[Command] {
  let out : Array[Command] = []
  match self.grid() {
    None => ()
    Some(grid) =>
      if self.prompt == "WHERE " {
        grid.filter = text
        grid.offset = 0L
        out.push(Command::Reload)
      } else if self.prompt == "LIMIT " {
        let rows = @string.parse_int(text.trim()) catch { _ => 0 }
        if rows >= 1 && rows <= max_limit {
          grid.limit = rows
          grid.offset = 0L
          out.push(Command::Reload)
        } else {
          self.message = "LIMIT is a number from 1 to \{max_limit}"
        }
      } else if self.prompt == "columns: " {
        // The columns named stay, in the table's own order; the rest are hidden. A name the
        // table does not have is passed over, and naming none keeps what was shown.
        let named = text.split(",").map(n => n.trim().to_owned()).collect()
        let shown = grid.page.columns.filter(c => named.contains(c))
        if shown.length() == 0 {
          self.message = "no column of this table was named"
        } else {
          grid.hidden = grid.page.columns.filter(c => !shown.contains(c))
        }
      } else if self.pending.length() == 1 {
        let column = self.pending[0]
        grid.set_cell(grid.cursor_row, column, @table.Cell::of(text))
        self.message = "cell changed; C-s saves"
      }
  }
  self.pending = []
  self.prompt = ""
  out
}

///|
fn State::press_palette(self : State, key : String) -> Array[Command] {
  let out : Array[Command] = []
  if key == "enter" {
    let matches = self.palette_matches()
    if self.palette_pick < matches.length() {
      let pick = matches[self.palette_pick]
      self.mode = Browse
      if pick.has_prefix("table: ") {
        let name = pick.exact_view(start=7).to_owned()
        for table in self.tables {
          if table.name == name {
            out.push(Command::OpenTable(schema=table.schema, table=table.name))
          }
        }
      } else {
        match @keymap.Action::parse(pick) {
          Some(action) =>
            match action {
              @keymap.Action::Quit => out.push(Command::Quit)
              @keymap.Action::Reload => out.push(Command::Reload)
              _ => self.message = pick + ": press its key"
            }
          None => ()
        }
      }
    }
  } else if key == "up" {
    if self.palette_pick > 0 {
      self.palette_pick = self.palette_pick - 1
    }
  } else if key == "down" {
    self.palette_pick = self.palette_pick + 1
  } else if key == "backspace" {
    if self.palette_query.length() > 0 {
      self.palette_query = self.palette_query
        .exact_view(end=self.palette_query.length() - 1)
        .to_owned()
      self.palette_pick = 0
    }
  } else if key.length() == 1 {
    self.palette_query = self.palette_query + key
    self.palette_pick = 0
  }
  out
}
