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
  /// The branch that has the working copy on it, marked with a dot.
  current : Int32
}

///|
pub fn Repo::new() -> Repo {
  let staged : Array[Bool] = []
  for _ in 0..<8 {
    staged.push(false)
  }
  {
    branches: [
      "main", "feat/ui", "fix/perf", "chore/deps", "release/0.5", "docs/guide",
    ],
    commits: [
      "a3f9c21  draw the tree, not the list", "7b1e044  a sheet every example wears",
      "c92d38a  ascii stops asking the tables", "1f04b7e  sparks where the snake eats",
      "8d5c2a0  four regions, one page", "3e77b19  miller columns", "5d2ab90  a frame redraws what moved",
      "0c7e4f2  the band every screen wears", "b41c8d3  a log with its own graph",
      "e9a1705  eight bars, one board",
    ],
    files: [
      "src/app/app.mbt", "src/strip/width.mbt", "src/examples/snake/board.mbt", "src/examples/json/doc.mbt",
      "README.md", "CHANGELOG.md", "src/comp/diff.mbt", "docs/index.html",
    ],
    marks: [0, 0, 0, 1, 0, -1, 0, 0],
    cursor: [0, 0, 0],
    focus: 1,
    staged,
    current: 0,
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
let add_style : @style.Style = @style.Style::new(fg=@theme.good)

///|
let del_style : @style.Style = @style.Style::new(fg=@theme.bad)

///|
let touched_style : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let value_style : @style.Style = @style.Style::new(fg=@theme.ink)

///|
/// The column between two panes: a hairline with a space after it.
fn gap() -> @strip.Strip {
  @strip.Strip::join([
    @strip.Strip::of("│", @theme.edge),
    @strip.Strip::blank(1, @style.Style::new()),
  ])
}

///|
/// One row of one pane: the entry, dimmed when the pane has no keyboard, and
/// marked down its left edge when it is the row the cursor is on.
fn Repo::row(
  self : Repo,
  pane : Int32,
  index : Int32,
  width : Int32,
) -> @strip.Strip {
  let focused = self.focus == pane
  let picked = focused && self.cursor[pane] == index
  let ground = if picked { @theme.cursor } else { value_style }
  let bar = if picked {
    @strip.Strip::of("▌", @theme.marker)
  } else {
    @strip.Strip::of(" ", @style.Style::new())
  }
  if pane == 2 {
    let mark = match self.marks[index] {
      -1 => "D"
      1 => "A"
      _ => "M"
    }
    let mark_style = match self.marks[index] {
      1 => add_style
      -1 => del_style
      _ => touched_style
    }
    let staged = if self.staged[index] { "●" } else { "○" }
    let inner = width - 5
    let body = @strip.Strip::join([
      @strip.Strip::of(
        staged + " ",
        if self.staged[index] {
          add_style
        } else if picked {
          ground
        } else {
          @theme.faint_style
        },
      ),
      @strip.Strip::of(mark + " ", mark_style),
      @strip.Strip::of(
        @theme.fit(self.files[index], inner),
        if picked {
          ground
        } else if focused {
          value_style
        } else {
          @theme.quiet
        },
      ),
    ])
    return @strip.Strip::join([bar, body.pad_to(width - 1, @style.Style::new())]).crop(
      0, width,
    )
  }
  if pane == 1 {
    let text = self.commits[index]
    let hash = text[0:7].to_owned()
    let message = text[9:].to_owned()
    let hash_style = if picked {
      ground
    } else if focused {
      @theme.identifier
    } else {
      @theme.quiet
    }
    let body_style = if picked {
      ground
    } else if focused {
      value_style
    } else {
      @theme.quiet
    }
    let room = width - 2 - 9
    return @strip.Strip::join([
      bar,
      @strip.Strip::of(hash + "  ", hash_style),
      @strip.Strip::of(@theme.fit(message, room), body_style),
      @strip.Strip::blank(1, @style.Style::new()),
    ]).crop(0, width)
  }
  let text = self.branches[index]
  let current = index == self.current
  let style = if picked {
    ground
  } else if focused && current {
    @theme.mark
  } else if focused {
    @theme.body
  } else {
    @theme.quiet
  }
  @strip.Strip::join([
    bar,
    @strip.Strip::of(
      if current {
        "● "
      } else {
        "  "
      },
      if picked {
        ground
      } else {
        @theme.faint_style
      },
    ),
    @strip.Strip::of(@theme.fit(text, width - 4), style),
    @strip.Strip::blank(1, @style.Style::new()),
  ]).crop(0, width)
}

///|
impl @widget.Widget for Repo with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if width < 50 || height < 6 {
    return @strip.Strip::blank(width, @style.default)
  }
  if row == 0 {
    return @theme.band(
      "moonetui",
      subject="git",
      note="main · 3 ahead · clean",
      width~,
    )
  }
  if row == 1 {
    return @theme.rule(width~)
  }
  if row == height - 1 {
    return @theme.keys(
      [("tab", "pane"), ("↑↓", "move"), ("space", "stage"), ("q", "quit")],
      width~,
    )
  }
  let left = width * 22 / 100
  let middle = width * 41 / 100
  let right = width - left - middle - 4
  let body = row - 2
  if body == 0 {
    return @strip.Strip::join([
      @theme.head(
        "branches",
        count=self.branches.length().to_string(),
        width=left,
        active=self.focus == 0,
      ),
      gap(),
      @theme.head(
        "commits",
        count=self.commits.length().to_string(),
        width=middle,
        active=self.focus == 1,
      ),
      gap(),
      @theme.head(
        "changes",
        count=self.files.length().to_string(),
        width=right,
        active=self.focus == 2,
      ),
    ]).crop(0, width)
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
    gap(),
    cell(1, middle),
    gap(),
    cell(2, right),
  ])
  .crop(0, width)
  .pad_to(width, @style.Style::new())
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
