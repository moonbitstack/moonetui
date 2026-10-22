// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn data_table() -> Demo {
  let table = @widget.DataTable::new(zebra=true)
  ignore(table.add_column("Target", width=10))
  ignore(table.add_column("Tests", width=6, align=Right))
  ignore(table.add_column("Status"))
  ignore(table.add_row(["wasm", "336", "pass"]))
  ignore(table.add_row(["wasm-gc", "336", "pass"]))
  ignore(table.add_row(["js", "336", "pass"]))
  ignore(table.add_row(["native", "336", "pass"]))
  Demo::new(
    "DataTable",
    @app.column(0, [@app.leaf(1, table)]),
    group=Data,
    note="Columns, a cell cursor, sorting by any column, and stripes if asked.",
    rows=5,
  )
}

///|
pub fn markdown() -> Demo {
  let doc = @widget.Markdown::new(
    "# Deploy report\n\nAll **four** backends pass, with `--deny-warn`.\n\n- wasm and wasm-gc\n- js and native\n\n> Shipped on a Thursday.",
  )
  Demo::new(
    "Markdown",
    @app.column(0, [@app.leaf(1, doc)]),
    group=Data,
    note="Headings, emphasis, lists, quotes, code and tables, wrapped to the width.",
    rows=9,
  )
}

///|
pub fn tooltip() -> Demo {
  let tip = @widget.Tooltip::new(
    "Builds every target and runs the whole suite on each.",
    max_width=34,
    style=@style.Style::new(bg=@style.Colour::rgb(60, 60, 80)),
  )
  Demo::new(
    "Tooltip",
    @app.column(0, [@app.leaf(1, tip)]),
    group=Data,
    note="A padded box of wrapped text, for a hint beside what it explains.",
    rows=4,
  )
}

///|
pub fn toast() -> Demo {
  let done = @widget.Toast::new(
    "All four backends pass.",
    title="Deployed",
    duration=0,
  )
  let warn = @widget.Toast::new(
    "Two tests were skipped.",
    title="Heads up",
    level=Warning,
    duration=0,
  )
  Demo::new(
    "Toast",
    @app.column(0, [@app.leaf(1, done), @app.leaf(2, warn)]),
    group=Data,
    note="A notice with a coloured bar for its level; it expires on its own or on a click.",
    rows=4,
  )
}
