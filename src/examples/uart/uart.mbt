// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// What a sensor node puts on a serial line: whole rows of plain text, no escape
// bytes at all, because the thing at the other end of the wire is not a
// terminal. The rows are a package of their own so CI can draw them without a
// serial port and hand them to two terminal emulators.

///|
pub struct Screen {
  head : @widget.Header
  temps : @widget.Sparkline
  status : @widget.Log
  bar : @widget.Progress
  root : @app.Node
}

///|
pub fn Screen::new() -> Screen {
  let head = @widget.Header::new("sensor node", note="115200 8n1")
  let temps = @widget.Sparkline::new(data=[21.0, 22.0, 24.5, 26.0, 25.0, 23.0])
  let bar = @widget.Progress::new(total=100)
  bar.set(78)
  let status = @widget.Log::new()
  status.write_lines(["link up", "reporting every second"])
  let root = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, temps, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(3, status),
    @app.leaf(4, bar, box=@layout.Box::new(extent=Cells(1))),
  ])
  { head, temps, status, bar, root, }
}
