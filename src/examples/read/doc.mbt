// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// A Markdown reader: the library's own `Markdown` widget sets the page, between
// the band and the key bar every example wears.

///|
/// The page the reader opens.
pub let document : String =
  #|# moonetui
  #|
  #|A terminal toolkit for MoonBit: a cell buffer, a differential renderer, an
  #|incremental key parser, a *CSS-like* design system, and the widgets built on
  #|them.
  #|
  #|## What it is good at
  #|
  #|- one synchronous step per frame: poll, parse, dispatch, lay out, diff
  #|- the same code and the same tests on wasm, wasm-gc, js and native
  #|  - a headless driver for tests, a TTY driver for programs
  #|  - frames checked against real terminal emulators in CI
  #|- a redraw writes only the runs of cells that changed
  #|
  #|## Getting started
  #|
  #|1. Add the module.
  #|2. Pick a driver.
  #|3. Mount a tree of widgets and step it.
  #|
  #|```
  #|moon add moonbitstack/moonetui
  #|moon run --target native src/examples/read/main
  #|```
  #|
  #|> A terminal program is a page that redraws itself; the renderer is only the
  #|> printer.
  #|
  #|---
  #|
  #|## Widgets by kind
  #|
  #|| kind    | examples                     | state       |
  #||:--------|:-----------------------------|------------:|
  #|| text    | label, markdown, text area   | owned       |
  #|| lists   | list, table, tree            | owned       |
  #|| input   | input, checkbox, radio       | owned       |
  #|| charts  | sparkline, bars, gauge       | read only   |
  #|
  #|## Keys
  #|
  #|The arrows move a line, *page up* and *page down* a page, *home* and *end*
  #|go to the ends, and the wheel scrolls.
  #|
  #|## Where to go next
  #|
  #|- `src/examples/` holds a program for each kind of screen.
  #|- The documentation site lists every widget with a live demo.
  #|

///|
/// How the page is set: headings in the accent, code in the cool colour, quotes
/// muted, rules as faint as the hairlines between panes.
pub fn page() -> @widget.Markdown {
  @widget.Markdown::new(
    document,
    style=@style.Style::new(fg=@theme.ink),
    heading_style=@style.Style::new(fg=@theme.accent, bold=true),
    code_style=@style.Style::new(fg=@theme.cool),
    quote_style=@style.Style::new(fg=@theme.muted, italic=true),
    rule_style=@style.Style::new(fg=@theme.faint),
  )
}

///|
pub fn sheet() -> @design.Stylesheet {
  @theme.sheet()
}

///|
pub struct Screen {
  root : @app.Node
  page : @widget.Markdown
}

///|
pub fn Screen::new() -> Screen {
  let page = page()
  let band = @theme.line(width => {
    @theme.band("moonetui", subject="read", note="README.md", width~)
  })
  let keys = @theme.line(width => {
    @theme.keys(
      [
        ("↑↓", "line"),
        ("pgup pgdn", "page"),
        ("home end", "ends"),
        ("q", "quit"),
      ],
      width~,
    )
  })
  let root = @app.column(0, [
    @app.leaf(1, band, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(
      2,
      page,
      box=@layout.Box::new(extent=Frac(1), pad={
        top: 1,
        right: 2,
        bottom: 1,
        left: 2,
      }),
    ),
    @app.leaf(3, keys, box=@layout.Box::new(extent=Cells(1))),
  ])
  { root, page, }
}
