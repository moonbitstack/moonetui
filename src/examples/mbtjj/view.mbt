// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The screen: the log down the left with its graph, the change the cursor is on
// down the right, the operations the repository has seen under both, and the
// keys along the foot.

///|
/// The width the log takes; the rest belongs to the change under the cursor.
const LOG_SHARE : Int32 = 56

///|
/// The rows the operations panel takes when it is open, its head included.
const OPS_ROWS : Int32 = 4

///|
/// How much of a row the graph, the change id and the spaces between take.
const LEDGER : Int32 = 15

///|
fn state_style(state : State) -> @style.Style {
  match state {
    Working => @theme.mark
    Immutable => @style.Style::new(fg=@theme.cool, bold=true)
    Conflict => @style.Style::new(fg=@theme.bad, bold=true)
    Mutable => @style.Style::new(fg=@theme.muted)
  }
}

///|
/// The graph of one row: the lanes in the quiet colour, the node in the colour
/// its state deserves, the whole four cells wide so every row's change id
/// starts in the same column.
fn graph_of(change : Change) -> @strip.Strip {
  if change.node_at < 0 {
    return @strip.Strip::of(change.graph, @style.Style::new(fg=@theme.muted))
  }
  let cells = change.node_at
  let head = @strip.Strip::of(
    if cells > 0 {
      change.graph[0:cells].to_owned()
    } else {
      ""
    },
    @style.Style::new(fg=@theme.muted),
  )
  let node = @strip.Strip::of(
    change.graph[cells:cells + 1].to_owned(),
    state_style(change.state),
  )
  let tail = @strip.Strip::of(
    change.graph[cells + 1:4].to_owned(),
    @style.Style::new(fg=@theme.muted),
  )
  @strip.Strip::join([head, node, tail])
}

///|
/// The bookmarks of a revision, as one word: a local one in the second accent,
/// a tracked one as `main@`.
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
  let cells = @strip.str_cells(text)
  if cells <= room {
    return text
  }
  let at = @strip.cut_at(text, room - 1)
  text[0:at].to_owned() + "…"
}

///|
/// One row of the log.
fn Repo::line(
  self : Repo,
  index : Int32,
  width : Int32,
  picked : Bool,
) -> @strip.Strip {
  let change = self.changes[index]
  let bar = if picked {
    @strip.Strip::of("▌", @theme.marker)
  } else {
    @strip.Strip::of(" ", @style.Style::new())
  }
  let ground = if picked { @theme.cursor } else { @style.Style::new() }
  let graph = graph_of(change)
  if change.change_id == "" {
    return @strip.Strip::join([
      bar,
      graph,
      @strip.Strip::blank(width - 5, ground),
    ]).crop(0, width)
  }
  let id = @strip.Strip::of(
    @theme.fit(change.change_id, 8),
    if picked {
      @theme.cursor
    } else {
      @theme.identifier
    },
  )
  let tags = marks_of(change)
  let tag_room = @strip.str_cells(tags)
  let room = width - LEDGER - (if tag_room > 0 { tag_room + 2 } else { 0 })
  let text = left_cut(change.description, room)
  let body = @strip.Strip::join([
    @strip.Strip::of(
      @theme.fit(text, room),
      if picked {
        @theme.cursor
      } else {
        @theme.body
      },
    ),
    if tag_room > 0 {
      @strip.Strip::of(
        "  " + tags,
        if picked {
          @theme.cursor
        } else {
          @style.Style::new(fg=@theme.accent_alt)
        },
      )
    } else {
      @strip.Strip::empty()
    },
  ])
  @strip.Strip::join([
    bar,
    graph,
    @strip.Strip::of(" ", ground),
    id,
    @strip.Strip::of(" ", ground),
    body,
  ])
  .crop(0, width)
  .pad_to(width, ground)
}

///|
/// A label and its value, the label in a fixed column of the details pane.
fn field(name : String, value : String) -> @strip.Strip {
  @strip.Strip::join([
    @strip.Strip::of(@theme.fit(" " + name, 11), @theme.quiet),
    @strip.Strip::of(value, @theme.body),
  ])
}

///|
/// The change under the cursor, one line at a time: what it is, who wrote it,
/// where it came from, what it says, and — in the diff view — what it does.
fn Repo::detail(self : Repo, line : Int32, width : Int32) -> @strip.Strip {
  let change = match self.selection() {
    None =>
      return @strip.Strip::of(" nothing matches the revset", @theme.quiet).pad_to(
        width,
        @style.Style::new(),
      )
    Some(change) => change
  }
  let text = if self.diff {
    if line == 0 {
      @strip.Strip::join([@strip.Strip::of(" " + change.stat, @theme.quiet)])
    } else if line >= 2 && line - 2 < change.diff.length() {
      diff_line(change.diff[line - 2])
    } else {
      @strip.Strip::empty()
    }
  } else if line == 0 {
    @strip.Strip::join([
      @strip.Strip::of(
        " " + state_word(change.state),
        state_style(change.state),
      ),
      @strip.Strip::of("  ·  " + change.commit_id, @theme.quiet),
    ])
  } else if line == 1 {
    @strip.Strip::empty()
  } else if line == 2 {
    field("change", change.change_id)
  } else if line == 3 {
    field("author", change.author + " <" + change.author + "@example.com>")
  } else if line == 4 {
    field("date", change.date)
  } else if line == 5 {
    field("parents", change.parents)
  } else if line == 6 {
    let tags = marks_of(change)
    field("bookmarks", if tags == "" { "—" } else { tags })
  } else if line == 8 {
    @strip.Strip::of(
      " " + left_cut(change.description, width - 2),
      @theme.title,
    )
  } else if line == 9 {
    @theme.rule(width~)
  } else if line == 10 {
    @strip.Strip::of(" " + change.stat, @theme.quiet)
  } else {
    @strip.Strip::empty()
  }
  text.crop(0, width).pad_to(width, @style.Style::new())
}

///|
fn diff_line(text : String) -> @strip.Strip {
  let first = if text.length() > 0 { text[0] } else { ' ' }
  let style = if first == '+' {
    @style.Style::new(fg=@theme.good)
  } else if first == '-' {
    @style.Style::new(fg=@theme.bad)
  } else {
    @theme.quiet
  }
  @strip.Strip::of(" " + text, style)
}

///|
/// The operations the repository has seen, newest first: the log a reader keeps
/// when a change does something they did not expect.
fn Repo::operation(_self : Repo, line : Int32, width : Int32) -> @strip.Strip {
  let ops : Array[(String, String, String)] = [
    ("19:41", "describe", "every screen wears the band"),
    ("19:12", "new", "feat: a frame redraws the rows that changed"),
    ("18:47", "commit", "fix: a pane head keeps its count"),
  ]
  if line == 0 {
    return @theme.head("operations", count="3", width~)
  }
  let at = line - 1
  if at >= ops.length() {
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let (time, verb, what) = ops[at]
  @strip.Strip::join([
    @strip.Strip::of(" " + time + "  ", @theme.faint_style),
    @strip.Strip::of(@theme.fit(verb, 9), @theme.live),
    @strip.Strip::of(left_cut(what, width - 18), @theme.body),
  ])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
}

///|
/// The column between the log and the change.
fn gap() -> @strip.Strip {
  @strip.Strip::join([
    @strip.Strip::of("│", @theme.edge),
    @strip.Strip::blank(1, @style.Style::new()),
  ])
}

///|
impl @widget.Widget for Repo with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 60 || height < 10 {
    return @strip.Strip::blank(width, @style.default)
  }
  let note = if self.typing {
    "revset " + self.filter.to_string() + "▏"
  } else if self.filter.to_string() != "" {
    "revset " + self.filter.to_string()
  } else {
    "moonetui · " + self.changes.length().to_string() + " revisions"
  }
  if row == 0 {
    return @theme.band("moonetui", subject="mbtjj", note~, width~)
  }
  if row == 1 {
    return @theme.rule(width~)
  }
  if row == height - 1 {
    return @theme.keys(
      [
        ("↑↓", "revision"),
        ("/", "revset"),
        ("d", if self.diff { "details" } else { "diff" }),
        ("o", "operations"),
        ("q", "quit"),
      ],
      width~,
    )
  }
  let left = width * LOG_SHARE / 100
  let right = width - left - 2
  let floor = if self.ops { height - 1 - OPS_ROWS } else { height - 1 }
  if self.ops && row >= floor {
    return self.operation(row - floor, width)
  }
  let body = row - 2
  if body == 0 {
    let rows = self.pickable()
    return @strip.Strip::join([
      @theme.head(
        "log",
        count=rows.length().to_string(),
        width=left,
        active=true,
      ),
      gap(),
      @theme.head(
        if self.diff {
          "diff"
        } else {
          "change"
        },
        count=match self.selection() {
          Some(change) => change.change_id
          None => "—"
        },
        width=right,
        active=false,
      ),
    ]).crop(0, width)
  }
  let index = body - 1
  let rows = self.rows()
  let log = if index < rows.length() {
    let here = self.cursor_at(rows[index])
    self.line(rows[index], left, here)
  } else {
    @strip.Strip::blank(left, @style.Style::new())
  }
  @strip.Strip::join([log, gap(), self.detail(index, right)])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
}

///|
/// The revisions a reader can land on: the cursor counts these, not the lanes.
fn Repo::cursor_at(self : Repo, index : Int32) -> Bool {
  let rows = self.pickable()
  if self.cursor >= rows.length() {
    return false
  }
  rows[self.cursor] == index
}

///|
impl @widget.Widget for Repo with fn hint(_self, size) {
  @geom.Size::new(size.width, 18)
}

///|
impl @widget.Widget for Repo with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Repo with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      if self.typing {
        match key.code {
          Enter | Escape => {
            self.typing = false
            if key.code is Escape {
              self.set_filter("")
            }
            ctx.repaint()
            true
          }
          Backspace => {
            self.backspace()
            ctx.repaint()
            true
          }
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
          Char(47) => {
            self.typing = true
            self.set_filter("")
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
          Char(113) => {
            ctx.emit(Quit)
            true
          }
          _ => false
        }
      }
    _ => false
  }
}

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
/// The screen the example runs: the log, and the keys it answers to.
pub struct Screen {
  root : @app.Node
  repo : Repo
}

///|
pub fn Screen::new() -> Screen {
  let repo = Repo::new()
  let root = @app.column(0, [
    @app.leaf(1, repo, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, repo, }
}
