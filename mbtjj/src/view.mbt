// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The window: the log with its graph down the left, what the cursor is on down
// the right, and a line above the keys that says what is being typed or what
// went wrong.

///|
/// How much of the width the log takes.
const LOG_SHARE : Int32 = 58

///|
/// What a line of the log costs before the description starts, the graph
/// column aside: the marker, the space after the graph, the change id and the
/// space after that.
const LEDGER : Int32 = 15

///|
/// The keys the window answers to, in the order the help panel lists them.
pub let bindings : Array[(String, String)] = [
  ("↑ ↓", "revision"),
  ("pgup pgdn", "a screen"),
  ("g G", "first, last"),
  ("/", "revset"),
  ("d", "what it does"),
  ("o", "operations"),
  ("r", "read again"),
  ("?", "keys"),
  ("q", "quit"),
]

///|
fn node_style(state : State) -> @style.Style {
  match state {
    Working => @style.Style::new(fg=cool, bold=true)
    Immutable => @style.Style::new(fg=cool, bold=true)
    Conflict => @style.Style::new(fg=bad, bold=true)
    Mutable => @style.Style::new(fg=muted)
  }
}

///|
/// The bookmarks of a revision as one word.
fn marks_of(change : Change) -> String {
  let out = StringBuilder()
  for book in change.bookmarks {
    if out.to_string().length() > 0 {
      out.write_string(" ")
    }
    out.write_string(book)
  }
  out.to_string()
}

///|
fn left_cut(text : String, room : Int32) -> String {
  if room <= 0 {
    return ""
  }
  if @strip.str_cells(text) <= room {
    return text
  }
  let at = @strip.cut_at(text, room - 1)
  text[0:at].to_owned() + "…"
}

///|
/// A repository path as the band can hold it: the end of it, which is the part
/// that names the repository, and an ellipsis for the rest.
fn short_path(path : String) -> String {
  if @strip.str_cells(path) <= 40 {
    return path
  }
  let chars = path.to_array()
  let mut start = chars.length()
  let mut used = 0
  while start > 0 && used < 37 {
    start = start - 1
    used = used + 1
  }
  // Do not begin in the middle of a path separator.
  while start < chars.length() && chars[start] != '/' && chars[start] != '\\' {
    start = start + 1
  }
  "…" + path[start:chars.length()].to_owned()
}

///|
/// A word broken into rows that fit `width`, on spaces where it can.
fn wrap(text : String, width : Int32) -> Array[String] {
  let out : Array[String] = []
  if width <= 0 {
    return out
  }
  let line = StringBuilder()
  for word in text.split(" ") {
    let word = word.to_owned()
    if word == "" {
      continue
    }
    if line.to_string().length() == 0 {
      line.write_string(word)
    } else if @strip.str_cells(line.to_string()) + 1 + @strip.str_cells(word) <=
      width {
      line.write_string(" ")
      line.write_string(word)
    } else {
      out.push(line.to_string())
      line.reset()
      line.write_string(word)
    }
  }
  if line.to_string().length() > 0 {
    out.push(line.to_string())
  }
  out
}

///|
/// One row of the log.
fn Repo::line(
  self : Repo,
  index : Int32,
  width : Int32,
  picked : Bool,
) -> @strip.Strip {
  let ground = if picked { cursor } else { @style.Style::new() }
  match self.rows[index] {
    Lane(graph~) =>
      @strip.Strip::join([
        @strip.Strip::of(" ", @style.Style::new()),
        @strip.Strip::of(graph, faint_style).pad_to(
          self.graph_width,
          @style.Style::new(),
        ),
      ])
      .crop(0, width)
      .pad_to(width, @style.Style::new())
    Revision(change) => {
      let bar = if picked {
        @strip.Strip::of("▌", marker)
      } else {
        @strip.Strip::of(" ", @style.Style::new())
      }
      let state = state_of(change.node)
      let graph = @strip.Strip::join([
        @strip.Strip::of(change.lanes, faint_style),
        @strip.Strip::of(
          change.node,
          if picked {
            ground
          } else {
            node_style(state)
          },
        ),
        @strip.Strip::of(change.after, faint_style),
      ]).pad_to(self.graph_width, @style.Style::new())
      let id = @strip.Strip::of(
        fit(change.change_id, 13),
        if picked {
          ground
        } else {
          identifier
        },
      )
      let tags = marks_of(change)
      // Two cells of air before the divider: a bookmark that touches it reads
      // as if it belonged to the pane beside it.
      let room = width -
        (LEDGER + self.graph_width) -
        (if tags == "" { 0 } else { @strip.str_cells(tags) + 4 })
      let text = if change.description == "" {
        if change.empty {
          "(empty)"
        } else {
          "(no description)"
        }
      } else {
        change.description
      }
      let body = @strip.Strip::join([
        @strip.Strip::of(
          left_cut(text, room),
          if picked {
            ground
          } else {
            body
          },
        ),
        if tags == "" {
          @strip.Strip::empty()
        } else {
          @strip.Strip::of(
            "  " + tags,
            if picked {
              ground
            } else {
              @style.Style::new(fg=accent_alt)
            },
          )
        },
      ])
      @strip.Strip::join([bar, graph, @strip.Strip::of(" ", ground), id, body])
      .crop(0, width)
      .pad_to(width, ground)
    }
  }
}

///|
/// A field of the details pane: the name in a column, the value beside it.
fn field(name : String, value : String, style : @style.Style) -> @strip.Strip {
  @strip.Strip::join([
    @strip.Strip::of(fit(" " + name, 11), quiet),
    @strip.Strip::of(value, style),
  ])
}

///|
/// What the details pane shows at line `at`, or the empty strip.
fn Repo::aside_line(self : Repo, at : Int32, width : Int32) -> @strip.Strip {
  match self.view {
    Ops =>
      match self.aside_line_of(at, width) {
        Some(strip) => strip
        None => @strip.Strip::blank(width, @style.Style::new())
      }
    Diff =>
      match self.aside_line_of(at, width) {
        Some(strip) => strip
        None => @strip.Strip::blank(width, @style.Style::new())
      }
    Help => help_line(at, width)
    Details => self.details_line(at, width)
  }
}

///|
/// A line of the diff or of the operations log, coloured by what it is.
fn Repo::aside_line_of(self : Repo, at : Int32, width : Int32) -> @strip.Strip? {
  if at < 0 || at >= self.aside.length() {
    return None
  }
  let line = self.aside[at]
  let style = if self.view is Ops {
    if line.has_prefix("@") {
      @style.Style::new(fg=accent, bold=true)
    } else if line.has_prefix("│") ||
      line.has_prefix("○") ||
      line.has_prefix("◆") {
      @style.Style::new(fg=accent_alt)
    } else {
      quiet
    }
  } else if line.has_prefix("Added") {
    @style.Style::new(fg=good)
  } else if line.has_prefix("Removed") {
    @style.Style::new(fg=bad)
  } else if line.has_prefix("Modified") {
    @style.Style::new(fg=warn)
  } else if line.has_prefix("+") {
    @style.Style::new(fg=good)
  } else if line.has_prefix("-") {
    @style.Style::new(fg=bad)
  } else {
    quiet
  }
  Some(@strip.Strip::of(" " + left_cut(line, width - 1), style))
}

///|
/// The change under the cursor.
fn Repo::details_line(self : Repo, at : Int32, width : Int32) -> @strip.Strip {
  let change = match self.pick() {
    None =>
      return @strip.Strip::of(
        if self.rows.length() == 0 {
          " the revset matches nothing"
        } else {
          " no revision under the cursor"
        },
        quiet,
      )
    Some(change) => change
  }
  let body : @strip.Strip = if at == 0 {
    @strip.Strip::join([
      @strip.Strip::of(
        " " + state_word(state_of(change.node)),
        node_style(state_of(change.node)),
      ),
      @strip.Strip::of("  ·  " + change.commit_id, quiet),
    ])
  } else if at == 2 {
    field("change", change.change_id, body)
  } else if at == 3 {
    field("author", change.author, body)
  } else if at == 4 {
    field("date", change.date, body)
  } else if at == 5 {
    field(
      "parents",
      if change.parents.length() == 0 {
        "—"
      } else {
        change.parents.join(" ")
      },
      body,
    )
  } else if at == 6 {
    let tags = marks_of(change)
    field(
      "bookmarks",
      if tags == "" {
        "—"
      } else {
        tags
      },
      if tags == "" {
        quiet
      } else {
        @style.Style::new(fg=accent_alt)
      },
    )
  } else if at >= 8 {
    let room = width - 1
    let lines = wrap(change.description, room)
    let index = at - 8
    if index < lines.length() {
      @strip.Strip::of(" " + lines[index], title)
    } else if index == lines.length() && change.empty {
      @strip.Strip::of(" (empty change)", quiet)
    } else if index == lines.length() + 1 {
      @strip.Strip::of(" d  what it does   ·   r  read again", faint_style)
    } else {
      @strip.Strip::blank(width, @style.Style::new())
    }
  } else {
    @strip.Strip::blank(width, @style.Style::new())
  }
  body.crop(0, width).pad_to(width, @style.Style::new())
}

///|
/// The keys, one pair a line, for the help panel.
fn help_line(at : Int32, width : Int32) -> @strip.Strip {
  if at >= bindings.length() {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let (key, meaning) = bindings[at]
  @strip.Strip::join([
    @strip.Strip::of(fit(" " + key, 12), identifier),
    @strip.Strip::of(meaning, body),
  ])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
}

///|
/// What the pane head says, which depends on what the pane is showing.
fn Repo::aside_name(self : Repo) -> String {
  match self.view {
    Details => "change"
    Diff => "diff"
    Ops => "operations"
    Help => "keys"
  }
}

///|
impl @widget.Widget for Repo with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 50 || height < 8 {
    return @strip.Strip::blank(width, @style.default)
  }
  let left = width * LOG_SHARE / 100
  let right = width - left - 2
  // The body is what is left between the rule under the band and the line
  // above the keys.
  let body_rows = height - 4
  self.resize(body_rows - 1)
  let note = if self.typing {
    "revset " + self.revset.to_string() + "▏"
  } else if self.status != "" {
    self.status
  } else if self.revset.to_string() != "" {
    "revset " + self.revset.to_string()
  } else {
    self.picks.length().to_string() + " revisions"
  }
  if row == 0 {
    return band("mbtjj", subject=short_path(self.root), note~, width~)
  }
  if row == 1 {
    return rule(width~)
  }
  if row == height - 1 {
    return keys(
      [
        ("↑↓", "move"),
        ("/", "revset"),
        ("d", "diff"),
        ("?", "keys"),
        ("q", "quit"),
      ],
      width~,
    )
  }
  if row == height - 2 {
    let said : @strip.Strip = if self.status != "" {
      @strip.Strip::of(" " + self.status, @style.Style::new(fg=bad))
    } else if self.revset.to_string() != "" {
      @strip.Strip::join([
        @strip.Strip::of(" revset ", quiet),
        @strip.Strip::of(self.revset.to_string(), identifier),
      ])
    } else if self.view is Help {
      @strip.Strip::of(" press ? again for the change", quiet)
    } else if self.view is Ops {
      @strip.Strip::of(" operations, newest first", quiet)
    } else if self.view is Diff {
      @strip.Strip::of(" what this change does", quiet)
    } else {
      @strip.Strip::of(" jj log", quiet)
    }
    return said.crop(0, width).pad_to(width, @style.Style::new())
  }
  let at = row - 2
  if at == 0 {
    let under = match self.pick() {
      Some(change) => change.change_id
      None => ""
    }
    return @strip.Strip::join([
      head(
        "log",
        count=self.picks.length().to_string(),
        width=left,
        active=true,
      ),
      gap(),
      head(self.aside_name(), count=under, width=right, active=false),
    ]).crop(0, width)
  }
  let index = self.offset + at - 1
  let under = match self.pick() {
    Some(change) =>
      if index < self.rows.length() {
        match self.rows[index] {
          Revision(other) => other.change_id == change.change_id
          Lane(_) => false
        }
      } else {
        false
      }
    None => false
  }
  let log = if index < self.rows.length() {
    self.line(index, left, under)
  } else {
    @strip.Strip::blank(left, @style.Style::new())
  }
  return @strip.Strip::join([log, gap(), self.aside_line(at - 1, right)])
    .crop(0, width)
    .pad_to(width, @style.Style::new())
}

///|
impl @widget.Widget for Repo with fn hint(_self, _size) {
  @geom.Size::new(100, 26)
}

///|
impl @widget.Widget for Repo with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Repo with fn handle(self, ctx, msg) {
  match msg {
    @widget.Msg::Key(key) =>
      if self.typing {
        match key.code {
          Enter => {
            self.stop_revset(true)
            ctx.repaint()
            true
          }
          Escape => {
            self.stop_revset(false)
            ctx.repaint()
            true
          }
          Backspace => {
            self.backspace()
            ctx.repaint()
            true
          }
          Char(code) =>
            if code >= 32 && code < 127 {
              self.push(code.unsafe_to_char().to_string())
              ctx.repaint()
              true
            } else {
              false
            }
          _ => false
        }
      } else {
        match key.code {
          Up => {
            self.shift(-1)
            ctx.repaint()
            true
          }
          Down => {
            self.shift(1)
            ctx.repaint()
            true
          }
          PageUp => {
            self.shift(-self.lines)
            ctx.repaint()
            true
          }
          PageDown => {
            self.shift(self.lines)
            ctx.repaint()
            true
          }
          Home => {
            self.jump(false)
            ctx.repaint()
            true
          }
          End => {
            self.jump(true)
            ctx.repaint()
            true
          }
          Char(47) => {
            self.start_revset()
            ctx.repaint()
            true
          }
          Char(100) => {
            self.toggle_diff()
            ctx.repaint()
            true
          }
          Char(111) => {
            self.toggle_ops()
            ctx.repaint()
            true
          }
          Char(114) => {
            self.reload()
            ctx.repaint()
            true
          }
          Char(63) => {
            self.toggle_help()
            ctx.repaint()
            true
          }
          Char(103) => {
            self.jump(false)
            ctx.repaint()
            true
          }
          Char(71) => {
            self.jump(true)
            ctx.repaint()
            true
          }
          _ => false
        }
      }
    _ => false
  }
}

///|
/// The window: the repository, and the tree the host draws. The tree is built
/// here so that the type and its widget implementation stay in one package, and
/// the repo lives in the window so the host and the leaf are looking at the
/// same one.
pub struct Screen {
  repo : Repo
}

///|
pub fn Screen::new(root : String) -> Screen {
  { repo: Repo::new(root), }
}

///|
/// The window's own state, reached through it: a `Repo` handed out by value
/// would be a copy, and a copy is not what the leaf draws.
pub fn Screen::set_log(self : Screen, rows : Array[Row]) -> Unit {
  self.repo.set_log(rows)
}

///|
pub fn Screen::set_aside(self : Screen, lines : Array[String]) -> Unit {
  self.repo.set_aside(lines)
}

///|
pub fn Screen::take(self : Screen) -> Request? {
  self.repo.take()
}

///|
pub async fn Screen::serve(self : Screen, req : Request) -> Unit {
  self.repo.serve(req)
}

///|
pub async fn Screen::open(self : Screen, revset~ : String = "") -> Unit {
  self.repo.open(revset~)
}

///|
pub fn Screen::view(self : Screen) -> View {
  self.repo.view()
}

///|
pub fn Screen::status(self : Screen) -> String {
  self.repo.status()
}

///|
pub fn Screen::rows(self : Screen) -> Array[Row] {
  self.repo.rows()
}

///|
pub fn Screen::pick(self : Screen) -> Change? {
  self.repo.pick()
}

///|
pub fn Screen::node(self : Screen) -> @app.Node {
  @app.column(0, [@app.leaf(1, self.repo, box=@layout.Box::new(extent=Frac(1)))])
}
