// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The bytes of a press at `x`, `y`, in the mouse protocol the parser reads.
fn click(x : Int32, y : Int32) -> Bytes {
  ascii("\u001b[<0;" + x.to_string() + ";" + y.to_string() + "M")
}

///|
/// The bytes of the down arrow, which every list answers to.
fn down() -> Bytes {
  ascii("\u001b[B")
}

///|
/// Run `script` through a one-node application and answer with its screen and
/// everything its widgets reported.
fn drive(
  widget : &@widget.Widget,
  size : @geom.Size,
  script : Array[Bytes],
) -> (String, Array[@widget.Out]) raise {
  let tty = @driver.Headless::new(size, script~, tick=16)
  let ui = @app.App::new(tty, @app.leaf(1, widget))
  ui.start()
  let reported : Array[@widget.Out] = []
  for _ in script {
    ignore(ui.step())
    for out in ui.drain() {
      reported.push(out)
    }
  }
  // One more step with nothing to read: the parser lets go of a key it was
  // holding to see whether an escape sequence was coming.
  ignore(ui.step())
  for out in ui.drain() {
    reported.push(out)
  }
  ui.refresh()
  ignore(ui.step())
  (ui.screen().join("\n"), reported)
}

///|
fn asked(reported : Array[@widget.Out], wanted : @widget.Out) -> Bool {
  reported
  .filter(out => {
    match (out, wanted) {
      (Selected(..), Selected(..)) => true
      (Dismissed(..), Dismissed(..)) => true
      (Changed(..), Changed(..)) => true
      (Pressed(..), Pressed(..)) => true
      (MenuPicked(..), MenuPicked(..)) => true
      (Scrolled(..), Scrolled(..)) => true
      _ => false
    }
  })
  .length() >
  0
}

///|
test "a message box answers under the driver, by key and by click" {
  let box = @widget.MessageBox::new(
    title="Quit",
    message="Discard unsaved work?",
    buttons=@widget.ok_cancel,
  )
  let (screen, _) = drive(box, @geom.Size::new(40, 6), [ascii("\r")])
  assert_eq(screen.contains("Quit"), true)
  assert_eq(screen.contains("Discard unsaved work?"), true)
  assert_eq(screen.contains("Cancel"), true)
  let (_, reported) = drive(box, @geom.Size::new(40, 6), [
    ascii("\r"),
    click(18, 5),
  ])
  assert_eq(asked(reported, Selected(id=0, index=0)), true)
  assert_eq(asked(reported, Dismissed(id=0)), true)
}

///|
test "an input box takes typing and a click under the driver" {
  let box = @widget.InputBox::new(prompt="Name", value="moon")
  let (screen, reported) = drive(box, @geom.Size::new(40, 5), [
    ascii("i"),
    click(14, 4),
  ])
  assert_eq(screen.contains("Name"), true)
  assert_eq(box.text(), "mooni")
  assert_eq(asked(reported, Changed(id=0, value="")), true)
  assert_eq(asked(reported, Selected(id=0, index=0)), true)
}

///|
test "a file dialog walks its listing under the driver" {
  let dialog = @widget.FileDialog::new(path="/src", entries=[
    @widget.FileEntry::new("src", dir=true),
    @widget.FileEntry::new("widget.mbt", size=4820),
  ])
  let (screen, reported) = drive(dialog, @geom.Size::new(40, 8), [
    down(),
    ascii("\r"),
  ])
  assert_eq(screen.contains("/src"), true)
  assert_eq(screen.contains("widget.mbt"), true)
  assert_eq(asked(reported, Selected(id=0, index=0)), true)
  assert_eq(dialog.name(), "widget.mbt")
}

///|
test "a menu bar takes an item by key and by click under the driver" {
  let bar = @widget.MenuBar::new()
  bar.add("File", [@widget.Item::new("New"), @widget.Item::new("Quit")])
  let (screen, reported) = drive(bar, @geom.Size::new(40, 6), [
    down(),
    ascii("\r"),
  ])
  assert_eq(screen.contains("File"), true)
  assert_eq(asked(reported, MenuPicked(id=0, menu=0, index=0)), true)
  let other = @widget.MenuBar::new()
  other.add("File", [@widget.Item::new("New"), @widget.Item::new("Quit")])
  let (_, clicked) = drive(other, @geom.Size::new(40, 6), [down(), click(3, 3)])
  assert_eq(asked(clicked, MenuPicked(id=0, menu=0, index=0)), true)
}

///|
test "a command palette narrows and runs under the driver" {
  let palette = @widget.CommandPalette::new()
  palette.add("Open file")
  palette.add("Quit")
  let (screen, reported) = drive(palette, @geom.Size::new(40, 8), [
    ascii("q"),
    ascii("\r"),
  ])
  assert_eq(screen.contains("Quit"), true)
  assert_eq(palette.query(), "q")
  assert_eq(asked(reported, Selected(id=0, index=0)), true)
}

///|
test "a chart, a bar chart, a gauge and a scrollbar draw under the driver" {
  let plot = @widget.Chart::new(datasets=[
    @widget.Dataset::new("a", [(0.0, 1.0), (1.0, 3.0)]),
  ])
  let (screen, _) = drive(plot, @geom.Size::new(30, 8), [])
  assert_eq(screen.trim() != "", true)
  let bars = @widget.BarChart::new(bars=[@widget.Bar::new("a", value=2.0)])
  let (screen, _) = drive(bars, @geom.Size::new(20, 5), [])
  assert_eq(screen.contains("a"), true)
  let gauge = @widget.Gauge::new(ratio=0.5, label="load")
  let (screen, _) = drive(gauge, @geom.Size::new(20, 1), [])
  assert_eq(screen.contains("50%"), true)
  let bar = @widget.Scrollbar::new(content=20, viewport=10)
  let (screen, reported) = drive(bar, @geom.Size::new(1, 10), [
    down(),
    click(1, 9),
  ])
  assert_eq(screen.contains("█"), true)
  assert_eq(asked(reported, Scrolled(id=0, x=0, y=0)), true)
}

///|
test "a block, a switcher, a pretty and a mask draw under the driver" {
  let block : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("inside"),
    title="Box",
  )
  let (screen, _) = drive(block, @geom.Size::new(20, 4), [])
  assert_eq(screen.contains("Box"), true)
  assert_eq(screen.contains("inside"), true)
  let switcher : &@widget.Widget = @widget.ContentSwitcher::new(children=[
    @widget.Static::new("first"),
  ])
  let (screen, _) = drive(switcher, @geom.Size::new(20, 1), [])
  assert_eq(screen.contains("first"), true)
  let pretty : &@widget.Widget = @widget.Pretty::new(
    value=VObj([("a", VInt(1))]),
  )
  let (screen, _) = drive(pretty, @geom.Size::new(20, 3), [])
  assert_eq(screen.contains("a: 1"), true)
  let mask : &@widget.Widget = @widget.MaskedInput::new("##-##")
  let (screen, _) = drive(mask, @geom.Size::new(20, 1), [ascii("1")])
  assert_eq(screen.contains("1_-__"), true)
}

///|
test "a link and a clock answer under the driver" {
  let link : &@widget.Widget = @widget.Link::new("docs")
  let (screen, reported) = drive(link, @geom.Size::new(20, 1), [
    ascii("\r"),
    click(1, 1),
  ])
  assert_eq(screen.contains("docs"), true)
  assert_eq(asked(reported, Pressed(id=0)), true)
  let head : &@widget.Widget = @widget.Header::new(
    "moonetui",
    clock=Some(@widget.Clock::new(hour=1, minute=2, second=3)),
  )
  let (screen, _) = drive(head, @geom.Size::new(20, 1), [])
  assert_eq(screen.contains("01:02:03"), true)
}

///|
test "a stateful list and table are driven from the state the caller holds" {
  let state = @widget.ListState::new()
  let list : &@widget.Widget = @widget.StatefulList::new(
    items=["a", "b", "c"],
    state~,
  )
  let (screen, _) = drive(list, @geom.Size::new(10, 3), [down()])
  assert_eq(screen.contains("b"), true)
  assert_eq(state.selected(), 0)
  let table_state = @widget.TableState::new()
  let table : &@widget.Widget = @widget.StatefulTable::new(
    header=["one"],
    rows=[["x"], ["y"]],
    state=table_state,
  )
  let (screen, _) = drive(table, @geom.Size::new(10, 3), [down(), click(2, 3)])
  assert_eq(screen.contains("one"), true)
  assert_eq(table_state.row(), 1, msg="the click chose the second row")
}
