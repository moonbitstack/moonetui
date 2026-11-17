// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A Jujutsu log in three parts: the revisions with their graph, the change the
// cursor is on, and the operations the repository has seen. The data is fixed,
// so the example needs no `jj` binary and a frame test sees the same log twice.
//
// A revision is a row of the graph and a row of facts. The graph is written the
// way `jj log` writes it — a lane per branch, a node per revision, `@` for the
// working copy, `◆` for an immutable one, `×` for a conflict — and a row whose
// change id is empty is a lane with no revision on it, which is how a merge is
// drawn.

///|
pub(all) enum State {
  Immutable
  Mutable
  Working
  Conflict
}

///|
pub(all) struct Change {
  /// The graph, four cells, with the node written in it at `node_at`.
  graph : String
  node_at : Int32
  state : State
  /// Empty when the row is a lane between two revisions.
  change_id : String
  commit_id : String
  author : String
  date : String
  parents : String
  bookmarks : Array[String]
  description : String
  stat : String
  diff : Array[String]
}

///|
fn change(
  graph : String,
  node_at : Int32,
  state : State,
  change_id : String,
  commit_id : String,
  author : String,
  date : String,
  parents : String,
  bookmarks : Array[String],
  description : String,
  stat : String,
  diff : Array[String],
) -> Change {
  {
    graph,
    node_at,
    state,
    change_id,
    commit_id,
    author,
    date,
    parents,
    bookmarks,
    description,
    stat,
    diff,
  }
}

///|
fn lane(graph : String) -> Change {
  change(graph, -1, Mutable, "", "", "", "", "", [], "", "", [])
}

///|
/// The repository the log shows: a trunk, a feature branch that merged back,
/// a conflict, and a working copy with an empty description.
pub fn log() -> Array[Change] {
  [
    change(
      "@   ",
      0,
      Working,
      "qpvuntsm",
      "9f2c1ab0",
      "leo",
      "2026-11-17 19:41",
      "rlvkpnrz",
      [],
      "(empty) every screen wears the band",
      "+18 −6   4 files",
      [
        "+  pub fn band(name, subject, note, width)", "+  pub fn keys(pairs, width)",
        "-  pub fn header(title, note)", "   ...",
      ],
    ),
    change(
      "○   ",
      0,
      Mutable,
      "rlvkpnrz",
      "44a9d1c2",
      "leo",
      "2026-11-17 19:12",
      "zslqopmn",
      ["main"],
      "feat: a frame redraws the rows that changed",
      "+212 −96   9 files",
      [
        "+  App::repaint(id)", "+  damage rows, compose those, diff those", "-  place the tree on every frame",
        "   ...",
      ],
    ),
    change(
      "○   ",
      0,
      Mutable,
      "zslqopmn",
      "77c1de30",
      "bo",
      "2026-11-17 19:05",
      "rlvkpnrz kkmpptxz",
      [],
      "merge: the diff pane meets the pane head",
      "+0 −0   0 files",
      ["   merge of 2 revisions", "   ..."],
    ),
    lane("├─╮ "),
    change(
      "│ ○ ",
      2,
      Mutable,
      "kkmpptxz",
      "2f81b3aa",
      "ada",
      "2026-11-17 18:47",
      "wqnwkozp",
      ["fix/pane-head"],
      "fix: a pane head keeps its count",
      "+4 −4   2 files",
      [
        "+    let room = width - cells(label)", "-    let room = width", "   ...",
      ],
    ),
    change(
      "│ ○ ",
      2,
      Conflict,
      "wqnwkozp",
      "5b0e77f1",
      "ada",
      "2026-11-17 18:02",
      "mmmvllll",
      ["feat/diff"],
      "feat: a conflict in the middle",
      "+31 −12   3 files",
      [
        "+  <<<<<<< conflict 1 of 1", "+  fn detail(self, line, width) {", "+  =======",
        "+  fn detail(self, row, size) {", "+  >>>>>>>",
      ],
    ),
    lane("├─╯ "),
    change(
      "◆   ",
      0,
      Immutable,
      "mmmvllll",
      "1b2c3d4e",
      "leo",
      "2026-11-17 17:58",
      "ttxvnzqr",
      ["main@"],
      "docs: the round's account, and the eight bars",
      "+140 −22   5 files",
      ["+  ## Conformance", "+  the frames, read back by pyte", "   ..."],
    ),
    change(
      "○   ",
      0,
      Mutable,
      "ttxvnzqr",
      "8a71f0c5",
      "kai",
      "2026-11-16 20:31",
      "nkmqrxpy",
      ["docs/guide"],
      "docs: a guide that runs the library twice",
      "+88 −11   2 files",
      ["+  ## Getting started", "+  let ui = App::new(tty, tree)", "   ..."],
    ),
    change(
      "○   ",
      0,
      Mutable,
      "nkmqrxpy",
      "3d9c4a67",
      "leo",
      "2026-11-16 19:04",
      "zzzzzzzz",
      [],
      "perf: a bar of blocks is a bar, not a grapheme problem",
      "+26 −40   3 files",
      ["+  if printable_ascii(text) { fast_path() }", "   ..."],
    ),
    change(
      "○   ",
      0,
      Immutable,
      "zzzzzzzz",
      "00000000",
      "",
      "",
      "",
      [],
      "root()",
      "",
      [],
    ),
  ]
}

///|
/// What the client holds: the log, the cursor, the revset being typed, and
/// which of the two right-hand views is showing.
pub struct Repo {
  changes : Array[Change]
  mut cursor : Int32
  filter : StringBuilder
  mut typing : Bool
  mut diff : Bool
  mut ops : Bool
}

///|
pub fn Repo::new() -> Repo {
  {
    changes: log(),
    cursor: 0,
    filter: StringBuilder(),
    typing: false,
    diff: false,
    ops: false,
  }
}

///|
pub fn Repo::filter(self : Repo) -> String {
  self.filter.to_string()
}

///|
pub fn Repo::typing(self : Repo) -> Bool {
  self.typing
}

///|
pub fn Repo::diff(self : Repo) -> Bool {
  self.diff
}

///|
pub fn Repo::ops(self : Repo) -> Bool {
  self.ops
}

///|
/// The rows the log draws: every row when nothing is being looked for, and
/// only the revisions that match when a revset is typed. A lane row has no
/// change of its own, so a filter drops it.
pub fn Repo::rows(self : Repo) -> Array[Int32] {
  let out : Array[Int32] = []
  let wanted = self.filter.to_string()
  for i in 0..<self.changes.length() {
    let change = self.changes[i]
    if wanted == "" {
      out.push(i)
    } else if change.change_id != "" && matches(change, wanted) {
      out.push(i)
    }
  }
  out
}

///|
fn matches(change : Change, wanted : String) -> Bool {
  if change.change_id.contains(wanted) || change.description.contains(wanted) {
    return true
  }
  for book in change.bookmarks {
    if book.contains(wanted) {
      return true
    }
  }
  false
}

///|
/// The revision rows the cursor can land on, as indices into `changes`.
pub fn Repo::pickable(self : Repo) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in self.rows() {
    if self.changes[i].change_id != "" {
      out.push(i)
    }
  }
  out
}

///|
/// The change under the cursor.
pub fn Repo::selection(self : Repo) -> Change? {
  let rows = self.pickable()
  if rows.length() == 0 {
    return None
  }
  let at = if self.cursor >= rows.length() {
    rows.length() - 1
  } else {
    self.cursor
  }
  Some(self.changes[rows[at]])
}

///|
pub fn Repo::shift(self : Repo, step : Int32) -> Unit {
  let rows = self.pickable()
  if rows.length() == 0 {
    return
  }
  let next = self.cursor + step
  if next >= 0 && next < rows.length() {
    self.cursor = next
  }
}

///|
pub fn Repo::set_filter(self : Repo, text : String) -> Unit {
  self.filter.reset()
  self.filter.write_string(text)
  if self.cursor >= self.pickable().length() {
    self.cursor = 0
  }
}

///|
fn Repo::push(self : Repo, text : String) -> Unit {
  self.filter.write_string(text)
  if self.cursor >= self.pickable().length() {
    self.cursor = 0
  }
}

///|
fn Repo::backspace(self : Repo) -> Unit {
  let text = self.filter.to_string()
  if text.length() == 0 {
    return
  }
  let keep = text[0:text.length() - 1].to_owned()
  self.set_filter(keep)
}

///|
pub fn Repo::toggle_diff(self : Repo) -> Unit {
  self.diff = !self.diff
}

///|
pub fn Repo::toggle_ops(self : Repo) -> Unit {
  self.ops = !self.ops
}

///|
/// The state a revision is drawn in, as the word the details pane calls it.
fn state_word(state : State) -> String {
  match state {
    Immutable => "immutable"
    Mutable => "mutable"
    Working => "working copy"
    Conflict => "conflict"
  }
}
