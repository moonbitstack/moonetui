// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let head = @widget.Header::new("sensor node", note="115200 8n1")
  let temps = @widget.Sparkline::new(data=[21.0, 22.0, 24.5, 26.0, 25.0, 23.0])
  let bar = @widget.Progress::new(total=100)
  bar.set(78)
  let status = @widget.Log::new()
  status.write_lines(["link up", "reporting every second"])
  let tree = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, temps, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(3, status),
    @app.leaf(4, bar, box=@layout.Box::new(extent=Cells(1))),
  ])
  let wire = @driver.Headless::new(@geom.Size::new(40, 8))
  let ui = @app.App::new(wire, tree, plain=true)
  ui.start()
  let frame = wire.output()
  ui.stop()
  println("what the serial line receives, 40 columns by 8 rows:")
  println(frame)
  if frame.contains("\u{1b}") {
    println("escape bytes found on the wire")
  } else {
    println("no escape bytes on the wire: text and newlines only")
  }
}
