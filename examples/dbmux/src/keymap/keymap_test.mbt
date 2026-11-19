// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the defaults bind the keys the footer shows" {
  let keys = @keymap.Keymap::default()
  assert_eq(keys.action("C-s"), Some(@keymap.Action::Save))
  assert_eq(keys.action("j"), Some(@keymap.Action::Down))
  assert_eq(keys.action("?"), Some(@keymap.Action::Help))
  assert_eq(keys.action("z"), None)
}

///|
test "a key becomes the text the keymap file spells" {
  let key = @event.Key::with_mods(@event.KeyCode::Char(115), @event.none)
  assert_eq(@keymap.key_text(key), "s")
  let ctrl : @event.Mods = { ctrl: true, alt: false, shift: false, }
  assert_eq(
    @keymap.key_text({ code: @event.KeyCode::Char(115), mods: ctrl, }),
    "C-s",
  )
  assert_eq(
    @keymap.key_text({ code: @event.KeyCode::Escape, mods: @event.none, }),
    "esc",
  )
}

///|
test "a keymap file rebinds and takes the old key away" {
  let keys = @keymap.Keymap::default()
  let rebound = keys.over(
    (
      #|[keys]
      #|save = "C-w"
    ),
  )
  assert_eq(rebound.action("C-w"), Some(@keymap.Action::Save))
  assert_eq(rebound.action("C-s"), None)
}

///|
test "a name no action has is refused, not ignored" {
  let keys = @keymap.Keymap::default()
  let message = try {
    ignore(
      keys.over(
        (
          #|[keys]
          #|sav = "C-w"
        ),
      ),
    )
    "loaded"
  } catch {
    @config.Refused(text~) => text
  }
  assert_eq(message, "no action is called sav")
}

///|
test "the rows list is sorted and names every binding" {
  let rows = @keymap.Keymap::default().rows()
  assert_eq(rows.length() > 10, true)
  assert_eq(rows[0].0, "?")
}

///|
test "every action has a name and can be parsed back" {
  let actions : Array[@keymap.Action] = [
    @keymap.Action::Quit,
    @keymap.Action::Save,
    @keymap.Action::FilterCell,
    @keymap.Action::ExportJson,
  ]
  for action in actions {
    assert_eq(@keymap.Action::parse(action.name()), Some(action))
  }
}

///|
test "a keymap file sets the editor's carets, and names the one it does not know" {
  let keymap = @keymap.Keymap::default().over(
    "[caret]\nnormal = \"underline\"\nblink = false\n",
  )
  assert_eq(keymap.caret_normal, @widget.Underline(blink=false))
  assert_eq(keymap.caret_insert, @widget.Bar(blink=false))
  let kept = @keymap.Keymap::default().over("[keys]\nsave = \"C-w\"\n")
  assert_eq(kept.caret_normal, @widget.Block(blink=true))
  let refused = try
    @keymap.Keymap::default().over("[caret]\ninsert = \"beam\"\n")
  catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(refused)
}
