// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The UTF-16 units of `text` as hex, so what this test hands over survives the
/// trip through a test runner unchanged.
fn hex16(text : String) -> String {
  let out = StringBuilder()
  let digit = fn(v : Int32) {
    if v < 10 {
      (48 + v).unsafe_to_char()
    } else {
      (97 + v - 10).unsafe_to_char()
    }
  }
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    out.write_char(digit(unit / 0x1000 % 16))
    out.write_char(digit(unit / 0x100 % 16))
    out.write_char(digit(unit / 0x10 % 16))
    out.write_char(digit(unit % 16))
  }
  out.to_string()
}

///|
/// Announces one frame: its name, the emulators that can model it, the bytes
/// that draw it, and the rows it is meant to show.
/// `scripts/verify_terminals.py` draws the same bytes with two terminal
/// emulators this library has no part in; what they show has to be these rows.
fn announce(
  name : String,
  engines : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  let line = StringBuilder()
  line.write_string(
    "interop\t" +
    name +
    "\t" +
    engines +
    "\t" +
    size.width.to_string() +
    "\t" +
    size.height.to_string() +
    "\t" +
    hex16(stream),
  )
  for row in rows {
    line.write_string("\t" + hex16(row))
  }
  println(line.to_string())
}

///|
/// Rows of one frame, as the bytes that draw it and the screen it fills.
fn composite(
  rows : Array[@strip.Strip],
  size : @geom.Size,
) -> (String, Array[String]) {
  let spans = @comp.full(rows)
  let stream = @comp.encode(spans, @style.default)
  let screen = @vt.Grid::new(size.width, size.height)
  screen.write(stream)
  (stream, screen.rows())
}

///|
test "the attributes this library writes are the ones a terminal draws" {
  let size = @geom.Size::new(28, 3)
  let rows : Array[@strip.Strip] = [
    @strip.Strip::from_segs([
      @strip.Seg::new("plain ", @style.default),
      @strip.Seg::new("bold", @style.Style::new(bold=true)),
      @strip.Seg::new(" ", @style.default),
      @strip.Seg::new("red", @style.Style::new(fg=@style.red, bg=@style.black)),
    ]),
    @strip.Strip::from_segs([
      @strip.Seg::new("under", @style.Style::new(underline=true)),
      @strip.Seg::new(" reverse", @style.Style::new(reverse=true)),
      @strip.Seg::new(" dim", @style.Style::new(dim=true)),
    ]),
    @strip.Strip::from_segs([
      @strip.Seg::new("rgb", @style.Style::new(fg=@style.Colour::rgb(1, 2, 3))),
      @strip.Seg::new(
        " indexed",
        @style.Style::new(fg=@style.Colour::Ansi256(200)),
      ),
    ]),
  ]
  let (stream, drawn) = composite(rows, size)
  announce("attributes", "pyte,tmux", size, stream, drawn)
  // What was drawn is what was meant: every row is its text, padded to width.
  assert_eq(drawn[0], "plain bold red              ")
  assert_eq(drawn[1], "under reverse dim           ")
}

///|
test "wide characters land on the columns the frame puts them on" {
  let size = @geom.Size::new(20, 3)
  let rows : Array[@strip.Strip] = [
    @strip.Strip::of("中文abc", @style.default),
    @strip.Strip::of("ｱｲｳabc", @style.default),
    @strip.Strip::of("\u{1F1EF}\u{1F1F5} e\u{301}", @style.default),
  ]
  let (stream, drawn) = composite(rows, size)
  announce("wide", "pyte,tmux", size, stream, drawn)
  assert_eq(drawn[0], "中文abc             ")
  assert_eq(drawn[1], "ｱｲｳabc              ")
}

///|
test "a frame of widgets draws as the widgets, frame and all" {
  let size = @geom.Size::new(32, 10)
  let tty = @driver.Headless::new(size)
  let table = @widget.DataTable::new()
  ignore(table.add_column("name"))
  ignore(table.add_column("size"))
  ignore(table.add_row(["alpha", "12"]))
  ignore(table.add_row(["beta", "340"]))
  ignore(table.add_row(["中文", "7"]))
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["frame"]),
    @design.Styles::new(border=Round),
  )
  let ui = @app.App::new(
    tty,
    @app.column(1, [
      @app.leaf(1, @widget.Header::new("moonetui", note="0.3.6")),
      @app.leaf(2, table, classes=["frame"]),
      @app.leaf(3, @widget.Progress::new(total=10)),
      @app.leaf(4, @widget.Footer::new([("q", "quit")])),
    ]),
    sheet~,
  )
  ui.start()
  ui.refresh()
  ignore(ui.step())
  let rows = ui.screen()
  let screen = @vt.Grid::new(size.width, size.height)
  screen.write(tty.output())
  assert_eq(screen.rows(), rows)
  announce("widgets", "pyte,tmux", size, tty.output(), rows)
}

///|
test "a second frame is drawn over the first, and only where it moved" {
  let size = @geom.Size::new(20, 4)
  let tty = @driver.Headless::new(size)
  let field = @widget.Input::new()
  let ui = @app.App::new(
    tty,
    @app.column(0, [
      @app.leaf(1, @widget.Static::new("title")),
      @app.leaf(2, field),
    ]),
  )
  ui.start()
  ui.refresh()
  ignore(ui.step())
  let first = tty.output()
  field.set("beta")
  ui.refresh()
  ignore(ui.step())
  let both = tty.output()
  let rows = ui.screen()
  let screen = @vt.Grid::new(size.width, size.height)
  screen.write(first)
  screen.write(both)
  assert_eq(screen.rows(), rows)
  announce("redraw", "pyte,tmux", size, first + both, rows)
}

///|
/// A joined emoji is one cluster of two cells, and a terminal has to be told so
/// by the text itself: the bytes are the same as for the letters, the width is
/// not. pyte's cell buffer keeps one character per cell and loses the rest of a
/// joined sequence, so this frame is held to the multiplexer only.
test "a joined emoji arrives whole, and takes the cells of one emoji" {
  let size = @geom.Size::new(20, 3)
  let rows : Array[@strip.Strip] = [
    @strip.Strip::of("\u{1F469}\u{200D}\u{1F4BB} code", @style.default),
    @strip.Strip::of("\u{1F44D}\u{1F3FD} ok", @style.default),
    @strip.Strip::of("1\u{FE0F}\u{20E3} key", @style.default),
  ]
  let (stream, drawn) = composite(rows, size)
  announce("cluster", "tmux", size, stream, drawn)
  assert_eq(drawn[0], "\u{1F469}\u{200D}\u{1F4BB} code           ")
  assert_eq(drawn[1], "\u{1F44D}\u{1F3FD} ok               ")
}
