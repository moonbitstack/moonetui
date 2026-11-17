// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The rows a frame addressed, read back out of the escape stream: the row of
/// every `CSI row ; col H`. Colour sequences end in `m` and are passed over.
fn rows_written(text : String) -> Array[Int32] {
  let rows : Array[Int32] = []
  let last = text.length()
  let mut i = 0
  while i + 1 < last {
    if text[i] != '\u{1b}' || text[i + 1] != '[' {
      i = i + 1
      continue
    }
    let mut j = i + 2
    let mut row = 0
    let mut colons = 0
    while j < last {
      let code = text[j].to_int()
      if code >= 48 && code <= 57 {
        if colons == 0 {
          row = row * 10 + (code - 48)
        }
      } else if code == 59 {
        colons = colons + 1
      } else {
        break
      }
      j = j + 1
    }
    if j < last && text[j] == 'H' && colons > 0 {
      rows.push(row - 1)
    }
    i = j
  }
  rows
}

///|
test "a key that moves a list's cursor redraws that list and nothing else" {
  let list = @widget.ListView::new(["one", "two", "three"])
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Header::new("moonetui"),
      box=@layout.Box::new(extent=Cells(1)),
    ),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(
      3,
      @widget.Footer::new([("q", "quit")]),
      box=@layout.Box::new(extent=Cells(1)),
    ),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(12, 5))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.clear_output()
  tty.push(ascii("\u{1b}[B"))
  ui.step() |> ignore
  assert_eq(list.index(), 1)
  let rows = rows_written(tty.output())
  assert_eq(rows, [1, 2])
  assert_eq(ui.screen(), [
    "  moonetui  ", "one         ", "two         ", "three       ", " q quit     ",
  ])
}

///|
test "a partial frame draws what a whole frame would" {
  let list = @widget.ListView::new(["alpha", "beta", "gamma"])
  let tree = @app.column(0, [
    @app.leaf(
      1,
      @widget.Static::new("a note"),
      box=@layout.Box::new(extent=Cells(1)),
    ),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(10, 4))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.push(ascii("\u{1b}[B"))
  ui.step() |> ignore
  let partial = ui.screen()
  // The same step drawn whole: the screen has to agree row for row.
  ui.refresh()
  ui.step() |> ignore
  assert_eq(ui.screen(), partial)
  assert_eq(partial, ["a note    ", "alpha     ", "beta      ", "gamma     "])
}

///|
test "a frame with nothing damaged writes nothing" {
  let tree = @app.column(0, [@app.leaf(1, @widget.Static::new("still"))])
  let tty = @driver.Headless::new(@geom.Size::new(8, 2))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.clear_output()
  ui.step() |> ignore
  ui.step() |> ignore
  assert_eq(tty.output(), "")
}

///|
test "repainting a node after a host change writes that node's rows" {
  let left = @widget.Static::new("left")
  let right = @widget.Static::new("right")
  let tree = @app.row(0, [
    @app.leaf(1, left, box=@layout.Box::new(extent=Frac(1))),
    @app.leaf(2, right, box=@layout.Box::new(extent=Frac(1))),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(10, 1))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.clear_output()
  left.set("LEFT")
  ui.repaint(1)
  ui.step() |> ignore
  // Both nodes sit on the one row, so that row is composed again: the frame
  // writes a row rather than nothing.
  assert_eq(rows_written(tty.output()), [0])
  assert_eq(ui.screen(), ["LEFT right"])
}

///|
test "damage that covers the screen composes it whole" {
  let tree = @app.column(0, [
    @app.leaf(1, @widget.Static::new("one")),
    @app.leaf(2, @widget.Static::new("two")),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(6, 2))
  let ui = @app.App::new(tty, tree)
  ui.start()
  tty.clear_output()
  ui.repaint_region(@geom.Region::new(0, 0, 6, 2))
  ui.step() |> ignore
  assert_eq(ui.screen(), ["one   ", "two   "])
}

///|
test "a hidden row is drawn again when the thing above it goes" {
  let list = @widget.ListView::new(["a", "b", "c"])
  let before = @app.column(0, [
    @app.leaf(
      9,
      @widget.Static::new("note"),
      box=@layout.Box::new(extent=Cells(1)),
    ),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
  ])
  let after = @app.column(0, [
    @app.leaf(
      9,
      @widget.Static::new("note"),
      box=@layout.Box::new(extent=Cells(1)),
      styles=@design.Styles::new(display=@design.Hidden),
    ),
    @app.leaf(2, list, box=@layout.Box::new(extent=Frac(1))),
  ])
  let tty = @driver.Headless::new(@geom.Size::new(6, 4))
  let ui = @app.App::new(tty, before)
  ui.start()
  assert_eq(ui.screen(), ["note  ", "a     ", "b     ", "c     "])
  ui.swap_root(after)
  ui.step() |> ignore
  assert_eq(ui.screen(), ["a     ", "b     ", "c     ", "      "])
}
