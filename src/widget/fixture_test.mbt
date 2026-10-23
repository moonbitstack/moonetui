// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let plain : @style.Style = @style.default

///|
fn size(width : Int32, height : Int32) -> @geom.Size {
  @geom.Size::new(width, height)
}

///|
fn rows(w : &@widget.Widget, at : @geom.Size) -> Array[String] {
  let out : Array[String] = []
  for y in 0..<at.height {
    out.push(w.render_line(y, at).text())
  }
  out
}

///|
fn key(code : @event.KeyCode) -> @widget.Msg {
  Key(@event.Key::of(code))
}

///|
fn press(
  w : &@widget.Widget,
  id : Int32,
  at : @geom.Size,
  msg : @widget.Msg,
) -> Array[@widget.Out] {
  let ctx = @widget.Ctx::new(id, at)
  w.handle(ctx, msg) |> ignore
  ctx.asked()
}

///|
fn mouse(kind : @event.MouseKind, x : Int32, y : Int32) -> @widget.Msg {
  Mouse({ kind, button: 0, x, y, mods: @event.none, })
}

///|
/// Whether `w` took `msg`, and what it asked for.
fn feed(
  w : &@widget.Widget,
  at : @geom.Size,
  msg : @widget.Msg,
) -> (Bool, Array[@widget.Out]) {
  let ctx = @widget.Ctx::new(1, at)
  let took = w.handle(ctx, msg)
  (took, ctx.asked())
}
