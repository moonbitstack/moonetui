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
| `@style` | Colours (named, indexed, true colour), text attributes, palette quantisation, and differential SGR rendering | done |
| `@strip` | One rendered line: styled segments measured in terminal columns, with cropping, division, padding and merging, over a generated Unicode width table | done |
| `@event` | Keys, mouse reports, paste, resize and focus as plain values | done |
| `@input` | The terminal byte stream turned into events: CSI and SS3 sequences, modifiers, SGR mouse, bracketed paste, in-band resize, UTF-8 split across reads | done |
| `@comp` | The compositor: placements to composed rows, consecutive screens to the spans that changed, spans to escape sequences | done |
| `@driver` | The seam to a terminal — write, poll, size, raw mode, clock — plus the capability sequences and a headless terminal for tests | done |
| `@layout` | Placing boxes along an axis: fixed cells, percentages, automatic sizes and fractional shares, with integer division that loses no column | done |
| `@widget` | The widget contract and eight widgets: static text, label, button, input, list, progress bar, header, footer | done |
| `@app` | The widget tree, the focus ring, and the frame loop: poll, parse, dispatch, lay out, compose, diff, write | done |
| `@driver/node` | Node's terminal: raw mode, a queue the data handler fills, and a frame pump | done |
| `@driver/web` | A terminal drawn on a canvas: the grid, the escape sequences it understands, key encoding, and in-band resize | done |

What is left for 0.1.0: the native terminal driver (termios and the Windows console), which is written here but verified in CI, since this machine cannot link it.

## Design

The library core is **synchronous**. `wasm-gc` has no `async`, and the core has to run there because that is where the tests run, so the main loop is a `step()` the host drives: a blocking poll on native, `setInterval` under Node, `requestAnimationFrame` in a browser.

Only four operations ever touch a platform: write, read what is available, set raw mode, and ask for the terminal size. Everything else — parsing, layout, composition, widgets — is pure and runs on all four backends.

## Use it

```
moon add moonbitstack/moonetui
```

Two runnable examples: `moon run --target js examples/hello` for a terminal, and `examples/browser/index.html` for the same application drawn on a canvas.

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

135 tests; the browser grid's own tests run on the js backend, the rest on all four.

## License

Apache-2.0. See [LICENSE](LICENSE).
