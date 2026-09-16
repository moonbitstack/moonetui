<div align="center">

# moonetui

**A terminal UI toolkit for [MoonBit](https://www.moonbitlang.com/)**

Cell buffer, differential ANSI renderer, incremental key parser, layout, widgets, and pluggable terminal drivers — after Python's [Textual](https://github.com/Textualize/textual).

[![Check and Test](https://img.shields.io/github/actions/workflow/status/moonbitstack/moonetui/ci.yml?branch=master&label=CI&logo=github)](https://github.com/moonbitstack/moonetui/actions)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

</div>

> 0.1.0 is under construction. This README states what is in the repository today, not what is planned.

## What is here

| Package | What it does | Status |
|:--|:--|:--:|
| `@geom` | Integer rectangle algebra: `Offset`, `Size`, `Region`, `Spacing`, with intersection, union, splitting and clamping | done |

Everything else on the way to 0.1.0 — styles, the cell buffer, the key parser, layout, widgets, the compositor and the three drivers — is not in the repository yet.

## Design

The library core is **synchronous**. `wasm-gc` has no `async`, and the core has to run there because that is where the tests run, so the main loop is a `step()` the host drives: a blocking poll on native, `setInterval` under Node, `requestAnimationFrame` in a browser.

Only four operations ever touch a platform: write, read what is available, set raw mode, and ask for the terminal size. Everything else — parsing, layout, composition, widgets — is pure and runs on all four backends.

## Use it

```
moon add moonbitstack/moonetui
```

```moonbit
let screen = @geom.Size::new(80, 24)
let panel = @geom.Region::new(2, 1, 40, 10)
let visible = panel.clip(screen.width, screen.height)
```

## Tests

```
moon check --target all --deny-warn
moon test --target all
```

13 tests, all four backends.

## License

Apache-2.0. See [LICENSE](LICENSE).
