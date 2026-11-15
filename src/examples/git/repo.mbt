// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A repository in three panes: branches, commits, and the files the working
// tree has changed. The data is fixed, so the example needs no git binary and a
// frame test sees the same three panes twice.

///|
pub struct Repo {
  branches : Array[String]
  commits : Array[String]
  files : Array[String]
  /// -1 for a deletion, 0 for a change, 1 for a new file.
  marks : Array[Int32]
  cursor : Array[Int32]
  mut focus : Int32
  staged : Array[Bool]
}

///|
pub fn Repo::new() -> Repo {
  let staged : Array[Bool] = []
  for _ in 0..<6 {
    staged.push(false)
  }
  {
    branches: ["main *", "feat/ui", "fix/perf", "chore/deps"],
    commits: [
      "a3f9c21  draw the tree, not the list", "7b1e044  a sheet every example wears",
      "c92d38a  ascii stops asking the tables", "1f04b7e  sparks where the snake eats",
      "8d5c2a0  four regions, one page", "3e77b19  miller columns",
    ],
    files: [
      "src/app/app.mbt", "src/strip/width.mbt", "src/examples/snake/board.mbt", "src/examples/tree/tree.mbt",
      "README.md", "CHANGELOG.md",
    ],
    marks: [0, 0, 0, 1, 0, -1],
    cursor: [0, 0, 0],
    focus: 1,
    staged,
  }
}

///|
pub fn Repo::focus(self : Repo) -> Int32 {
  self.focus
}

///|
/// What the focused pane has under its cursor, which is what a test reads.
pub fn Repo::selection(self : Repo) -> String {
  let index = self.cursor[self.focus]
  if self.focus == 0 {
    self.branches[index]
  } else if self.focus == 1 {
    self.commits[index]
  } else {
    self.files[index]
  }
}

///|
pub fn Repo::staged(self : Repo, index : Int32) -> Bool {
  self.staged[index]
}

///|
fn Repo::length(self : Repo, pane : Int32) -> Int32 {
  if pane == 0 {
    self.branches.length()
  } else if pane == 1 {
    self.commits.length()
  } else {
    self.files.length()
  }
}

///|
pub fn Repo::shift(self : Repo, step : Int32) -> Unit {
  let pane = self.focus
  let next = self.cursor[pane] + step
  if next >= 0 && next < self.length(pane) {
    self.cursor[pane] = next
  }
}

///|
pub fn Repo::next_pane(self : Repo) -> Unit {
  self.focus = (self.focus + 1) % 3
}

///|
/// Stage or unstage the file under the cursor. Only the file pane has anything
/// to stage; the other two say so by doing nothing.
pub fn Repo::toggle(self : Repo) -> Unit {
  if self.focus != 2 {
    return
  }
  let index = self.cursor[2]
  self.staged[index] = !self.staged[index]
}

///|
let title_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let live_style : @style.Style = @style.Style::new(fg=@theme.accent_alt)

///|
let value_style : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let add_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let del_style : @style.Style = @style.Style::new(fg=@theme.bad)

///|
let picked_style : @style.Style = @style.Style::new(
  fg=@style.black,
  bg=@theme.accent,
  bold=true,
)

///|
fn repeat(glyph : String, count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(glyph)
  }
  out.to_string()
}

///|
fn fit(text : String, width : Int32) -> String {
  let cells = @strip.str_cells(text)
  if cells >= width {
    return text
  }
  text + repeat(" ", width - cells)
}

///|
/// One row of one pane: the entry, dimmed when the pane is not focused, filled
/// when it is the row the cursor is on.
fn Repo::row(
  self : Repo,
  pane : Int32,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let focused = self.focus == pane
  let picked = focused && self.cursor[pane] == index
  if pane == 2 {
    let mark = match self.marks[index] {
      -1 => "-"
      1 => "+"
      _ => "~"
    }
    let mark_style = if self.marks[index] == 1 {
      add_style
    } else if self.marks[index] == -1 {
      del_style
    } else {
      dim_style
    }
    let staged = if self.staged[index] { "●" } else { "○" }
    let inner = if width > 4 { width - 4 } else { width }
    return @strip.Strip::join([
      @strip.Strip::of(
        " " + staged + " ",
        if self.staged[index] {
          add_style
        } else {
          dim_style
        },
      ),
      @strip.Strip::of(mark + " ", mark_style),
      @strip.Strip::of(
        fit(self.files[index], inner),
        if picked {
          picked_style
        } else {
          value_style
        },
      ),
    ])
  }
  let text = if pane == 0 { self.branches[index] } else { self.commits[index] }
  let style = if pane == 0 { live_style } else { value_style }
  @strip.Strip::of(
    fit(" " + text, width),
    if picked {
      picked_style
    } else if focused {
      style
    } else {
      dim_style
    },
  )
}

///|
impl @widget.Widget for Repo with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 50 {
    return @strip.Strip::blank(width, @style.default)
  }
  if row == 0 {
    return @strip.Strip::join([
      @strip.Strip::of(" git", head_style),
      @strip.Strip::of("  moonetui · main · 3 ahead", title_style),
    ])
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " tab pane · ↑↓ move · space stage · esc quit", title_style,
    )
  }
  let left = width * 22 / 100
  let middle = width * 38 / 100
  let right = width - left - middle - 4
  let body = row - 1
  // The pane headers sit on the first row of the body.
  if body == 0 {
    return @strip.Strip::join([
      @strip.Strip::of(
        fit(" branches", left),
        if self.focus == 0 {
          live_style
        } else {
          title_style
        },
      ),
      @strip.Strip::blank(2, @style.Style::new()),
      @strip.Strip::of(
        fit(" commits", middle),
        if self.focus == 1 {
          live_style
        } else {
          title_style
        },
      ),
      @strip.Strip::blank(2, @style.Style::new()),
      @strip.Strip::of(
        fit(" files", right),
        if self.focus == 2 {
          live_style
        } else {
          title_style
        },
      ),
    ])
  }
  let index = body - 1
  let cell = fn(pane : Int32, pane_width : Int32) {
    if index < self.length(pane) {
      self.row(pane, index, pane_width)
    } else {
      @strip.Strip::blank(pane_width, @style.Style::new())
    }
  }
  @strip.Strip::join([
    cell(0, left),
    @strip.Strip::blank(2, @style.Style::new()),
    cell(1, middle),
    @strip.Strip::blank(2, @style.Style::new()),
    cell(2, right),
  ])
}

///|
impl @widget.Widget for Repo with fn hint(_self, size) {
  @geom.Size::new(size.width, 12)
}

///|
impl @widget.Widget for Repo with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Repo with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Tab => {
          self.next_pane()
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
        Char(32) => {
          self.toggle()
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
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
