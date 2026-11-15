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
/// Announces one frame of the demo: its name, the emulators that can model it,
/// the bytes written since the demo started, and the rows it is meant to show.
/// `scripts/verify_terminals.py` replays those bytes in two terminal emulators
/// this repository has no part in; what they show has to be these rows.
fn announce(
  name : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  let line = StringBuilder()
  line.write_string(
    "interop\t" +
    name +
    "\tpyte,tmux\t" +
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
/// One key of the demo's script, and what the demo must show once it has
/// answered: the widget with the keyboard, the list's row, the bar's percent,
/// the field's text, and whether the loop is still alive.
struct Step {
  name : String
  key : String
  focus : Int32
  index : Int32
  percent : Int32
  text : String
  alive : Bool
}

///|
/// The demo's keys, in the order a reader presses them: tab reaches the list,
/// two downs pick the third row, enter copies it into the field and moves the
/// bar on, tab reaches the field, a character goes in at its cursor, and
/// ctrl-c stops the loop.
fn steps() -> Array[Step] {
  [
    {
      name: "tui/01 tab",
      key: "\t",
      focus: 10,
      index: 0,
      percent: 35,
      text: "",
      alive: true,
    },
    {
      name: "tui/02 down",
      key: "\u{1b}[B",
      focus: 10,
      index: 1,
      percent: 35,
      text: "",
      alive: true,
    },
    {
      name: "tui/03 down again",
      key: "\u{1b}[B",
      focus: 10,
      index: 2,
      percent: 35,
      text: "",
      alive: true,
    },
    {
      name: "tui/04 enter",
      key: "\r",
      focus: 10,
      index: 2,
      percent: 45,
      text: "gamma",
      alive: true,
    },
    {
      name: "tui/05 tab again",
      key: "\t",
      focus: 3,
      index: 2,
      percent: 45,
      text: "gamma",
      alive: true,
    },
    {
      name: "tui/06 typed",
      key: "!",
      focus: 3,
      index: 2,
      percent: 45,
      text: "gamma!",
      alive: true,
    },
    {
      name: "tui/07 ctrl-c",
      key: "\u{3}",
      focus: 3,
      index: 2,
      percent: 45,
      text: "gamma!",
      alive: false,
    },
  ]
}

///|
test "the demo answers keys, frame by frame" {
  let size = @geom.Size::new(80, 24)
  let demo = @demo.Demo::new()
  // One chunk per key and an empty one after it: a key's frame is drawn on the
  // step after its handler has answered, which is what a reader sees.
  let script : Array[Bytes] = []
  let plan = steps()
  for step in plan {
    script.push(@utf8.encode(step.key))
    script.push(b"")
  }
  let driver = @driver.Headless::new(size, script~, tick=16)
  let ui = @app.App::new(driver, demo.root, sheet=@demo.sheet())
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("tui/00 open", size, total.to_string(), ui.screen())
  assert_eq(ui.focused(), 6)
  assert_eq(demo.list.index(), 0)
  let mut alive = true
  for step in plan {
    driver.clear_output()
    ignore(ui.step())
    let reports = ui.drain()
    demo.answer(reports)
    if reports.length() > 0 {
      ui.refresh()
    }
    alive = ui.step()
    total.write_string(driver.output())
    // Every frame is announced with the rows the demo means to show, so two
    // terminal emulators can be asked what the same bytes show.
    announce(step.name, size, total.to_string(), ui.screen())
    assert_eq(ui.focused(), step.focus)
    assert_eq(demo.list.index(), step.index)
    assert_eq(demo.bar.percent(), step.percent)
    assert_eq(demo.field.text(), step.text)
    assert_eq(alive, step.alive)
  }
  assert_false(alive)
}
