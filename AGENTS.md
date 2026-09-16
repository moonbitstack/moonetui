`moonetui` is a terminal UI toolkit for MoonBit, written after Python's Textual. It renders into a cell buffer, diffs consecutive frames, and emits the smallest escape sequence that repaints the change.

# Working here

- `moon fmt` first. CI runs `moon fmt`, `moon info --target all` and then `git diff --exit-code`, so an unformatted file or a stale `pkg.generated.mbti` fails the build on its own.
- `moon check --target all --deny-warn` is the gate. Warnings are errors, and all four backends must pass. `moon test` does not run `--deny-warn`, so a green test run says nothing about the gate.
- `moon info --target all` regenerates every `pkg.generated.mbti`. Read the diff: that file is the public interface moving.
- CI installs the latest moon on every run. Upgrade locally rather than pinning.

# Two rules the whole repository depends on

- **The core is synchronous.** `wasm-gc` has no `async`, and the core must run there because that is the backend the tests run on. So no library code is `async`: the main loop is `App::step`, which the host calls — a blocking poll on native, `setInterval` under Node, `requestAnimationFrame` in a browser. `Driver::poll(timeout_ms)` means *at most* that long, and returns whatever has arrived, possibly nothing.
- **Anything that reaches a snapshot must be target-independent.** The gate runs the same `inspect` snapshots on wasm, wasm-gc, js and native. Never let a floating point number, a `Map` iteration order, or `String`'s `<` (which is shortlex — it compares length first, not code points) decide what a snapshot contains.

# Layout

One package per concern, and the dependency graph is a DAG so the compiler enforces the layering: `geom` sits at the bottom; `style` and `event` build on it; `strip` renders a line; `layout` places boxes; `widget` draws into strips; `comp` composes and diffs; `app` drives; `driver/*` are the only packages that touch a platform. Tests live beside their subject as `*_test.mbt` (black box, through the package's public face) or `*_wbtest.mbt` (white box, for internals).

# Things worth knowing

- A trait implementation that a package's own code never uses is an error under `--deny-warn`. Operator implementations must be written `pub impl Add for T with fn add(…)` — without `pub` they are invisible outside the package, and the black-box tests will report the trait as unimplemented.
- `geom` clamps rather than raising. A negative extent becomes zero, a split outside the region yields one full part and one empty part, and an empty operand to `union` is ignored. Off-screen widgets are normal, so they must not be errors.
- Terminal cells are whole columns. Nothing in `geom` is fractional, and nothing downstream may introduce a fractional coordinate — a half-column does not exist.
