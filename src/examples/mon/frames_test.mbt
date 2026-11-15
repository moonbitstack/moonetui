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
test "a walk into the grass, two strikes, and a creature caught" {
  let size = @geom.Size::new(80, 22)
  let screen = @mon.Screen::new()
  let field = screen.field
  let driver = @driver.Headless::new(size, tick=16)
  let ui = @app.App::new(driver, screen.root, sheet=@mon.sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(driver.output())
  driver.clear_output()
  announce("mon/00 route", size, total.to_string(), ui.screen())
  assert_true(field.mode == @mon.Walk)
  assert_eq(field.x, 3)
  assert_eq(field.y, 4)
  // Two steps north put the party in the tall grass of the second band, and
  // the fourth step into it brings something out.
  field.walk(0, -1)
  assert_eq(field.steps, 1)
  field.walk(0, -1)
  assert_eq(field.steps, 2)
  field.walk(1, 0)
  assert_eq(field.steps, 3)
  field.walk(1, 0)
  assert_eq(field.steps, 4)
  assert_true(field.mode == @mon.Fight)
  assert_true(field.enemy.length() > 0)
  shot(ui, driver, total, "mon/01 wild", size)
  // Two strikes and the wild one is down; the party's creature has taken a hit.
  let was = field.lead_beast().hp
  field.strike()
  assert_true(field.lead_beast().hp < was)
  shot(ui, driver, total, "mon/02 struck", size)
  let mut turns = 0
  while field.mode == @mon.Fight && turns < 12 {
    field.strike()
    turns = turns + 1
  }
  assert_true(field.mode == @mon.Won)
  assert_eq(field.caught, 7)
  shot(ui, driver, total, "mon/03 caught", size)
  // Space puts the grass back, and a potion heals the one in front.
  field.rest()
  assert_true(field.mode == @mon.Walk)
  let before = field.lead_beast().hp
  field.heal()
  assert_true(field.lead_beast().hp >= before)
  shot(ui, driver, total, "mon/04 healed", size)
}
