// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "each caret names its DECSCUSR code" {
  assert_eq(@widget.Terminal.code(), 0)
  assert_eq(@widget.Block(blink=true).code(), 1)
  assert_eq(@widget.Block(blink=false).code(), 2)
  assert_eq(@widget.Underline(blink=true).code(), 3)
  assert_eq(@widget.Underline(blink=false).code(), 4)
  assert_eq(@widget.Bar(blink=true).code(), 5)
  assert_eq(@widget.Bar(blink=false).code(), 6)
  assert_eq(@widget.Bar(blink=true).sequence(), "\u{1b}[5 q")
  assert_eq(@widget.caret, @widget.Terminal)
}

///|
test "a field with a caret puts the terminal's cursor where the typing goes" {
  let field = @widget.Input::new(caret=Bar(blink=true))
  let tree = @app.column(0, [
    @app.leaf(9, @widget.Static::new("name")),
    @app.leaf(1, field),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(12, 2), script=[ascii("hi")])
  let ui = @app.App::new(tty, tree)
  ui.start()
  let first = tty.output()
  // Row 1 is the field's, column 0 the empty text's end; the bar blinks.
  assert_true(first.contains("\u{1b}[2;1H\u{1b}[5 q\u{1b}[?25h"))
  tty.clear_output()
  ui.step() |> ignore
  assert_eq(field.text(), "hi")
  // Two characters typed, so the caret is two columns on, and the field draws
  // no cursor of its own.
  assert_true(tty.output().contains("\u{1b}[2;3H\u{1b}[5 q\u{1b}[?25h"))
  assert_false(tty.output().contains("\u{1b}[7m"))
  tty.clear_output()
  ui.stop()
  assert_true(tty.output().contains("\u{1b}[0 q"))
}

///|
test "a field without a caret draws its own cursor and leaves the terminal's hidden" {
  let field = @widget.Input::new()
  let tree = @app.column(0, [@app.leaf(1, field)])
  let tty = @driver.Headless::new(@geom.Size::new(8, 1), script=[ascii("hi")])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.step() |> ignore
  ui.stop()
  let out = tty.output()
  assert_false(out.contains(" q"))
  assert_false(out.contains("\u{1b}[?25h\u{1b}[?2026l"))
}

///|
test "a text area's caret follows the gutter and the line" {
  let area = @widget.TextArea::new(
    text="one\ntwo",
    caret=Underline(blink=false),
  )
  let tree = @app.column(0, [@app.leaf(1, area)])
  let tty = @driver.Headless::new(@geom.Size::new(16, 3))
  let ui = @app.App::new(tty, tree)
  ui.start()
  let at = area.cursor()
  let out = tty.output()
  assert_true(out.contains("\u{1b}[4 q\u{1b}[?25h"))
  assert_eq(at, (0, 0))
}
