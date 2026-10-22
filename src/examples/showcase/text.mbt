// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn static_text() -> Demo {
  let left = @widget.Static::new("Text sits on the left by default.")
  let centre = @widget.Static::new("Or in the centre,", align=Centre)
  let right = @widget.Static::new("or on the right.", align=Right)
  let tinted = @widget.label(
    "label() styles it in one call.",
    style=@style.Style::new(fg=@style.cyan, bold=true),
  )
  Demo::new(
    "Static",
    @app.column(0, [
      @app.leaf(1, left, box=line(1)),
      @app.leaf(2, centre, box=line(1)),
      @app.leaf(3, right, box=line(1)),
      @app.leaf(4, tinted, box=line(1)),
    ]),
    group=Text,
    note="Text clipped at a character boundary, aligned left, centre or right.",
    rows=4,
  )
}

///|
pub fn header() -> Demo {
  let bar = @widget.Header::new("moonetui", note="ctrl-c to quit")
  Demo::new(
    "Header",
    @app.column(0, [@app.leaf(1, bar, box=line(1))]),
    group=Text,
    note="The title bar: the title in the centre, a note at the right edge.",
    rows=1,
  )
}

///|
pub fn footer() -> Demo {
  let bar = @widget.Footer::new([
    ("tab", "next"),
    ("enter", "choose"),
    ("esc", "back"),
    ("q", "quit"),
  ])
  Demo::new(
    "Footer",
    @app.column(0, [@app.leaf(1, bar, box=line(1))]),
    group=Text,
    note="Key hints along the bottom edge, as many as the width holds.",
    rows=1,
  )
}

///|
pub fn rule() -> Demo {
  let kinds : Array[(String, @widget.RuleKind)] = [
    ("solid", Solid),
    ("heavy", Heavy),
    ("double", Double),
    ("dashed", Dashed),
    ("thick", Thick),
    ("ascii", Ascii),
  ]
  let rows = kinds.mapi((i, kind) => {
    @app.row(
      i * 10,
      [
        @app.leaf(i * 10 + 1, @widget.Static::new(kind.0), box=line(8)),
        @app.leaf(
          i * 10 + 2,
          @widget.Rule::horizontal(kind=kind.1),
          box=@layout.Box::new(extent=Frac(1)),
        ),
      ],
      box=line(1),
    )
  })
  Demo::new(
    "Rule",
    @app.column(100, rows),
    group=Text,
    note="A horizontal or vertical rule in any of nine styles.",
    rows=6,
  )
}

///|
pub fn digits() -> Demo {
  let clock = @widget.Digits::new(value="12:34")
  let price = @widget.Digits::new(
    value="€9.99",
    style=@style.Style::new(fg=@style.yellow, bold=true),
  )
  Demo::new(
    "Digits",
    @app.row(
      0,
      [@app.leaf(1, clock, box=line(17)), @app.leaf(2, price)],
      box=line(3),
    ),
    group=Text,
    note="Three-row glyphs for clocks and counters, plain or bold.",
    rows=3,
  )
}

///|
pub fn sparkline() -> Demo {
  let load = @widget.Sparkline::new(data=[
    3.0, 5.0, 2.0, 8.0, 6.0, 4.0, 7.0, 9.0, 5.0, 3.0, 6.0, 8.0, 4.0, 2.0, 5.0, 7.0,
  ])
  let tall = @widget.Sparkline::new(
    data=[1.0, 2.0, 4.0, 7.0, 9.0, 7.0, 4.0, 2.0, 1.0, 2.0, 4.0, 7.0],
    summary=Mean,
  )
  Demo::new(
    "Sparkline",
    @app.column(0, [
      @app.leaf(1, load, box=line(1)),
      @app.leaf(2, tall, box=line(3)),
    ]),
    group=Text,
    note="An eight-level bar chart that buckets its data to fit the width.",
    rows=4,
  )
}

///|
pub fn progress() -> Demo {
  let done = @widget.Progress::new(total=100)
  done.set(62)
  let fine = @widget.Progress::new(total=1000)
  fine.set(333)
  Demo::new(
    "Progress",
    @app.column(0, [
      @app.leaf(1, done, box=line(1)),
      @app.leaf(2, fine, box=line(1)),
    ]),
    group=Text,
    note="A bar against a total, filled in eighths of a column.",
    rows=2,
  )
}

///|
pub fn loading_indicator() -> Demo {
  Demo::new(
    "LoadingIndicator",
    @app.column(0, [@app.leaf(1, @widget.LoadingIndicator::new())]),
    group=Text,
    note="Five dots that pulse on every frame, for work with no end in sight.",
    rows=3,
  )
}

///|
pub fn placeholder() -> Demo {
  Demo::new(
    "Placeholder",
    @app.row(0, [
      @app.leaf(
        1,
        @widget.Placeholder::new(label="Sidebar"),
        box=@layout.Box::new(extent=Frac(1)),
      ),
      @app.leaf(
        2,
        @widget.Placeholder::new(label="Content", colour=3),
        box=@layout.Box::new(extent=Frac(2)),
      ),
    ]),
    group=Text,
    note="A coloured stand-in for a widget not written yet; a click cycles what it shows.",
    rows=4,
  )
}
