// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Bytes from code values, so a test can write down what a terminal sends.
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
fn ascii(text : String) -> Bytes {
  let out : Array[Int] = []
  for i in 0..<text.length() {
    out.push(text[i].to_int())
  }
  bytes(out)
}

///|
test "an application draws its tree on the first frame" {
  let head = @widget.Header::new("moonetui")
  let list = @widget.ListView::new(["alpha", "beta"])
  let foot = @widget.Footer::new([("q", "quit")])
  let tree = @app.column(0, [
    @app.leaf(1, head, box=@layout.Box::new(extent=Cells(1))),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(3, foot, box=@layout.Box::new(extent=Cells(1))),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(12, 4))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), [
    "  moonetui  ", "alpha       ", "beta        ", " q quit     ",
  ])
  // The list is the only widget that can hold focus, so it has it.
  assert_eq(ui.focused(), 2)
}

///|
test "a key press reaches the focused widget and repaints" {
  let list = @widget.ListView::new(["one", "two", "three"])
  let tree = @app.column(0, [@app.leaf(1, list)])
  let tty = @driver.Headless::new(@geom.Size::new(8, 3), script=[
    ascii("\u{1b}[B"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.clear_output()
  ui.step() |> ignore
  assert_eq(list.index(), 1)
  // Only the two rows whose highlight changed are repainted.
  let written = tty.output()
  assert_eq(written.length() > 0, true)
  assert_eq(ui.screen()[1], "two     ")
}

///|
test "tab moves focus round the ring" {
  let first = @widget.Button::new("one")
  let second = @widget.Button::new("two")
  let tree = @app.row(0, [
    @app.leaf(1, first, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(2, second, box=@layout.Box::new(extent=Frac(1))),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(12, 1), script=[
    ascii("\t"),
    ascii("\t"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.focused(), 1)
  ui.step() |> ignore
  assert_eq(ui.focused(), 2)
  // The ring wraps rather than stopping at the end.
  ui.step() |> ignore
  assert_eq(ui.focused(), 1)
}

///|
test "what a widget reports reaches the host" {
  let button = @widget.Button::new("go")
  let tree = @app.column(0, [@app.leaf(1, button)])
  let tty = @driver.Headless::new(@geom.Size::new(8, 1), script=[ascii("\r")])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.drain(), [])
  ui.step() |> ignore
  assert_eq(ui.drain(), [Pressed(id=1)])
  // Draining twice does not report the same press again.
  assert_eq(ui.drain(), [])
}

///|
test "a click goes to the widget under the pointer" {
  let top = @widget.ListView::new(["a", "b"])
  let bottom = @widget.Button::new("go")
  let tree = @app.column(0, [
    @app.leaf(1, top, box=@layout.Box::new(extent=Cells(2))),
    @app.leaf(2, bottom, box=@layout.Box::new(extent=Cells(1))),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(6, 3), script=[
    // Row three, column one: the button.
    ascii("\u{1b}[<0;1;3M"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.step() |> ignore
  assert_eq(ui.focused(), 2)
  assert_eq(ui.drain(), [Pressed(id=2)])
}

///|
test "control-c quits" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("x"))])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1), script=[bytes([3])])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.step(), false)
}

///|
test "a resize settles before the screen is rebuilt" {
  let list = @widget.ListView::new(["a", "b", "c", "d"])
  let tree = @app.column(0, [@app.leaf(1, list)])
  let tty = @driver.Headless::new(@geom.Size::new(6, 2), script=[
    // CSI 48 ; rows ; columns t
    ascii("\u{1b}[48;4;6t"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen().length(), 2)
  // The report arrives on this step; the rebuild waits for the clock to move
  // past the settle time, which the next poll provides.
  ui.step() |> ignore
  ui.step() |> ignore
  assert_eq(ui.screen().length(), 4)
  assert_eq(ui.screen()[3], "d     ")
}

///|
test "starting and stopping hand the terminal over and back" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("hi"))])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  let opening = tty.output()
  // The alternate screen is entered before anything is drawn on it.
  assert_eq(opening[0:8].to_owned(), @driver.enter_alt)
  tty.clear_output()
  ui.stop()
  assert_eq(tty.is_running(), false)
  let closing = tty.output()
  assert_eq(closing[closing.length() - 8:].to_owned(), @driver.leave_alt)
}

///|
test "a frame with nothing to say writes nothing" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("hi"))])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.clear_output()
  ui.step() |> ignore
  ui.step() |> ignore
  // Nothing happened, so nothing was sent — which is the whole point of
  // comparing frames rather than repainting on a timer.
  assert_eq(tty.output(), "")
}

///|
test "typing into an input edits it through the whole stack" {
  let field = @widget.Input::new(placeholder="name")
  let tree = @app.column(0, [@app.leaf(1, field)])
  let tty = @driver.Headless::new(@geom.Size::new(8, 1), script=[
    ascii("hi"),
    ascii("\u{7f}"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.step() |> ignore
  assert_eq(field.text(), "hi")
  ui.step() |> ignore
  assert_eq(field.text(), "h")
  let reported = ui.drain()
  assert_eq(reported[reported.length() - 1], Changed(id=1, value="h"))
}
