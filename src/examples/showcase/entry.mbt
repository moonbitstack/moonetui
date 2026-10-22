// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn input() -> Demo {
  let name = @widget.Input::new(placeholder="your name")
  let secret = @widget.Input::new(placeholder="password", password=true)
  let code = @widget.Input::new(placeholder="four digits", max_length=4)
  Demo::new(
    "Input",
    @app.column(0, [
      @app.leaf(1, name, box=line(1)),
      @app.leaf(2, secret, box=line(1)),
      @app.leaf(3, code, box=line(1)),
    ]),
    group=Entry,
    note="A single-line field with Textual's keys; a password field shows dots.",
    rows=3,
  )
}

///|
pub fn text_area() -> Demo {
  let area = @widget.TextArea::new(text="fn main {\n  println(\"hello\")\n}\n")
  Demo::new(
    "TextArea",
    @app.column(0, [@app.leaf(1, area)]),
    group=Entry,
    note="A multi-line editor with selection, undo, word moves and a line gutter.",
    rows=5,
  )
}

///|
pub fn log() -> Demo {
  let lines = @widget.Log::new()
  lines.write_lines([
    "boot ok", "loading modules", "listening on 12000", "ready",
  ])
  Demo::new(
    "Log",
    @app.column(0, [@app.leaf(1, lines)]),
    group=Entry,
    note="Lines that follow the tail until the reader scrolls away from it.",
    rows=4,
  )
}

///|
pub fn rich_log() -> Demo {
  let lines = @widget.RichLog::new(wrap=true)
  lines.write("deploy passed", style=@style.Style::new(fg=@style.green))
  lines.write("2 warnings", style=@style.Style::new(fg=@style.yellow))
  lines.write("one failure", style=@style.Style::new(fg=@style.red, bold=true))
  lines.write("done")
  Demo::new(
    "RichLog",
    @app.column(0, [@app.leaf(1, lines)]),
    group=Entry,
    note="A log of styled lines that can wrap to the width.",
    rows=4,
  )
}
