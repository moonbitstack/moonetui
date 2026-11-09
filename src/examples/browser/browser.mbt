// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The whole gallery on the canvas whose id is `canvas`.
pub fn start(canvas : String) -> Unit {
  let gallery = @showcase.Gallery::new()
  let ui = @app.App::new(
    @web.WebTty::new(canvas~, font_px=14, fg=fore, bg=back, palette=site),
    gallery.tree(),
    sheet=gallery.sheet(),
  )
  gallery.attach(ui)
  run(ui, canvas, out => gallery.react(ui, out))
}

///|
/// One demo, by name, on the canvas whose id is `canvas`. What its widgets
/// report goes to the page's `moonetuiReport(canvas, text)`, if it has one.
pub fn mount(canvas : String, name : String) -> Unit {
  guard @showcase.find(name) is Some(demo) else { return }
  let tty = @web.WebTty::new(
    canvas~,
    font_px=14,
    fg=fore,
    bg=back,
    palette=site,
  )
  let ui = @app.App::new(tty, demo.tree, sheet=demo.sheet)
  for id in demo.disabled {
    ui.disable(id)
  }
  run(ui, canvas, _ => ())
}

///|
fn run(
  ui : @app.App[@web.WebTty],
  canvas : String,
  react : (@widget.Out) -> Unit,
) -> Unit {
  ui.start() catch {
    _ => return
  }
  @web.pump(() => {
    let alive = ui.step() catch { _ => false }
    for out in ui.drain() {
      match out {
        Focused(..) | Blurred(..) | Repaint(..) => ()
        _ => report(canvas, @debug.to_string(out))
      }
      react(out)
    }
    alive
  })
}

///|
extern "js" fn report(canvas : String, text : String) -> Unit =
  #| (canvas, text) => {
  #|   if (typeof globalThis.moonetuiReport === "function") {
  #|     globalThis.moonetuiReport(canvas, text);
  #|   }
  #| }

///|
/// The documentation site's terminal colours, so a canvas sits in its page.
let fore : String = "#c9d4e8"

///|
let back : String = "#0a0e16"

///|
/// The named colours in the site's own palette, which the pages' code blocks
/// use too: the standard table's dark red and blue are hard to read on `back`.
let site : @style.Palette = {
  named: [
    (0x15, 0x16, 0x1e),
    (0xf7, 0x76, 0x8e),
    (0x9e, 0xce, 0x6a),
    (0xe0, 0xaf, 0x68),
    (0x7a, 0xa2, 0xf7),
    (0xbb, 0x9a, 0xf7),
    (0x7d, 0xcf, 0xff),
    (0xa9, 0xb1, 0xd6),
    (0x41, 0x48, 0x68),
    (0xff, 0x89, 0x9d),
    (0xb9, 0xf2, 0x7c),
    (0xff, 0xc7, 0x77),
    (0x8d, 0xb0, 0xff),
    (0xc7, 0xa9, 0xff),
    (0xa4, 0xda, 0xff),
    (0xc0, 0xca, 0xf5),
  ],
}
