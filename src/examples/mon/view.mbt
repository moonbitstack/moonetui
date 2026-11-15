// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The route on the left, the party on the right, and the fight in a band under
// them. Tall grass is drawn in the library's green, the stream in its blue, and
// the party's hit points as a bar that loses its colour as it empties.

///|
const MAP_W : Int32 = 44

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let head_style : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let grass : @style.Style = @style.Style::new(fg=@style.Rgb(0x2f, 0x4a, 0x35))

///|
let tall : @style.Style = @style.Style::new(fg=@theme.good)

///|
let water : @style.Style = @style.Style::new(fg=@theme.accent)

///|
let path : @style.Style = @style.Style::new(fg=@style.Rgb(0x3c, 0x40, 0x52))

///|
let tree : @style.Style = @style.Style::new(fg=@style.Rgb(0x1f, 0x3a, 0x2a))

///|
let me : @style.Style = @style.Style::new(fg=@theme.accent_alt, bold=true)

///|
let healthy : @style.Style = @style.Style::new(fg=@theme.good)

///|
let hurt : @style.Style = @style.Style::new(fg=@theme.warn)

///|
let faint : @style.Style = @style.Style::new(fg=@theme.bad, bold=true)

///|
fn rule(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("─")
  }
  out.to_string()
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
fn cut(text : String, width : Int32) -> String {
  if @strip.str_cells(text) <= width {
    text
  } else {
    text[0:@strip.cut_at(text, width)].to_owned()
  }
}

///|
fn right(text : String, width : Int32) -> String {
  let cells = @strip.str_cells(text)
  if cells >= width {
    cut(text, width)
  } else {
    spaces(width - cells) + text
  }
}

///|
fn left(text : String, width : Int32) -> String {
  let cells = @strip.str_cells(text)
  if cells >= width {
    cut(text, width)
  } else {
    text + spaces(width - cells)
  }
}

///|
fn edge(
  width : Int32,
  top : Bool,
  title : String,
  note : String,
  body : @strip.Strip,
) -> @strip.Strip {
  if top {
    let head = "╭─ " + title + " "
    let tail = if note.length() > 0 { " " + note + " ─╮" } else { "─╮" }
    let fill = width - @strip.str_cells(head) - @strip.str_cells(tail)
    return @strip.Strip::from_segs([
      @strip.Seg::new(head, head_style),
      @strip.Seg::new(if fill > 0 { rule(fill) } else { "" }, frame_style),
      @strip.Seg::new(tail, dim),
    ])
  }
  @strip.Strip::join([
    @strip.Strip::of("│", frame_style),
    body,
    @strip.Strip::of("│", frame_style),
  ])
}

///|
fn floor(width : Int32) -> @strip.Strip {
  @strip.Strip::of("╰" + rule(width - 2) + "╯", frame_style)
}

///|
fn tile_style(tile : String) -> @style.Style {
  if tile == ":" {
    tall
  } else if tile == "~" {
    water
  } else if tile == "=" {
    path
  } else if tile == "T" {
    tree
  } else {
    grass
  }
}

///|
fn tile_glyph(tile : String) -> String {
  if tile == ":" {
    "▒▒"
  } else if tile == "~" {
    "~~"
  } else if tile == "=" {
    "=="
  } else if tile == "T" {
    "▓▓"
  } else {
    "  "
  }
}

///|
/// One row of the route: twenty tiles, two cells each, with the party's mark
/// drawn over the tile it stands on.
fn Field::map_row(self : Field, y : Int32, width : Int32) -> @strip.Strip {
  let parts : Array[@strip.Strip] = [@strip.Strip::of(" ", @style.Style::new())]
  for x in 0..<WIDE {
    if x == self.x && y == self.y {
      parts.push(@strip.Strip::of("@@", me))
    } else {
      let tile = tile_at(x, y)
      parts.push(@strip.Strip::of(tile_glyph(tile), tile_style(tile)))
    }
  }
  @strip.Strip::join(parts).pad_to(width, @style.Style::new())
}

///|
fn bar(hp : Int32, most : Int32, width : Int32) -> String {
  let filled = if most <= 0 { 0 } else { hp * width / most }
  let out = StringBuilder()
  for i in 0..<width {
    out.write_string(if i < filled { "█" } else { "░" })
  }
  out.to_string()
}

///|
fn hp_style(hp : Int32, most : Int32) -> @style.Style {
  if hp * 4 <= most {
    faint
  } else if hp * 2 <= most {
    hurt
  } else {
    healthy
  }
}

///|
impl @widget.Widget for Field with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  if row == 0 {
    let band = @strip.Strip::of(
      " ⬢ MONSTERS",
      @style.Style::new(fg=@theme.good, bold=true),
    )
    let stats = @strip.Strip::of(
      "badges " +
      self.badges.to_string() +
      "  ·  seen " +
      self.seen.to_string() +
      "  ·  caught " +
      self.caught.to_string() +
      "  ·  steps " +
      self.steps.to_string() +
      " ",
      dim,
    )
    let fill = width - band.cell_length() - stats.cell_length()
    return @strip.Strip::join([
      band,
      @strip.Strip::blank(if fill > 0 { fill } else { 0 }, @style.Style::new()),
      stats,
    ]).pad_to(width, @style.Style::new())
  }
  if row == 1 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " arrows walk · space strike · f flee · h potion · 1-3 party · esc quit ",
      dim,
    ).pad_to(width, @style.Style::new())
  }
  let panel_h = 10
  let right_w = width - MAP_W - 1
  let at = row - 2
  if row >= 2 && row < 2 + panel_h {
    let map = if at == 0 {
      edge(MAP_W, true, "ROUTE 4", "tall grass", @strip.Strip::empty())
    } else if at == panel_h - 1 {
      floor(MAP_W)
    } else if at - 1 < TALL {
      edge(MAP_W, false, "", "", self.map_row(at - 1, MAP_W - 2))
    } else {
      edge(
        MAP_W,
        false,
        "",
        "",
        @strip.Strip::blank(MAP_W - 2, @style.Style::new()),
      )
    }
    let party = if at == 0 {
      edge(
        right_w,
        true,
        "PARTY",
        self.lead_beast().name,
        @strip.Strip::empty(),
      )
    } else if at == panel_h - 1 {
      floor(right_w)
    } else {
      edge(right_w, false, "", "", self.party_row(at - 1, right_w - 2))
    }
    return @strip.Strip::join([
      map,
      @strip.Strip::blank(1, @style.Style::new()),
      party,
    ]).pad_to(width, @style.Style::new())
  }
  let battle_top = 2 + panel_h + 1
  if row >= battle_top && row < battle_top + 6 {
    return self.battle_row(row - battle_top, width)
  }
  @strip.Strip::blank(width, @style.Style::new())
}

///|
fn Field::party_row(self : Field, at : Int32, inner : Int32) -> @strip.Strip {
  if at < 6 {
    let index = at / 2
    if index >= self.party.length() {
      return @strip.Strip::blank(inner, @style.Style::new())
    }
    let beast = self.party[index]
    let front = index == self.lead
    if at % 2 == 0 {
      return @strip.Strip::join([
        @strip.Strip::of(
          if front {
            " ▸ "
          } else {
            "   "
          },
          if front {
            me
          } else {
            dim
          },
        ),
        @strip.Strip::of(
          left(beast.name, 9),
          if beast.hp > 0 {
            ink
          } else {
            dim
          },
        ),
        @strip.Strip::of(right("lv " + beast.level.to_string(), 7), dim),
      ]).pad_to(inner, @style.Style::new())
    }
    return @strip.Strip::join([
      @strip.Strip::of("   ", dim),
      @strip.Strip::of(
        bar(beast.hp, beast.most, 12),
        hp_style(beast.hp, beast.most),
      ),
      @strip.Strip::of(
        right(beast.hp.to_string() + "/" + beast.most.to_string(), 10),
        if beast.hp > 0 {
          dim
        } else {
          faint
        },
      ),
    ]).pad_to(inner, @style.Style::new())
  }
  if at == 7 {
    return @strip.Strip::of(
      cut("   potions x" + self.potions.to_string() + "  ·  rope x1", inner),
      dim,
    ).pad_to(inner, @style.Style::new())
  }
  @strip.Strip::blank(inner, @style.Style::new())
}

///|
/// The band under the panels: the fight while it lasts, and the last four lines
/// of what has happened when it does not.
fn Field::battle_row(
  self : Field,
  at : Int32,
  width : Int32,
  height : Int32,
) -> @strip.Strip {
  let inner = width - 2
  let lead = self.party[self.lead]
  if self.mode == Walk {
    if at == 0 {
      return @strip.Strip::join([
        @strip.Strip::of(" FIELD NOTES", head_style),
        @strip.Strip::of("  " + self.log[self.log.length() - 1], dim),
      ]).pad_to(width, @style.Style::new())
    }
    let line = at - 1
    if line >= 0 && line < self.log.length() {
      return @strip.Strip::of("  › " + cut(self.log[line], width - 4), dim).pad_to(
        width,
        @style.Style::new(),
      )
    }
    return @strip.Strip::blank(width, @style.Style::new())
  }
  let title = if self.mode == Won {
    "CAUGHT"
  } else {
    "A WILD " + self.enemy + " APPEARED"
  }
  if at == 0 {
    let tail = if self.mode == Won {
      "one for the party"
    } else {
      "turn " + self.turn.to_string()
    }
    return edge(width, true, title, tail, @strip.Strip::empty())
  }
  if at == 5 {
    return floor(width)
  }
  let body = if at == 1 {
    @strip.Strip::join([
      @strip.Strip::of("  ● " + left(self.enemy, 10), ink),
      @strip.Strip::of(
        bar(self.enemy_hp, self.enemy_most, 20),
        hp_style(self.enemy_hp, self.enemy_most),
      ),
      @strip.Strip::of(
        right(self.enemy_hp.to_string() + "/" + self.enemy_most.to_string(), 10),
        dim,
      ),
    ])
  } else if at == 3 {
    @strip.Strip::join([
      @strip.Strip::of("  ● " + left(lead.name, 10), me),
      @strip.Strip::of(
        bar(lead.hp, lead.most, 20),
        hp_style(lead.hp, lead.most),
      ),
      @strip.Strip::of(
        right(lead.hp.to_string() + "/" + lead.most.to_string(), 10),
        dim,
      ),
    ])
  } else if at == 4 {
    @strip.Strip::of(
      "  " + cut(self.log[self.log.length() - 1], inner),
      if self.mode == Won {
        healthy
      } else {
        dim
      },
    )
  } else {
    @strip.Strip::of("", dim)
  }
  let body = if at == 2 {
    @strip.Strip::of("  " + cut("space strikes · f runs", inner - 2), dim)
  } else {
    body
  }
  edge(width, false, "", "", body.pad_to(inner, @style.Style::new()))
}

///|
impl @widget.Widget for Field with fn hint(_self, _size) {
  @geom.Size::new(64, 18)
}

///|
impl @widget.Widget for Field with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Field with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Up => {
          self.walk(0, -1)
          ctx.repaint()
          true
        }
        Down => {
          self.walk(0, 1)
          ctx.repaint()
          true
        }
        Left => {
          self.walk(-1, 0)
          ctx.repaint()
          true
        }
        Right => {
          self.walk(1, 0)
          ctx.repaint()
          true
        }
        Char(32) | Enter => {
          if self.mode == Won {
            self.rest()
          } else if self.mode == Fight {
            self.strike()
          } else {
            self.heal()
          }
          ctx.repaint()
          true
        }
        Char(102) => {
          self.flee()
          ctx.repaint()
          true
        }
        Char(104) => {
          self.heal()
          ctx.repaint()
          true
        }
        Char(ch) =>
          if ch >= 49 && ch <= 51 {
            let index = ch - 49
            if index < self.party.length() && self.party[index].hp > 0 {
              self.lead = index
              ctx.repaint()
              true
            } else {
              false
            }
          } else {
            false
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
  field : Field
}

///|
pub fn Screen::new() -> Screen {
  let field = Field::new()
  let root = @app.column(0, [
    @app.leaf(1, field, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, field, }
}
