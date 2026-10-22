// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn bytes(values : Array[Int32]) -> Bytes {
  let out : Array[Byte] = []
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
fn ascii(text : String) -> Bytes {
  let out : Array[Int32] = []
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
  ui.step() |> ignore
  assert_eq(ui.focused(), 1)
}

///|
test "focus starts on the first widget that is not disabled" {
  let tree = @app.column(0, [
    @app.leaf(1, @widget.Button::new("one")),
    @app.leaf(2, @widget.Button::new("two")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(8, 2))
  let ui = @app.App::new(tty, tree)
  ui.disable(1)
  ui.start()
  assert_eq(ui.focused(), 2)
  ui.push_screen(tree)
  assert_eq(ui.focused(), 2)
}

///|
test "tab passes over a node a rule hides" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["gone"]),
    @design.Styles::new(display=Hidden),
  )
  let tree = @app.column(0, [
    @app.leaf(1, @widget.Button::new("one")),
    @app.leaf(2, @widget.Button::new("two"), classes=["gone"]),
    @app.leaf(3, @widget.Button::new("three")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(8, 3), script=[bytes([0x09])])
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  ui.step() |> ignore
  assert_eq(ui.focused(), 3)
}

///|
test "what a widget reports reaches the host" {
  let button = @widget.Button::new("go")
  let tree = @app.column(0, [@app.leaf(1, button)])
  let tty = @driver.Headless::new(@geom.Size::new(8, 1), script=[ascii("\r")])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.drain(), [Focused(id=1)])
  ui.step() |> ignore
  assert_eq(ui.drain(), [Pressed(id=1)])
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
    ascii("\u{1b}[<0;1;3M"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.drain() |> ignore
  ui.step() |> ignore
  assert_eq(ui.focused(), 2)
  assert_eq(ui.drain(), [Blurred(id=1), Focused(id=2), Pressed(id=2)])
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
test "the quit key can be another key, or none" {
  let ctrl : @event.Mods = { ctrl: true, alt: false, shift: false, }
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("x"))])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1), script=[
    bytes([3]),
    bytes([0x11]),
  ])
  let ui = @app.App::new(
    tty,
    tree,
    quit=Some(@event.Key::with_mods(Char(113), ctrl)),
  )
  ui.start()
  assert_eq(ui.step(), true)
  assert_eq(ui.step(), false)
  let tty = @driver.Headless::new(@geom.Size::new(4, 1), script=[bytes([3])])
  let ui = @app.App::new(tty, tree, quit=None)
  ui.start()
  assert_eq(ui.step(), true)
}

///|
test "a resize settles before the screen is rebuilt" {
  let list = @widget.ListView::new(["a", "b", "c", "d"])
  let tree = @app.column(0, [@app.leaf(1, list)])
  let tty = @driver.Headless::new(@geom.Size::new(6, 2), script=[
    ascii("\u{1b}[48;4;6t"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen().length(), 2)
  ui.step() |> ignore
  ui.step() |> ignore
  assert_eq(ui.screen().length(), 4)
  assert_eq(ui.screen()[3], "d     ")
}

///|
test "a terminal that reports no resize is measured instead" {
  let list = @widget.ListView::new(["a", "b", "c", "d"])
  let tree = @app.column(0, [@app.leaf(1, list)])
  let tty = @driver.Headless::new(@geom.Size::new(6, 2))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.set_size(@geom.Size::new(6, 4))
  ui.step() |> ignore
  ui.step() |> ignore
  assert_eq(ui.screen().length(), 4)
}

///|
test "starting and stopping hand the terminal over and back" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("hi"))])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  let opening = tty.output()
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

///|
test "an inline border and padding frame the content" {
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Static::new("hi"),
      styles=@design.Styles::new(
        border=@design.Thin,
        padding=@geom.Spacing::all(1),
      ),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(8, 5))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), [
    "┌──────┐", "│      │", "│ hi   │", "│      │", "└──────┘",
  ])
}

///|
test "a class rule outweighs the name rule it beats" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Panel"),
    @design.Styles::new(border=@design.Ascii),
  )
  sheet.add(
    @design.Sel::new(classes=["fancy"]),
    @design.Styles::new(border=@design.Double),
  )
  let tree = @app.column(0, [
    @app.leaf(1, @widget.Static::new("x"), name="Panel", classes=["fancy"]),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(6, 3))
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), [
    "╔════╗", "║x   ║", "╚════╝",
  ])
}

///|
test "inline styles sit on top of the rules" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Panel"),
    @design.Styles::new(border=@design.Thin),
  )
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Static::new("x"),
      name="Panel",
      styles=@design.Styles::new(border=@design.Round),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(6, 3))
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), [
    "╭────╮", "│x   │", "╰────╯",
  ])
}

///|
test "a hidden node and its slot are gone" {
  let tree = @app.row(0, [
    @app.leaf(
      1,
      @widget.Static::new("a"),
      styles=@design.Styles::new(display=@design.Hidden),
    ),
    @app.leaf(2, @widget.Static::new("b")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["b   "])
}

///|
test "a rule can hide a node it matches" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["gone"]),
    @design.Styles::new(display=@design.Hidden),
  )
  let tree = @app.row(0, [
    @app.leaf(1, @widget.Static::new("a"), classes=["gone"]),
    @app.leaf(2, @widget.Static::new("b")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1))
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), ["b   "])
}

///|
test "margin keeps space the node does not draw in" {
  let tree = @app.row(0, [
    @app.leaf(
      1,
      @widget.Static::new("ab"),
      styles=@design.Styles::new(margin=@geom.Spacing::horizontal(1)),
    ),
    @app.leaf(2, @widget.Static::new("cd")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(8, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), [" ab cd  "])
}

///|
test "a focus rule restyles the widget focus moves onto" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(focus=true),
    @design.Styles::new(border=@design.Heavy),
  )
  sheet.add(
    @design.Sel::new(name="Edge"),
    @design.Styles::new(border=@design.Thin),
  )
  let tree = @app.row(0, [
    @app.leaf(
      1,
      @widget.Button::new("go"),
      box=@layout.Box::new(extent=Frac(1)),
      name="Edge",
    ),
    @app.leaf(
      2,
      @widget.Button::new("ok"),
      box=@layout.Box::new(extent=Frac(1)),
      name="Edge",
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(14, 3), script=[ascii("\t")])
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), [
    "┏━━━━━┓┌─────┐", "┃ go  ┃│ ok  │", "┗━━━━━┛└─────┘",
  ])
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "┌─────┐┏━━━━━┓", "│ go  │┃ ok  ┃", "└─────┘┗━━━━━┛",
  ])
}

///|
test "alignment puts a short block where the style says" {
  let tree = @app.column(
    0,
    [@app.leaf(1, @widget.Button::new("go"))],
    styles=@design.Styles::new(align=@design.Align::new(v=@design.Middle)),
  )
  let tty = @driver.Headless::new(@geom.Size::new(6, 5))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["      ", "      ", "  go  ", "      ", "      "])
}

///|
test "a container's background is placed behind its children" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Panel"),
    @design.Styles::new(text=@style.Style::new(bg=@style.blue)),
  )
  let tree = @app.column(
    0,
    [@app.leaf(1, @widget.Static::new("hi"))],
    name="Panel",
  )
  let tty = @driver.Headless::new(@geom.Size::new(8, 3))
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), ["hi      ", "        ", "        "])
  assert_eq(tty.output().contains("\u{1b}[44m"), true)
}

///|
test "a plain wire takes whole frames with no control sequences" {
  let label = @widget.Static::new("hi")
  let tree = @app.column(0, [@app.leaf(1, label)])
  let tty = @driver.Headless::new(@geom.Size::new(4, 2))
  let ui = @app.App::new(tty, tree, plain=true)
  ui.start()
  let written = tty.output()
  assert_eq(written, "hi  \r\n    \r\n")
  assert_eq(written.contains("\u{1b}"), false)
  assert_eq(ui.screen(), ["hi  ", "    "])
  ui.stop()
}
