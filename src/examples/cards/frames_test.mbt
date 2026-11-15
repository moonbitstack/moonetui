// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
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
fn interop_wanted() -> Bool {
  match @env.get_env_var("MOONETUI_INTEROP") {
    Some(_) => true
    None => false
  }
}

///|
fn announce(
  name : String,
  size : @geom.Size,
  stream : String,
  rows : Array[String],
) -> Unit {
  if !interop_wanted() {
    return
  }
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
fn shot(
  ui : @app.App[@driver.Headless],
  driver : @driver.Headless,
  total : StringBuilder,
  name : String,
  size : @geom.Size,
) -> Unit raise {
  driver.clear_output()
  ui.refresh()
  ignore(ui.step())
  total.write_string(driver.output())
  announce(name, size, total.to_string(), ui.screen())
}

///|
test "a deal, a lift, a drop, and the last card going home" {
  let size = @geom.Size::new(80, 24)
  let screen = @cards.Screen::new()
  let table = screen.table
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@cards.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("cards/00 title", size, total.to_string(), ui.screen())
  assert_true(table.phase() == @cards.Title)
  // A deal: one card to the first column and one more to each after it, the
  // last of every column turned up, twenty-four left in the stock.
  table.deal()
  assert_true(table.phase() == @cards.Playing)
  let mut dealt = 0
  let mut turned = 0
  for column in 0..<7 {
    let pile = table.pile(column)
    assert_eq(pile.length(), column + 1)
    dealt = dealt + pile.length()
    for card in pile {
      if card.up {
        turned = turned + 1
      }
    }
  }
  assert_eq(dealt, 28)
  assert_eq(turned, 7)
  assert_eq(table.pile(7).length(), 24)
  shot(ui, driver, total, "cards/01 dealt", size)
  // A draw takes the top of the stock and turns it up on the waste.
  table.draw()
  assert_eq(table.pile(7).length(), 23)
  assert_eq(table.pile(8).length(), 1)
  shot(ui, driver, total, "cards/02 drawn", size)
  // A set piece: a red three alone in the first column, a black four in the
  // second, and a king's worth of face-down cards under nothing.
  table.piles[0] = [@cards.Card::new(3, 1, true)]
  table.piles[1] = [@cards.Card::new(4, 0, true)]
  table.piles[2] = []
  table.jump(0)
  table.grab()
  assert_true(table.holding())
  table.aim(1)
  assert_true(table.accepts(1, @cards.Card::new(3, 1, true)))
  shot(ui, driver, total, "cards/03 held", size)
  table.place()
  assert_false(table.holding())
  assert_eq(table.pile(0).length(), 0)
  assert_eq(table.pile(1).length(), 2)
  shot(ui, driver, total, "cards/04 placed", size)
  // The move is one step, and `u` takes it back.
  table.undo()
  assert_eq(table.pile(0).length(), 1)
  assert_eq(table.pile(1).length(), 1)
  shot(ui, driver, total, "cards/05 undone", size)
  // Twelve cards home in every suit and a king left on the table: `f` sends it
  // home and the table is clear.
  for suit in 0..<4 {
    let pile : Array[@cards.Card] = []
    for rank in 1..<=12 {
      pile.push(@cards.Card::new(rank, suit, true))
    }
    table.found[suit] = pile
  }
  for suit in 0..<4 {
    table.piles[suit] = [@cards.Card::new(13, suit, true)]
  }
  for suit in 0..<4 {
    table.jump(suit)
    table.home()
  }
  assert_eq(table.home_count(), 52)
  assert_true(table.phase() == @cards.Won)
  shot(ui, driver, total, "cards/06 clear", size)
  table.undo()
  assert_true(table.phase() == @cards.Playing)
}
