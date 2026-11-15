// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A player for a record: the spectrum it is drawing, the track that is on, how
// far into it the needle is, and the rest of the album. The position is seconds
// of the beat, so a frame test can seek to the end and hear the next track
// start.

///|
pub struct Track {
  title : String
  length : Int32
}

///|
pub struct Player {
  tracks : Array[Track]
  mut pick : Int32
  mut playing : Bool
  mut at : Int32
  mut beat : Int32
  mut volume : Int32
}

///|
pub fn Player::new() -> Player {
  let tracks : Array[Track] = [
    { title: "Aerial", length: 372, },
    { title: "Always", length: 248, },
    { title: "Rope and Summit", length: 301, },
    { title: "Without It", length: 195, },
    { title: "The Ghost of Old", length: 264, },
    { title: "So Clear", length: 226, },
    { title: "Burning Wires", length: 318, },
    { title: "Tide", length: 141, },
    { title: "Fields", length: 205, },
  ]
  { tracks, pick: 0, playing: true, at: 161, beat: 0, volume: 70, }
}

///|
pub fn Player::position(self : Player) -> Int32 {
  self.at
}

///|
pub fn Player::playing(self : Player) -> Bool {
  self.playing
}

///|
pub fn Player::length_of(self : Player, index : Int32) -> Int32 {
  self.tracks[index].length
}

///|
pub fn Player::total(self : Player) -> Int32 {
  let mut seconds = 0
  for track in self.tracks {
    seconds = seconds + track.length
  }
  seconds
}

///|
/// Play or pause. A paused needle stays where it is, and the spectrum settles.
pub fn Player::toggle(self : Player) -> Unit {
  self.playing = !self.playing
}

///|
/// Seek by `delta` seconds, and never past either end of the track.
pub fn Player::seek(self : Player, delta : Int32) -> Unit {
  let next = self.at + delta
  let end = self.tracks[self.pick].length
  if next < 0 {
    self.at = 0
  } else if next > end {
    self.at = end
  } else {
    self.at = next
  }
}

///|
pub fn Player::loudness(self : Player, delta : Int32) -> Unit {
  let next = self.volume + delta
  if next >= 0 && next <= 100 {
    self.volume = next
  }
}

///|
/// The next track, or the first one when the album ends.
pub fn Player::step(self : Player, delta : Int32) -> Unit {
  let n = self.tracks.length()
  self.pick = (self.pick + delta + n) % n
  self.at = 0
}

///|
/// The beat: a playing needle moves on a second at a time, and reaching the end
/// of a track starts the next one from the top.
pub fn Player::advance(self : Player, ms : Int32) -> Unit {
  self.beat = self.beat + 1
  if !self.playing {
    return
  }
  self.at = self.at + ms / 1000
  if self.at >= self.tracks[self.pick].length {
    self.step(1)
  }
}

///|
fn two(value : Int32) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
pub fn Player::clock(seconds : Int32) -> String {
  two(seconds / 60) + ":" + two(seconds % 60)
}

///|
pub fn Player::title(self : Player) -> String {
  self.tracks[self.pick].title
}

///|
/// The spectrum of the bar at `index`, from nought to one: three waves of
/// different lengths, so the shape moves as the needle does.
fn bar_at(index : Int32, at : Int32, playing : Bool) -> Double {
  if !playing {
    return 0.08 + (index % 3).to_double() * 0.02
  }
  let a = (index * 7 + at * 3) % 24
  let b = (index * 11 + at * 5) % 17
  let c = (index * 5 + at * 2) % 9
  let value = (a + b + c).to_double() / 50.0 + 0.12
  if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
let bars : Array[String] = [
  "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█",
]

///|
fn Player::spectrum_row(self : Player, width : Int32) -> Array[@strip.Strip] {
  let parts : Array[@strip.Strip] = []
  let n = if width > 0 { width } else { 1 }
  for x in 0..<n {
    let level = bar_at(x, self.at, self.playing)
    let mut step = (level * 7.0).to_int()
    if step < 0 {
      step = 0
    }
    if step > 7 {
      step = 7
    }
    let style = if step <= 1 {
      @style.Style::new(fg=@theme.muted)
    } else if step <= 3 {
      @style.Style::new(fg=@theme.accent)
    } else if step <= 5 {
      @style.Style::new(fg=@theme.accent_alt)
    } else {
      @style.Style::new(fg=@theme.warn, bold=true)
    }
    parts.push(@strip.Strip::of(bars[step], style))
  }
  parts
}

///|
let dim : @style.Style = @style.Style::new(fg=@theme.muted)

///|
let ink : @style.Style = @style.Style::new(fg=@theme.ink)

///|
let loud : @style.Style = @style.Style::new(fg=@theme.accent, bold=true)

///|
let frame_style : @style.Style = @style.Style::new(fg=@theme.muted)

///|
fn rule(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("─")
  }
  out.to_string()
}

///|
fn heavy(count : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_string("━")
  }
  out.to_string()
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
/// A line of the now-playing panel, filled to the panel's inside.
fn inside(parts : Array[@strip.Strip], width : Int32) -> @strip.Strip {
  @strip.Strip::join(parts).pad_to(width, @style.Style::new())
}

///|
fn panel(
  width : Int32,
  row : Int32,
  height : Int32,
  body : @strip.Strip,
) -> @strip.Strip {
  if row == 0 {
    let head = "╭─ NOW PLAYING "
    let tail = " ♪ ─╮"
    let fill = width - @strip.str_cells(head) - @strip.str_cells(tail)
    return @strip.Strip::from_segs([
      @strip.Seg::new(head, @style.Style::new(fg=@theme.accent, bold=true)),
      @strip.Seg::new(if fill > 0 { rule(fill) } else { "" }, frame_style),
      @strip.Seg::new(tail, frame_style),
    ])
  }
  if row == height - 1 {
    return @strip.Strip::of("╰" + rule(width - 2) + "╯", frame_style)
  }
  @strip.Strip::join([
    @strip.Strip::of("│", frame_style),
    body,
    @strip.Strip::of("│", frame_style),
  ])
}

///|
impl @widget.Widget for Player with fn render_line(self, row, size) {
  let width = size.width
  let height = size.height
  let inner = width - 2
  if row == 0 {
    let left = @strip.Strip::of(
      " ♪ TUNES",
      @style.Style::new(fg=@theme.accent_alt, bold=true),
    )
    let right_text = @strip.Strip::of(
      "junip · fields · 2010  ·  " +
      Player::clock(self.total()) +
      " of music ",
      dim,
    )
    let fill = width - left.cell_length() - right_text.cell_length()
    return @strip.Strip::join([
      left,
      @strip.Strip::blank(if fill > 0 { fill } else { 0 }, @style.Style::new()),
      right_text,
    ]).pad_to(width, @style.Style::new())
  }
  if row == 1 {
    return @strip.Strip::of(rule(width), frame_style)
  }
  if row == height - 1 {
    return @strip.Strip::of(
      " ↑↓ track · space play · ←→ seek · +− volume · esc quit ", dim,
    ).pad_to(width, @style.Style::new())
  }
  let panel_h = 8
  if row >= 2 && row < 2 + panel_h {
    let at = row - 2
    let body = if at == 1 {
      inside(
        [
          @strip.Strip::of("  ", @style.Style::new()),
          @strip.Strip::join(self.spectrum_row(inner - 2)),
        ],
        inner,
      )
    } else if at == 3 {
      inside(
        [
          @strip.Strip::of(
            "  " + left(self.title(), inner - 12),
            @style.Style::new(fg=@theme.ink, bold=true),
          ),
          @strip.Strip::of(
            right(
              (self.pick + 1).to_string() +
              " of " +
              self.tracks.length().to_string(),
              10,
            ),
            dim,
          ),
        ],
        inner,
      )
    } else if at == 4 {
      inside(
        [
          @strip.Strip::of(
            "  junip · fields (2010) · track " + (self.pick + 1).to_string(),
            dim,
          ),
        ],
        inner,
      )
    } else if at == 5 {
      let bar_width = inner - 20
      let filled = self.at * bar_width / self.tracks[self.pick].length
      inside(
        [
          @strip.Strip::of("  " + Player::clock(self.at), ink),
          @strip.Strip::of(" ", dim),
          @strip.Strip::of(
            heavy(filled),
            @style.Style::new(fg=@theme.accent_alt),
          ),
          @strip.Strip::of(
            rule(if bar_width - filled > 0 { bar_width - filled } else { 0 }),
            @style.Style::new(fg=@style.Rgb(0x2c, 0x30, 0x44)),
          ),
          @strip.Strip::of(
            " " + Player::clock(self.tracks[self.pick].length),
            dim,
          ),
        ],
        inner,
      )
    } else if at == 6 {
      let volume = self.volume * 10 / 100
      inside(
        [
          @strip.Strip::of("  ◀◀  ", dim),
          @strip.Strip::of(if self.playing { "▶" } else { "▮▮" }, loud),
          @strip.Strip::of("  ▶▶      vol ", dim),
          @strip.Strip::of(heavy(volume), @style.Style::new(fg=@theme.accent)),
          @strip.Strip::of(
            rule(10 - volume),
            @style.Style::new(fg=@style.Rgb(0x2c, 0x30, 0x44)),
          ),
          @strip.Strip::of("  " + self.volume.to_string() + "%", dim),
        ],
        inner,
      )
    } else {
      @strip.Strip::blank(inner, @style.Style::new())
    }
    return panel(width, at, panel_h, body)
  }
  let list_top = 2 + panel_h
  let index = row - list_top
  if index >= 0 && index < self.tracks.length() {
    let track = self.tracks[index]
    let here = index == self.pick
    let line = @strip.Strip::join([
      @strip.Strip::of(
        if here {
          " ▎"
        } else {
          "  "
        },
        if here {
          loud
        } else {
          dim
        },
      ),
      @strip.Strip::of(
        right((index + 1).to_string(), 2) + "  ",
        if here {
          ink
        } else {
          dim
        },
      ),
      @strip.Strip::of(
        cut(track.title, inner - 14),
        if here {
          ink
        } else {
          dim
        },
      ),
    ]).pad_to(inner - 8, @style.Style::new())
    return @strip.Strip::join([
      line,
      @strip.Strip::of(
        "  " + Player::clock(track.length) + " ",
        if here {
          ink
        } else {
          dim
        },
      ),
    ]).pad_to(width, @style.Style::new())
  }
  @strip.Strip::blank(width, @style.Style::new())
}

///|
impl @widget.Widget for Player with fn hint(_self, _size) {
  @geom.Size::new(56, 16)
}

///|
impl @widget.Widget for Player with fn focusable(_self) {
  true
}

///|
impl @widget.Widget for Player with fn handle(self, ctx, msg) {
  match msg {
    Key(key) =>
      match key.code {
        Up => {
          self.step(-1)
          ctx.repaint()
          true
        }
        Down => {
          self.step(1)
          ctx.repaint()
          true
        }
        Left => {
          self.seek(-10)
          ctx.repaint()
          true
        }
        Right => {
          self.seek(10)
          ctx.repaint()
          true
        }
        Char(32) => {
          self.toggle()
          ctx.repaint()
          true
        }
        Char(43) => {
          self.loudness(5)
          ctx.repaint()
          true
        }
        Char(45) => {
          self.loudness(-5)
          ctx.repaint()
          true
        }
        _ => false
      }
    Tick(ms) => {
      self.advance(ms)
      ctx.repaint()
      true
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
  player : Player
}

///|
pub fn Screen::new() -> Screen {
  let player = Player::new()
  let root = @app.column(0, [
    @app.leaf(1, player, box=@layout.Box::new(extent=Frac(1))),
  ])
  { root, player, }
}
