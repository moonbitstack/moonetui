// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The whole gallery on the canvas whose id is `canvas`.
pub fn start(canvas : String) -> Unit {
  let gallery = @showcase.Gallery::new()
  let ui = @app.App::new(
    @web.WebTty::new(canvas~, font_px=14, fg=fore, bg=back),
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
  let tty = @web.WebTty::new(canvas~, font_px=14, fg=fore, bg=back)
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
