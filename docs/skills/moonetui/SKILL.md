---
name: moonetui
description: "Terminal interfaces for MoonBit: a cell buffer with a differential renderer, a stylesheet over name, class and state, and the widgets a full-screen program is made of — lists, tables, trees, forms, dialogs, menus, charts and meters. Use when a MoonBit program needs a terminal interface, a widget drawn into a frame, or the escape sequences a terminal is written with."
---

# moonetui

A screen is a tree of widgets, a stylesheet and a driver. One `step()` polls,
parses, dispatches, lays out, composes, diffs and writes; nothing waits in the
background, so the same source runs on wasm, wasm-gc, js and native.

```bash
moon add moonbitstack/moonetui
```

```
import {
  "moonbitstack/moonetui/app" @app,
  "moonbitstack/moonetui/design" @design,
  "moonbitstack/moonetui/driver" @driver,
  "moonbitstack/moonetui/geom" @geom,
  "moonbitstack/moonetui/widget" @widget,
}
```

Every package below the application is optional: a program that only formats a
line imports `@style` and `@strip` and nothing else.

## Draw one widget

A widget is a value with four operations: `render_line(row, size)` draws one row
as a `Strip`, `hint(size)` says the size it wants, `handle(ctx, msg)` answers a
message, and `focusable()` says whether Tab reaches it. Nothing is global and
nothing calls back, so a widget draws in a test with no terminal at all.

```moonbit
let field = @widget.Input::new(placeholder="name")
let at = @geom.Size::new(12, 1)
let line = field.render_line(0, at)
assert_eq(@strip.str_cells(line.text()), 12)
```

## Put a screen together

`App` owns the tree, the focus ring and the frame loop. `Headless` is a driver
that answers from a script of bytes, which is how a program is tested; a real
program passes `@native.NativeTty`, `@node.NodeTty` or `@web.WebTty` instead.

```moonbit
let tty = @driver.Headless::new(
  @geom.Size::new(24, 3),
  script=[b"\x1b[B"],
  tick=16,
)
let list = @widget.OptionList::new(options=[
  @widget.Choice::new("one"),
  @widget.Choice::new("two"),
])
let ui = @app.App::new(tty, @app.leaf(1, list))
ui.start()
ignore(ui.step())
assert_eq(ui.screen()[0].has_prefix("one"), true)
assert_eq(ui.focused(), 1)
```

A host that already has a loop calls `step()` once a frame and keeps whatever
`drain()` hands it: `Pressed`, `Changed`, `Selected`, `MenuPicked`, `Dismissed`
and the rest are plain values, so a handler is a `match` and not a callback.

## Style by role, switch the whole look

A stylesheet is rules over name, id, class and `:focus`, stacked by
specificity. A theme is one value holding every semantic colour, and
`Theme::sheet()` turns it into the rules the widgets already answer to.

```moonbit
let sheet = @design.light.sheet()
let node = @app.leaf(1, @widget.Static::new("ready"), classes=["success"])
assert_eq(@design.light.colour(@design.Success), @style.Colour::rgb(0, 112, 60))
assert_eq(node.id(), 1)
```

`set_theme` on a running application swaps the sheet in place, so a light and a
dark look are the same tree.

## Keep the choice outside the widget

`StatefulList` and `StatefulTable` draw from a state the caller owns, and move
it. Two widgets can share one state, and a caller can set either the choice or
the scroll between frames.

```moonbit
let state = @widget.ListState::new(selected=1)
let list = @widget.StatefulList::new(items=["alpha", "beta"], state~)
assert_eq(list.state().selected(), 1)
state.select(0, 2) |> ignore
assert_eq(list.state().selected(), 0)
```

## Rules that catch people out

- Only the focused widget is offered a key. A widget that moves a choice
  together with the view is what the library expects: the wheel scrolls the
  view alone, and a key or a click on a row moves the choice and pulls the view
  back to it.
- `@driver/native` compiles on native only, and marks itself so; keep such code
  in a `.mbt` file the whole application builds for native. Node and the browser
  have their own packages, and `@driver.Headless` works everywhere.
- A modal is a root, not a layer: `push_screen` puts a dialog or a command
  palette over the tree and `pop_screen` takes it away. The message that closes
  it is `Dismissed`.
- Colours are quantised by `moonrgba`, and widths come from `moonucd`, so a
  CJK glyph or an emoji takes two cells and combining marks take none.
- Text is measured in terminal columns, never in code units: `String::length`
  is UTF-16 and will disagree with the screen.
- `Calendar` takes a date from `moondate`; `Calendar::on(year, month, day)` is
  the builder for a caller that has three numbers.
