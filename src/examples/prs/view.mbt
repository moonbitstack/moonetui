// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The page a reviewer keeps open: the open requests with the checks on them, a
// card for the one under the cursor, and the repository's own feed at the foot.

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let good : @style.Style = @style.Style::new(fg=@theme.good, bold=true)

///|
let warn : @style.Style = @style.Style::new(fg=@theme.warn, bold=true)

///|
let bad : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
let mark : @style.Style = @style.Style::new(fg=@theme.accent_alt, bold=true)

///|
/// The band under the row the cursor is on: one step up from the page, so the
/// colours of the row keep their meaning.
let band_bg : @style.Style = @style.Style::new(bg=@style.Rgb(0x1e, 0x22, 0x33))

///|
fn cells_of(text : String) -> Int32 {
  @strip.str_cells(text)
}

///|
fn cut(text : String, width : Int32) -> String {
  if cells_of(text) <= width {
    text
  } else {
    text[0:@strip.cut_at(text, width)].to_owned()
  }
}

///|
fn spaces(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(" ")
  }
  out.to_string()
}

///|
fn left(text : String, width : Int32) -> String {
  let cells = cells_of(text)
  if cells >= width {
    cut(text, width)
  } else {
    text + spaces(width - cells)
  }
}

///|
fn right(text : String, width : Int32) -> String {
  let cells = cells_of(text)
  if cells >= width {
    cut(text, width)
  } else {
    spaces(width - cells) + text
  }
}

///|
fn rule(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("─")
  }
  out.to_string()
}

///|
fn check_mark(check : Check) -> String {
  match check {
    Pass => "●"
    Pending => "○"
    Fail => "x"
  }
}

///|
fn check_style(check : Check) -> @style.Style {
  match check {
    Pass => good
    Pending => dim
    Fail => bad
  }
}

///|
fn review_text(review : Review) -> String {
  match review {
    Approved => "approved"
    Waiting => "waiting"
    Changes => "changes"
    Draft => "draft"
    Merged => "merged"
  }
}

///|
fn review_style(review : Review) -> @style.Style {
  match review {
    Approved => good
    Waiting => dim
    Changes => warn
    Draft => dim
    Merged => mark
  }
}

///|
fn Board::row(self : Board, index : Int32, inner : Int32) -> @strip.Strip {
  let pull = self.pulls[index]
  let here = index == self.pick
  let dots : Array[@strip.Strip] = []
  for check in pull.checks {
    dots.push(@strip.Strip::of(check_mark(check), check_style(check)))
  }
  let parts : Array[@strip.Strip] = [
    @strip.Strip::of(
      if here {
        "▸ "
      } else {
        "  "
      },
      if here {
        mark
      } else {
        dim
      },
    ),
    @strip.Strip::of(left("#" + pull.number.to_string(), 5) + " ", dim),
    @strip.Strip::of(
      left(cut(pull.title, 38), 38),
      if here {
        ink
      } else {
        ink
      },
    ),
    @strip.Strip::of(right("@" + pull.author, 7), dim),
    @strip.Strip::of("  ", dim),
  ]
  for dot in dots {
    parts.push(dot)
  }
  parts.push(@strip.Strip::of(" ", dim))
  parts.push(
    @strip.Strip::of(
      left(review_text(pull.review), 9),
      review_style(pull.review),
    ),
  )
  parts.push(@strip.Strip::of(right(pull.age, 5), dim))
  let line = @strip.Strip::join(parts)
  if here {
    line.apply(band_bg).pad_to(inner, band_bg)
  } else {
    line.pad_to(inner, @style.Style::new())
  }
}

///|
/// `1 comment`, `3 comments`: a count and the word it counts.
fn plural(count : Int32, word : String) -> String {
  if count == 1 {
    count.to_string() + " " + word
  } else {
    count.to_string() + " " + word + "s"
  }
}

///|
fn Board::card_line(self : Board, row : Int32, inner : Int32) -> @strip.Strip {
  let pull = self.pulls[self.pick]
  let body = if row == 1 {
    @strip.Strip::join([
      @strip.Strip::of("@" + pull.author + " ", ink),
      @strip.Strip::of(
        "wants to merge " + pull.commits.to_string() + " commits into ",
        dim,
      ),
      @strip.Strip::of("master", ink),
      @strip.Strip::of(" from ", dim),
      @strip.Strip::of(pull.branch, mark),
    ])
  } else if row == 2 {
    @strip.Strip::of("", dim)
  } else if row == 3 {
    @strip.Strip::join([
      @strip.Strip::of("+" + pull.added.to_string(), good),
      @strip.Strip::of(" -" + pull.removed.to_string(), bad),
      @strip.Strip::of(
        "   " +
        plural(pull.files, "file") +
        "   " +
        plural(pull.commits, "commit") +
        "   " +
        plural(pull.comments, "comment"),
        dim,
      ),
    ])
  } else {
    @strip.Strip::join([
      @strip.Strip::of("checks  ", dim),
      @strip.Strip::of(check_mark(pull.checks[0]), check_style(pull.checks[0])),
      @strip.Strip::of(check_mark(pull.checks[1]), check_style(pull.checks[1])),
      @strip.Strip::of(check_mark(pull.checks[2]), check_style(pull.checks[2])),
      @strip.Strip::of("      review  ", dim),
      @strip.Strip::of(review_text(pull.review), review_style(pull.review)),
    ])
  }
  // One cell of air between the border and the words: a card whose text
  // touches its own edge reads as a table, not a card.
  @strip.Strip::join([@strip.Strip::of(" ", @style.Style::new()), body])
  .crop(0, inner)
  .pad_to(inner, @style.Style::new())
}

///|
impl @widget.Widget for Board with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    return @theme.band(
      "moonetui",
      subject="prs",
      note="moonbitstack/moonetui · " +
        self.count(Waiting).to_string() +
        " waiting · " +
        self.count(Approved).to_string() +
        " approved",
      width~,
    )
  }
  if row == 1 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 1 {
    return @theme.keys(
      [
        ("↑↓", "pull request"),
        ("m", "merge"),
        ("tab", "checks"),
        ("q", "quit"),
      ],
      width~,
    )
  }
  let inner = width - 2
  let list = self.pulls.length()
  let card_top = if self.open { 3 + list } else { -1 }
  let card_h = 6
  if row >= 2 && row < 2 + list {
    return @strip.Strip::join([
      @strip.Strip::of(" ", @style.Style::new()),
      self.row(row - 2, inner),
      @strip.Strip::of(" ", @style.Style::new()),
    ]).pad_to(width, @style.Style::new())
  }
  if self.open && row >= card_top && row < card_top + card_h {
    let at = row - card_top
    let pull = self.pulls[self.pick]
    let top = "╭─ #" + pull.number.to_string() + " " + pull.title + " "
    let fill = width - 1 - cells_of(top)
    let edge = if at == 0 {
      @strip.Strip::from_segs([
        @strip.Seg::new(top, head_style),
        @strip.Seg::new(if fill > 0 { rule(fill) } else { "" }, frame_style),
        @strip.Seg::new("╮", frame_style),
      ])
    } else if at == card_h - 1 {
      @strip.Strip::of("╰" + rule(width - 2) + "╯", frame_style)
    } else {
      @strip.Strip::join([
        @strip.Strip::of("│ ", frame_style),
        self.card_line(at, width - 4),
        @strip.Strip::of(" │", frame_style),
      ])
    }
    return edge.pad_to(width, @style.Style::new())
  }
  let feed_top = if self.open { card_top + card_h + 1 } else { 3 + list }
  if row == feed_top && row < height - 1 {
    return @strip.Strip::join([
      @strip.Strip::of(" ACTIVITY", head_style),
      @strip.Strip::of("  " + self.note, dim),
    ]).pad_to(width, @style.Style::new())
  }
  if row > feed_top && row < height - 1 {
    let at = row - feed_top - 1
    if at < self.activity.length() {
      let line = self.activity[at]
      let stamp = cut(line, 7)
      let rest = line[7:].to_owned()
      return @strip.Strip::join([
        @strip.Strip::of("  " + stamp, frame_style),
        @strip.Strip::of(cut(rest, width - 10), dim),
      ]).pad_to(width, @style.Style::new())
    }
  }
  @strip.Strip::blank(width, @style.Style::new())
}

///|
impl @widget.Widget for Board with fn hint(_self, _size) {
  @geom.Size::new(60, 16)
}

///|
impl @widget.Widget for Board with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Board with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
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
        Char(32) => {
          self.fold()
          ctx.repaint()
          true
        }
        Char(109) => {
          self.merge()
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
  board : Board
}

///|
pub fn Screen::new() -> Screen {
  let board = Board::new()
  let root = @app.column(0, [
    @app.leaf(1, board, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, board, }
}
