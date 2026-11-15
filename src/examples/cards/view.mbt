// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The table drawn as a table: dark green felt, cards of parchment with a
// printed edge, a card back the blue of the badge. Everything is five cells
// wide and three tall, so a column of seven starts at the same x as the
// foundation above it.

///|
const CARD_W : Int32 = 5

///|
/// Seven columns of five cells and six gaps: the width of the table.
const BOARD : Int32 = 41

///|
/// The first row of cards, and the first row of the columns.
const TOP_ROW : Int32 = 2

///|
const TABLE_TOP : Int32 = 6

///|
let felt : @style.Style = @style.Style::new(bg=@style.Rgb(0x10, 0x28, 0x21))

///|
let band : @style.Style = @style.Style::new(bg=@style.Rgb(0x08, 0x14, 0x10))

///|
let gold : @style.Colour = @style.Rgb(0xe9, 0xc8, 0x7c)

///|
let title_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xf3, 0xe4, 0xb4),
  bg=@style.Rgb(0x08, 0x14, 0x10),
  bold=true,
)

///|
let stat_style : @style.Style = @style.Style::new(
  fg=gold,
  bg=@style.Rgb(0x08, 0x14, 0x10),
)

///|
let keys_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x8c, 0x84, 0x66),
  bg=@style.Rgb(0x08, 0x14, 0x10),
)

///|
let note_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xe9, 0xc8, 0x7c),
  bg=@style.Rgb(0x08, 0x14, 0x10),
)

///|
let quiet_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x7c, 0x9b, 0x88),
)

///|
let prompt_style : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xd8, 0xb8, 0xf0),
  bold=true,
)

///|
/// The cream of a card face, and the two inks printed on it.
let face_border : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xd6, 0xd0, 0xbb),
  bg=@style.Rgb(0x10, 0x28, 0x21),
)

///|
let dark_face : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x1d, 0x20, 0x28),
  bg=@style.Rgb(0xf3, 0xee, 0xdd),
)

///|
let red_face : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xc0, 0x30, 0x2c),
  bg=@style.Rgb(0xf3, 0xee, 0xdd),
)

///|
let back_border : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x6f, 0x8f, 0xd8),
  bg=@style.Rgb(0x10, 0x28, 0x21),
)

///|
let back_face : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x8f, 0xab, 0xee),
  bg=@style.Rgb(0x22, 0x33, 0x63),
)

///|
/// Cards in the hand are lit lavender, so the pile they came from and the card
/// under the cursor are never the same colour.
let held_border : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xdc, 0xc9, 0xff),
  bg=@style.Rgb(0x10, 0x28, 0x21),
  bold=true,
)

///|
let held_face : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x2a, 0x1c, 0x3f),
  bg=@style.Rgb(0xbb, 0x9a, 0xf7),
  bold=true,
)

///|
let cursor_border : @style.Style = @style.Style::new(
  fg=@style.Rgb(0xf7, 0xdd, 0x9a),
  bg=@style.Rgb(0x10, 0x28, 0x21),
  bold=true,
)

///|
/// A slot that would take the cards in the hand glows the library's blue.
let aim_border : @style.Style = @style.Style::new(
  fg=@theme.accent,
  bg=@style.Rgb(0x10, 0x28, 0x21),
  bold=true,
)

///|
let slot_border : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x2e, 0x47, 0x3c),
  bg=@style.Rgb(0x10, 0x28, 0x21),
)

///|
let slot_mark : @style.Style = @style.Style::new(
  fg=@style.Rgb(0x3d, 0x5c, 0x4c),
  bg=@style.Rgb(0x10, 0x28, 0x21),
)

///|
fn mark_of(suit : Int32) -> String {
  match suit {
    0 => "♠"
    1 => "♥"
    2 => "♦"
    _ => "♣"
  }
}

///|
/// One line of a card: the printed edge, or the middle with its rank and suit
/// on cream.
fn card_chunk(
  card : Card,
  line : Int32,
  border : @style.Style,
  lifted : Bool,
) -> @strip.Strip {
  if line == 0 {
    return @strip.Strip::of("┌───┐", border)
  }
  if line == 2 {
    return @strip.Strip::of("└───┘", border)
  }
  let body = if lifted {
    held_face
  } else if !card.up {
    back_face
  } else if card.red() {
    red_face
  } else {
    dark_face
  }
  let text = if card.up { card.face_text() } else { "▓▓▓" }
  @strip.Strip::from_segs([
    @strip.Seg::new("│", border),
    @strip.Seg::new(text, body),
    @strip.Seg::new("│", border),
  ])
}

///|
/// An empty place on the table: a card's outline in a colour just above the
/// felt, with a suit mark for a foundation.
fn slot_chunk(
  line : Int32,
  mark : String,
  border : @style.Style,
) -> @strip.Strip {
  if line == 0 {
    return @strip.Strip::of("┌───┐", border)
  }
  if line == 2 {
    return @strip.Strip::of("└───┘", border)
  }
  @strip.Strip::from_segs([
    @strip.Seg::new("│", border),
    @strip.Seg::new(" " + mark + " ", slot_mark),
    @strip.Seg::new("│", border),
  ])
}

///|
fn felt_row(
  parts : Array[@strip.Strip],
  offset : Int32,
  width : Int32,
) -> @strip.Strip {
  let out : Array[@strip.Strip] = []
  if offset > 0 {
    out.push(@strip.Strip::blank(offset, felt))
  }
  for part in parts {
    out.push(part)
  }
  @strip.Strip::join(out).pad_to(width, felt)
}

///|
fn band_row(
  width : Int32,
  left : @strip.Strip,
  right : @strip.Strip,
) -> @strip.Strip {
  let fill = width - left.cell_length() - right.cell_length()
  let parts : Array[@strip.Strip] = [left]
  if fill > 0 {
    parts.push(@strip.Strip::blank(fill, band))
  }
  parts.push(right)
  @strip.Strip::join(parts).pad_to(width, band)
}

///|
fn centred(text : String, width : Int32, style : @style.Style) -> @strip.Strip {
  let cells = @strip.str_cells(text)
  let pad = if width > cells { (width - cells) / 2 } else { 0 }
  felt_row([@strip.Strip::of(text, style)], pad, width)
}

///|
fn clock_text(ms : Int32) -> String {
  let seconds = ms / 1000
  let rest = seconds % 60
  (seconds / 60).to_string() +
  ":" +
  (if rest < 10 { "0" } else { "" }) +
  rest.to_string()
}

///|
/// True when the slot under the cursor would take what the hand holds.
fn Table::aim_at(self : Table, head : Card?, column : Int32) -> Bool {
  match head {
    Some(card) =>
      self.pick == column && column != self.origin && self.accepts(column, card)
    None => false
  }
}

///|
fn Table::head(self : Table) -> Card? {
  if !self.holding {
    return None
  }
  let moved = self.moving()
  if moved.length() == 0 {
    None
  } else {
    Some(moved[0])
  }
}

///|
/// How far down a column the next card starts: two rows while the tallest
/// column has room for it, one when the terminal is short.
fn Table::step(self : Table, avail : Int32) -> Int32 {
  let mut tallest = 1
  for pile in self.piles {
    if pile.length() > tallest {
      tallest = pile.length()
    }
  }
  let wide = 3 + (tallest - 1) * 2
  if wide <= avail {
    2
  } else {
    1
  }
}

///|
fn Table::top_chunk(
  self : Table,
  head : Card?,
  column : Int32,
  line : Int32,
) -> @strip.Strip {
  let base = if self.pick == column && !self.holding {
    cursor_border
  } else if self.aim_at(head, column) {
    aim_border
  } else {
    slot_border
  }
  if column == 2 {
    return @strip.Strip::blank(CARD_W, felt)
  }
  if column == 0 {
    if self.stock.length() == 0 {
      let mark = if self.waste.length() > 0 { "↺" } else { " " }
      return slot_chunk(line, mark, base)
    }
    let border = if self.pick == column && !self.holding {
      cursor_border
    } else {
      back_border
    }
    return card_chunk(Card::new(0, 0, false), line, border, false)
  }
  if column == 1 {
    if self.waste.length() == 0 {
      return slot_chunk(line, " ", base)
    }
    let card = self.waste[self.waste.length() - 1]
    let lifted = self.holding && self.origin == 8
    let border = if lifted {
      held_border
    } else if self.pick == column && !self.holding {
      cursor_border
    } else if self.aim_at(head, column) {
      aim_border
    } else {
      face_border
    }
    return card_chunk(card, line, border, lifted)
  }
  let suit = column - 3
  let pile = self.found[suit]
  if pile.length() == 0 {
    return slot_chunk(line, mark_of(suit), base)
  }
  let card = pile[pile.length() - 1]
  let border = if self.pick == column && !self.holding {
    cursor_border
  } else if self.aim_at(head, column) {
    aim_border
  } else {
    face_border
  }
  card_chunk(card, line, border, false)
}

///|
fn Table::pile_chunk(
  self : Table,
  head : Card?,
  column : Int32,
  y : Int32,
  step : Int32,
) -> @strip.Strip {
  let pile = self.piles[column]
  let n = pile.length()
  if n == 0 {
    if y < 3 {
      let border = if self.pick == column && !self.holding {
        cursor_border
      } else if self.aim_at(head, column) {
        aim_border
      } else {
        slot_border
      }
      return slot_chunk(y, " ", border)
    }
    return @strip.Strip::blank(CARD_W, felt)
  }
  let mut idx = -1
  let mut i = 0
  while i < n {
    if i * step <= y {
      idx = i
    }
    i = i + 1
  }
  if idx < 0 {
    return @strip.Strip::blank(CARD_W, felt)
  }
  let line = y - idx * step
  if line > 2 {
    return @strip.Strip::blank(CARD_W, felt)
  }
  let card = pile[idx]
  if self.holding && column == self.origin && idx >= self.hold_from {
    return card_chunk(card, line, held_border, true)
  }
  let on_top = idx == n - 1
  let border = if on_top && self.aim_at(head, column) {
    aim_border
  } else if self.pick == column && !self.holding && idx == self.depth {
    cursor_border
  } else if card.up {
    face_border
  } else {
    back_border
  }
  card_chunk(card, line, border, false)
}

///|
fn title_row(row : Int32, width : Int32) -> @strip.Strip {
  if row == 6 {
    return centred(
      "♠  ♥    S O L I T A I R E    ♦  ♣", width, title_style,
    )
  }
  if row == 7 {
    return centred(
      "fifty-two cards · seven columns · four foundations", width, quiet_style,
    )
  }
  if row == 8 {
    return centred(
      "────────────────────────────",
      width, slot_border,
    )
  }
  if row == 10 {
    return centred("space deals a game", width, prompt_style)
  }
  if row >= 12 {
    let y = row - 12
    let chunks : Array[@strip.Strip] = []
    for column in 0..<COLUMNS {
      let count = column + 1
      let idx = if y < count { y } else { count - 1 }
      let line = y - idx
      if line <= 2 {
        chunks.push(
          card_chunk(Card::new(0, 0, false), line, back_border, false),
        )
      } else {
        chunks.push(@strip.Strip::blank(CARD_W, felt))
      }
    }
    return felt_row(
      spaced(chunks),
      if width > BOARD {
        (width - BOARD) / 2
      } else {
        0
      },
      width,
    )
  }
  @strip.Strip::blank(width, felt)
}

///|
fn spaced(chunks : Array[@strip.Strip]) -> Array[@strip.Strip] {
  let out : Array[@strip.Strip] = []
  let mut first = true
  for chunk in chunks {
    if !first {
      out.push(@strip.Strip::blank(1, felt))
    }
    out.push(chunk)
    first = false
  }
  out
}

///|
/// One row of the box that says the table is clear. It is drawn over the
/// columns rather than in place of them, so the table stays visible around it.
fn Table::banner_line(self : Table, row : Int32, w : Int32) -> @strip.Strip {
  let inner = w - 2
  if row == 0 || row == 4 {
    return @strip.Strip::of(
      (if row == 0 { "╔" } else { "╚" }) +
      ruled(inner, "═") +
      (if row == 0 { "╗" } else { "╝" }),
      cursor_border,
    )
  }
  let text = if row == 1 {
    if self.cheer / 240 % 2 == 0 {
      "✦  T H E   T A B L E   I S   C L E A R  ✦"
    } else {
      "✧  T H E   T A B L E   I S   C L E A R  ✧"
    }
  } else if row == 2 {
    "moves " +
    self.moves.to_string() +
    " · " +
    clock_text(self.clock) +
    " · pass " +
    self.passes.to_string()
  } else {
    "r deals again · u steps back"
  }
  let style = if row == 1 {
    title_style
  } else if row == 2 {
    stat_style
  } else {
    quiet_style
  }
  let cells = @strip.str_cells(text)
  let left = if inner > cells { (inner - cells) / 2 } else { 0 }
  let right = if inner > cells { inner - cells - left } else { 0 }
  @strip.Strip::from_segs([
    @strip.Seg::new("║", cursor_border),
    @strip.Seg::new(ruled(left, " "), band),
    @strip.Seg::new(text, style),
    @strip.Seg::new(ruled(right, " "), band),
    @strip.Seg::new("║", cursor_border),
  ])
}

///|
fn ruled(count : Int32, of : String) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string(of)
  }
  out.to_string()
}

///|
fn Table::keys_line(self : Table) -> String {
  match self.phase {
    Title => " space deals · esc quits"
    Playing =>
      " ←→ column  ↑↓ card  space lift/drop  enter draw  f home  u undo  r deal"
    Won => " r deals again  ·  u steps back  ·  esc quits"
  }
}

///|
impl @widget.Widget for Table with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  let bottom = if height >= 12 { height - 1 } else { -1 }
  if row == 0 {
    let left = @strip.Strip::of(" ♠ SOLITAIRE", title_style)
    let right = @strip.Strip::of(
      "stock " +
      self.stock.length().to_string() +
      "  ·  home " +
      self.home_count().to_string() +
      "/52  ·  moves " +
      self.moves.to_string() +
      "  ·  score " +
      self.score.to_string() +
      "  ·  " +
      clock_text(self.clock) +
      " ",
      stat_style,
    )
    return band_row(width, left, right)
  }
  if row == 1 {
    let note = self.note[0:@strip.cut_at(self.note, width - 2)]
    return band_row(
      width,
      @strip.Strip::of(" " + note.to_owned(), note_style),
      @strip.Strip::of("", band),
    )
  }
  if row == bottom {
    return band_row(
      width,
      @strip.Strip::of(self.keys_line(), keys_style),
      @strip.Strip::of("", band),
    )
  }
  if self.phase == Title {
    return title_row(row, width)
  }
  if row >= TOP_ROW && row < TOP_ROW + 3 {
    let head = self.head()
    let line = row - TOP_ROW
    let chunks : Array[@strip.Strip] = []
    for column in 0..<COLUMNS {
      chunks.push(self.top_chunk(head, column, line))
    }
    return felt_row(
      spaced(chunks),
      if width > BOARD {
        (width - BOARD) / 2
      } else {
        0
      },
      width,
    )
  }
  let avail = bottom - TABLE_TOP
  if row < TABLE_TOP || row >= bottom {
    return @strip.Strip::blank(width, felt)
  }
  let step = self.step(avail)
  let head = self.head()
  let chunks : Array[@strip.Strip] = []
  for column in 0..<COLUMNS {
    chunks.push(self.pile_chunk(head, column, row - TABLE_TOP, step))
  }
  let base = felt_row(
    spaced(chunks),
    if width > BOARD {
      (width - BOARD) / 2
    } else {
      0
    },
    width,
  )
  if self.phase == Won && row >= 9 && row < 14 && height >= 18 {
    let wide = 46
    let pad = if width > wide { (width - wide) / 2 } else { 0 }
    return @strip.Strip::join([
      base.crop(0, pad),
      self.banner_line(row - 9, wide),
      base.crop(pad + wide, width),
    ])
  }
  base
}

///|
impl @widget.Widget for Table with fn hint(_self, _size) {
  @geom.Size::new(BOARD, 21)
}

///|
impl @widget.Widget for Table with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Table with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Char(32) => {
          if self.phase == Won {
            self.deal()
          } else if self.phase == Title {
            self.deal()
          } else if self.holding {
            self.place()
          } else {
            self.grab()
          }
          ctx.repaint()
          true
        }
        Enter => {
          self.draw()
          ctx.repaint()
          true
        }
        Left => {
          self.aim(-1)
          ctx.repaint()
          true
        }
        Right => {
          self.aim(1)
          ctx.repaint()
          true
        }
        Up => {
          self.lift(-1)
          ctx.repaint()
          true
        }
        Down => {
          self.lift(1)
          ctx.repaint()
          true
        }
        Tab => {
          self.pick = if self.pick <= 6 { 8 } else { 0 }
          self.settle()
          ctx.repaint()
          true
        }
        BackTab => {
          self.pick = if self.pick <= 6 { 9 } else { 0 }
          self.settle()
          ctx.repaint()
          true
        }
        Char(102) => {
          self.home()
          ctx.repaint()
          true
        }
        Char(117) => {
          self.undo()
          ctx.repaint()
          true
        }
        Char(114) => {
          self.deal()
          ctx.repaint()
          true
        }
        Char(ch) =>
          if ch >= 49 && ch <= 55 {
            self.jump(ch - 49)
            ctx.repaint()
            true
          } else {
            false
          }
        _ => false
      }
    Tick(ms) => {
      let before = self.clock / 1000
      self.tick(ms)
      if self.phase == Won || self.clock / 1000 != before {
        ctx.repaint()
        true
      } else {
        false
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
pub struct Screen {
  root : @app.Node
  table : Table
}

///|
pub fn Screen::new() -> Screen {
  let table = Table::new()
  let root = @app.column(0, [
    @app.leaf(1, table, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, table, }
}
