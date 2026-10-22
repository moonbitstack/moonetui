// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn main raise {
  let gallery = @showcase.Gallery::new()
  let ui = @app.App::new(
    @native.NativeTty::new(),
    gallery.tree(),
    sheet=gallery.sheet(),
  )
  gallery.attach(ui)
  ui.start()
  @native.run(() => {
    let alive = ui.step()
    for out in ui.drain() {
      gallery.react(ui, out)
    }
    alive
  })
  ui.stop()
}
