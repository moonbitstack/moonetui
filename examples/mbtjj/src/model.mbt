// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// What the window holds: the rows `jj log` printed, the row the cursor is on,
// the revset being typed, and what the host has to ask the repository for. The
// model never starts a process itself; it leaves a request and the host runs it.

///|
/// What a revision is, in the words the details pane uses.
pub(all) enum State {
  Working
  Mutable
  Immutable
  Conflict
}

///|
/// One revision: the graph cells jj printed before it, the node, and the fields
/// the template asked for.
pub(all) struct Change {
  /// The lanes to the left of the node.
  lanes : String
  /// The node glyph: `@`, `○`, `◆` or `×`.
  node : String
  /// The cells between the node and the first field.
  after : String
  change_id : String
  commit_id : String
  author : String
  date : String
  bookmarks : Array[String]
  parents : Array[String]
  empty : Bool
  description : String
}

///|
/// A line of the log: a revision, or the lane a merge is drawn with.
pub(all) enum Row {
  Lane(graph~ : String)
  Revision(Change)
}

///|
/// What the right-hand pane shows.
pub(all) enum View {
  Details
  Diff
  Ops
  Help
}

///|
/// What the host has to ask jj for. The model sets one of these and the frame
/// loop runs it before the next frame.
pub(all) enum Request {
  Log(revset~ : String)
  Diff(change~ : String)
  Ops
}

///|
/// The state of one window over one repository.
pub struct Repo {
  /// The directory jj is run in.
  root : String
  mut rows : Array[Row]
  /// The rows of `rows` that carry a revision, in order.
  mut picks : Array[Int32]
  mut cursor : Int32
  /// The first row drawn, which moves when the cursor leaves the window.
  mut offset : Int32
  revset : StringBuilder
  mut typing : Bool
  mut view : View
  /// The lines of the diff or of the operations log, as jj printed them.
  mut aside : Array[String]
  mut status : String
  mut request : Request?
  mut lines : Int32
  /// The width of the graph column, which jj pads to the widest lane it drew.
  mut graph_width : Int32
}

///|
pub fn Repo::new(root : String) -> Repo {
  {
    root,
    rows: [],
    picks: [],
    cursor: 0,
    offset: 0,
    revset: StringBuilder(),
    typing: false,
    view: Details,
    aside: [],
    status: "",
    request: None,
    lines: 1,
    graph_width: 1,
  }
}

///|
/// The repository the window is looking at.
pub fn Repo::root(self : Repo) -> String {
  self.root
}

///|
pub fn Repo::view(self : Repo) -> View {
  self.view
}

///|
pub fn Repo::status(self : Repo) -> String {
  self.status
}

///|
pub fn Repo::revset(self : Repo) -> String {
  self.revset.to_string()
}

///|
pub fn Repo::typing(self : Repo) -> Bool {
  self.typing
}

///|
pub fn Repo::rows(self : Repo) -> Array[Row] {
  self.rows
}

///|
pub fn Repo::aside(self : Repo) -> Array[String] {
  self.aside
}

///|
/// The revision under the cursor.
pub fn Repo::pick(self : Repo) -> Change? {
  if self.picks.length() == 0 {
    return None
  }
  let at = if self.cursor >= self.picks.length() {
    self.picks.length() - 1
  } else {
    self.cursor
  }
  match self.rows[self.picks[at]] {
    Revision(change) => Some(change)
    Lane(_) => None
  }
}

///|
/// Where the log starts drawing, which the frame loop keeps in step with the
/// cursor.
pub fn Repo::offset(self : Repo) -> Int32 {
  self.offset
}

///|
/// Take the next request, if the model left one.
pub fn Repo::take(self : Repo) -> Request? {
  let out = self.request
  self.request = None
  out
}

///|
/// A log arrived: keep the cursor on the revision it was on, when that revision
/// is still in the log.
pub fn Repo::set_log(self : Repo, rows : Array[Row]) -> Unit {
  let was = match self.pick() {
    Some(change) => change.change_id
    None => ""
  }
  self.rows = rows
  // Every row's description starts in the same column, so the graph is measured
  // once for the whole log.
  let mut wide = 1
  for row in rows {
    let cells = match row {
      Lane(graph~) => @strip.str_cells(graph)
      Revision(change) =>
        @strip.str_cells(change.lanes) +
        @strip.str_cells(change.node) +
        @strip.str_cells(change.after)
    }
    if cells > wide {
      wide = cells
    }
  }
  self.graph_width = wide
  let picks : Array[Int32] = []
  for i in 0..<rows.length() {
    match rows[i] {
      Revision(_) => picks.push(i)
      Lane(_) => ()
    }
  }
  self.picks = picks
  let mut at = 0
  if was != "" {
    for i in 0..<picks.length() {
      match rows[picks[i]] {
        Revision(change) => if change.change_id == was { at = i }
        Lane(_) => ()
      }
    }
  }
  self.cursor = at
  if self.cursor >= picks.length() {
    self.cursor = if picks.length() == 0 { 0 } else { picks.length() - 1 }
  }
  self.status = ""
  self.follow()
}

///|
/// A diff or the operations arrived.
pub fn Repo::set_aside(self : Repo, lines : Array[String]) -> Unit {
  self.aside = lines
}

///|
/// Something went wrong: say it once, on the status line.
pub fn Repo::fail(self : Repo, text : String) -> Unit {
  self.status = text
}

///|
/// The number of rows the window can hold, told by the renderer every frame.
pub fn Repo::resize(self : Repo, lines : Int32) -> Unit {
  self.lines = if lines < 1 { 1 } else { lines }
  self.follow()
}

///|
fn Repo::follow(self : Repo) -> Unit {
  if self.picks.length() == 0 {
    self.offset = 0
    return
  }
  let at = match self.cursor < self.picks.length() {
    true => self.picks[self.cursor]
    false => 0
  }
  if at < self.offset {
    self.offset = at
  }
  if at >= self.offset + self.lines {
    self.offset = at - self.lines + 1
  }
  let most = if self.rows.length() > self.lines {
    self.rows.length() - self.lines
  } else {
    0
  }
  if self.offset > most {
    self.offset = most
  }
  if self.offset < 0 {
    self.offset = 0
  }
}

///|
/// Move the cursor by `step` revisions, and bring the window with it.
pub fn Repo::shift(self : Repo, step : Int32) -> Unit {
  if self.picks.length() == 0 {
    return
  }
  let next = self.cursor + step
  if next >= 0 && next < self.picks.length() {
    self.cursor = next
    self.follow()
    self.look()
  }
}

///|
/// Jump to the first or the last revision.
pub fn Repo::jump(self : Repo, last : Bool) -> Unit {
  if self.picks.length() == 0 {
    return
  }
  self.cursor = if last { self.picks.length() - 1 } else { 0 }
  self.follow()
  self.look()
}

///|
/// The cursor moved onto another revision: a diff or the operations log is
/// about the one that was showing, so it is asked for again.
fn Repo::look(self : Repo) -> Unit {
  match self.view {
    Details => ()
    Diff =>
      match self.pick() {
        Some(change) => self.request = Some(Diff(change=change.change_id))
        None => ()
      }
    Ops => ()
    Help => ()
  }
}

///|
/// `/` starts a revset; the letters go into it until enter.
pub fn Repo::start_revset(self : Repo) -> Unit {
  self.typing = true
  self.revset.reset()
}

///|
pub fn Repo::stop_revset(self : Repo, apply : Bool) -> Unit {
  self.typing = false
  if apply {
    self.request = Some(Log(revset=self.revset.to_string()))
  } else {
    self.revset.reset()
  }
}

///|
pub fn Repo::push(self : Repo, text : String) -> Unit {
  self.revset.write_string(text)
}

///|
pub fn Repo::backspace(self : Repo) -> Unit {
  let text = self.revset.to_string()
  if text.length() == 0 {
    return
  }
  self.revset.reset()
  self.revset.write_string(text[0:text.length() - 1].to_owned())
}

///|
/// `d`: the change itself, or what it does.
pub fn Repo::toggle_diff(self : Repo) -> Unit {
  if self.view is Diff {
    self.view = Details
    return
  }
  self.view = Diff
  match self.pick() {
    Some(change) => self.request = Some(Diff(change=change.change_id))
    None => ()
  }
}

///|
/// `o`: what the repository has seen.
pub fn Repo::toggle_ops(self : Repo) -> Unit {
  if self.view is Ops {
    self.view = Details
    return
  }
  self.view = Ops
  self.request = Some(Ops)
}

///|
/// `?`: the keys, in place of the change.
pub fn Repo::toggle_help(self : Repo) -> Unit {
  self.view = if self.view is Help { Details } else { Help }
}

///|
/// `r`: read the log again.
pub fn Repo::reload(self : Repo) -> Unit {
  self.request = Some(Log(revset=self.revset.to_string()))
}

///|
/// The word the details pane calls a revision's state.
pub fn state_word(state : State) -> String {
  match state {
    Working => "working copy"
    Mutable => "mutable"
    Immutable => "immutable"
    Conflict => "conflict"
  }
}

///|
/// What a node glyph means.
pub fn state_of(node : String) -> State {
  match node {
    "@" => Working
    "◆" => Immutable
    "×" => Conflict
    _ => Mutable
  }
}
