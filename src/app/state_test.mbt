// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a hover rule restyles the node under the pointer" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Hot"),
    @design.Styles::new(border=@design.Thin),
  )
  sheet.add(
    @design.Sel::new(name="Hot", hover=true),
    @design.Styles::new(border=@design.Heavy),
  )
  let tree = @app.row(0, [
    @app.leaf(
      1,
      @widget.Static::new("a"),
      name="Hot",
      box=@layout.Box::new(extent=Cells(3)),
    ),
    @app.leaf(
      2,
      @widget.Static::new("b"),
      box=@layout.Box::new(extent=Cells(3)),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(6, 3), script=[
    ascii("\u{1b}[<35;1;1M"),
    ascii("\u{1b}[<35;5;1M"),
  ])
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  assert_eq(ui.screen(), ["┌─┐b  ", "│a│   ", "└─┘   "])
  // A motion with no button over the first cell.
  ui.step() |> ignore
  assert_eq(ui.hovering(), 1)
  assert_eq(ui.screen(), ["┏━┓b  ", "┃a┃   ", "┗━┛   "])
  ui.step() |> ignore
  assert_eq(ui.hovering(), 2)
  assert_eq(ui.screen(), ["┌─┐b  ", "│a│   ", "└─┘   "])
}

///|
test "a disabled node is restyled, skipped and takes no input" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(name="Go"),
    @design.Styles::new(border=@design.Thin),
  )
  sheet.add(
    @design.Sel::new(name="Go", disabled=true),
    @design.Styles::new(border=@design.Ascii),
  )
  let tree = @app.row(0, [
    @app.leaf(
      1,
      @widget.Button::new("one"),
      name="Go",
      box=@layout.Box::new(extent=Frac(1)),
    ),
    @app.leaf(
      2,
      @widget.Button::new("two"),
      box=@layout.Box::new(extent=Frac(1)),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(14, 3), script=[
    ascii("\u{1b}[Z"),
    ascii("\t"),
    ascii("\u{1b}[<0;2;2M"),
  ])
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  ui.drain() |> ignore
  assert_eq(ui.focused(), 1)
  ui.disable(1)
  assert_eq(ui.is_disabled(1), true)
  // The ring moved on, and the disabled rule drew the ascii border.
  assert_eq(ui.focused(), 2)
  ui.step() |> ignore
  assert_eq(ui.screen(), ["+-----+  two  ", "| one |       ", "+-----+       "])
  // Tab walks around the disabled node, never onto it.
  ui.step() |> ignore
  assert_eq(ui.focused(), 2)
  ui.step() |> ignore
  assert_eq(ui.focused(), 2)
  // The click lands nowhere: the disabled widget declines it, and the only
  // messages are from the focus the disable moved along.
  ui.step() |> ignore
  assert_eq(ui.drain(), [Blurred(id=1), Focused(id=2)])
  ui.enable(1)
  assert_eq(ui.is_disabled(1), false)
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "┌─────┐  two  ", "│ one │       ", "└─────┘       ",
  ])
}

///|
test "an offset moves a node without telling the layout" {
  let tree = @app.row(0, [
    @app.leaf(
      1,
      @widget.Static::new("aa"),
      box=@layout.Box::new(extent=Frac(1)),
    ),
    @app.leaf(
      2,
      @widget.Static::new("bb"),
      box=@layout.Box::new(extent=Frac(1)),
      styles=@design.Styles::new(offset_x=2, offset_y=1),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(8, 3))
  let ui = @app.App::new(tty, tree)
  ui.start()
  assert_eq(ui.screen(), ["aa      ", "      bb", "        "])
}

///|
test "a stylesheet rule restyles the scroll bars" {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(
      scrollbar=@style.Style::new(reverse=false, fg=@style.red),
    ),
  )
  let kids : Array[@app.Node] = []
  for i in 0..<10 {
    kids.push(
      @app.leaf(10 + i, @widget.Static::new("row " + (i + 1).to_string())),
    )
  }
  let tree = @app.scroll(
    1,
    @app.column(2, kids),
    bar=@style.Style::new(reverse=true),
  )
  let tty = @driver.Headless::new(@geom.Size::new(10, 4))
  let ui = @app.App::new(tty, tree, sheet~)
  ui.start()
  // The rule replaced the pane's own reverse-video bar with red letters.
  assert_eq(tty.output().contains("\u{1b}[31m"), true)
  assert_eq(tty.output().contains("\u{1b}[7m"), false)
}

///|
test "a transition glides a node to its new place" {
  let moved = @app.leaf(
    1,
    @widget.Static::new("x"),
    styles=@design.Styles::new(transition=160),
  )
  let before = @app.column(0, [
    @app.leaf(9, @widget.Static::new("")),
    @app.leaf(
      10,
      @widget.Static::new(""),
      styles=@design.Styles::new(display=@design.Block),
    ),
    moved,
  ])
  let after = @app.column(0, [
    @app.leaf(9, @widget.Static::new("")),
    @app.leaf(
      10,
      @widget.Static::new(""),
      styles=@design.Styles::new(display=@design.Hidden),
    ),
    moved,
  ])
  let tty = @driver.Headless::new(@geom.Size::new(4, 4))
  let ui = @app.App::new(tty, before)
  ui.start()
  assert_eq(ui.screen(), ["    ", "    ", "x   ", "    "])
  ui.swap_root(after)
  // Sixteen milliseconds in: the glide is at its start, so row 2 still shows.
  ui.step() |> ignore
  assert_eq(ui.screen()[2], "x   ")
  // Long after: the glide is over and the frame is still.
  for _ in 0..<14 {
    ui.step() |> ignore
  }
  assert_eq(ui.screen(), ["    ", "x   ", "    ", "    "])
  ui.step() |> ignore
  assert_eq(ui.dirty, false)
}

///|
test "a timer fires on the driver's clock" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("x"))])
  let tty = @driver.Headless::new(@geom.Size::new(4, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  let hits : Array[Int32] = []
  ui.after(32, () => hits.push(1))
  ui.every(16, () => hits.push(2))
  for _ in 0..<5 {
    ui.step() |> ignore
  }
  // Five steps of sixteen milliseconds: the one-shot fired once, the
  // repeating one every step.
  let mut once = 0
  let mut many = 0
  for hit in hits {
    if hit == 1 {
      once = once + 1
    } else {
      many = many + 1
    }
  }
  assert_eq(once, 1)
  assert_eq(many >= 4, true)
}

///|
test "screens stack and come back" {
  let first = @app.column(0, [@app.leaf(1, @widget.Button::new("one"))])
  let second = @app.column(0, [@app.leaf(2, @widget.Button::new("two"))])
  let tty = @driver.Headless::new(@geom.Size::new(6, 1))
  let ui = @app.App::new(tty, first)
  ui.start()
  ui.drain() |> ignore
  assert_eq(ui.screen_depth(), 1)
  ui.push_screen(second)
  assert_eq(ui.screen_depth(), 2)
  ui.step() |> ignore
  assert_eq(ui.screen(), [" two  "])
  assert_eq(ui.focused(), 2)
  ui.pop_screen()
  assert_eq(ui.screen_depth(), 1)
  ui.step() |> ignore
  assert_eq(ui.screen(), [" one  "])
  assert_eq(ui.focused(), 1)
}

///|
test "a submitted input reports its value" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Input::new(placeholder="p"))])
  let tty = @driver.Headless::new(@geom.Size::new(10, 1), script=[
    ascii("hi"),
    ascii("\r"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.drain() |> ignore
  ui.step() |> ignore
  ui.drain() |> ignore
  ui.step() |> ignore
  let mut submitted : @widget.Out? = None
  for out in ui.drain() {
    match out {
      Submitted(..) => submitted = Some(out)
      _ => ()
    }
  }
  assert_eq(submitted, Some(Submitted(id=1, value="hi")))
}

///|
test "scrolling reports where the window sits" {
  let kids : Array[@app.Node] = []
  for i in 0..<10 {
    kids.push(@app.leaf(10 + i, @widget.Static::new("row")))
  }
  let tree = @app.scroll(1, @app.column(2, kids))
  let tty = @driver.Headless::new(@geom.Size::new(10, 4), script=[
    ascii("\u{1b}[<65;1;1M"),
  ])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.drain() |> ignore
  ui.step() |> ignore
  assert_eq(ui.drain(), [Scrolled(id=1, x=0, y=3)])
}

///|
test "a handler claims a message before the app acts" {
  let tree = @app.column(0, [
    @app.leaf(1, @widget.Button::new("go")),
    @app.leaf(2, @widget.Button::new("ok")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(8, 4), script=[ascii("\r")])
  let ui = @app.App::new(tty, tree)
  ui.start()
  ui.drain() |> ignore
  let seen : Array[Int32] = []
  ui.on(fn(out) {
    match out {
      Pressed(id~) => {
        seen.push(id)
        true
      }
      _ => false
    }
  })
  ui.step() |> ignore
  assert_eq(seen, [1])
  // Claimed: nothing reaches the drain.
  assert_eq(ui.drain().length(), 0)
  // A posted message arrives like a widget's own.
  ui.post(Selected(id=0, index=7))
  assert_eq(ui.drain(), [Selected(id=0, index=7)])
}
