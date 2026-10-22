// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn lines(kid_id : Int32) -> @app.Node {
  let kids : Array[@app.Node] = []
  for i in 0..<10 {
    kids.push(
      @app.leaf(kid_id + i, @widget.Static::new("line " + i.to_string())),
    )
  }
  @app.column(kid_id, kids)
}

///|
test "a scroll container shows a window of its child" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 4))
  let ui = @app.App::new(tty, @app.scroll(1, lines(10)))
  ui.start()
  assert_eq(ui.screen(), [
    "line 0   █", "line 1   ░", "line 2   ░", "line 3   ░",
  ])
}

///|
test "arrow keys scroll the container holding focus" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 4), script=[
    ascii("\u{1b}[B\u{1b}[B"),
  ])
  let ui = @app.App::new(tty, @app.scroll(1, lines(10)))
  ui.start()
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "line 2   ░", "line 3   █", "line 4   ░", "line 5   ░",
  ])
}

///|
test "home and end keys reach the ends" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 4), script=[
    ascii("\u{1b}[4~"),
    ascii("\u{1b}[1~"),
  ])
  let ui = @app.App::new(tty, @app.scroll(1, lines(10)))
  ui.start()
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "line 6   ░", "line 7   ░", "line 8   ░", "line 9   █",
  ])
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "line 0   █", "line 1   ░", "line 2   ░", "line 3   ░",
  ])
}

///|
test "the wheel scrolls the container under the pointer" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 4), script=[
    ascii("\u{1b}[<65;3;2M"),
  ])
  let ui = @app.App::new(tty, @app.scroll(1, lines(10)))
  ui.start()
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "line 3   ░", "line 4   █", "line 5   ░", "line 6   ░",
  ])
}

///|
test "a horizontal scroll grows sideways" {
  let kids : Array[@app.Node] = []
  for i in 0..<5 {
    kids.push(@app.leaf(10 + i, @widget.Static::new("aaaaa")))
  }
  let tty = @driver.Headless::new(@geom.Size::new(12, 3), script=[
    ascii("\u{1b}[C\u{1b}[C\u{1b}[C"),
  ])
  let ui = @app.App::new(tty, @app.scroll(1, @app.row(2, kids)))
  ui.start()
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "aaaaaaaaaaaa", "            ", " █████      ",
  ])
}

///|
test "focus scrolls the container to the widget that took it" {
  let kids : Array[@app.Node] = []
  for i in 0..<8 {
    kids.push(@app.leaf(10 + i, @widget.Button::new("b" + i.to_string())))
  }
  let tty = @driver.Headless::new(@geom.Size::new(10, 4), script=[
    ascii("\t\t\t\t\t\t\t\t"),
  ])
  let ui = @app.App::new(tty, @app.scroll(1, @app.column(2, kids)))
  ui.start()
  assert_eq(ui.screen(), [
    "   b0    █", "   b1    █", "   b2    ░", "   b3    ░",
  ])
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "   b4    ░", "   b5    ░", "   b6    █", "   b7    █",
  ])
}

///|
test "scroll offsets clamp at both ends" {
  let state = @app.ScrollState::new()
  let tty = @driver.Headless::new(@geom.Size::new(10, 4))
  let ui = @app.App::new(tty, @app.scroll(1, lines(10), state~))
  ui.start()
  assert_eq(state.scroll_by(dy=999), true)
  assert_eq(state.y, 6)
  assert_eq(state.scroll_by(dy=999), false)
  assert_eq(state.scroll_to(y=-5), true)
  assert_eq(state.y, 0)
  assert_eq(state.scroll_to(y=3), true)
  assert_eq(state.x, 0)
  ui.refresh()
  ui.step() |> ignore
  assert_eq(ui.screen(), [
    "line 3   ░", "line 4   █", "line 5   ░", "line 6   ░",
  ])
}

///|
test "a hidden scroll and its child are gone" {
  let tty = @driver.Headless::new(@geom.Size::new(10, 4))
  let ui = @app.App::new(
    tty,
    @app.scroll(
      1,
      lines(10),
      styles=@design.Styles::new(display=@design.Hidden),
    ),
  )
  ui.start()
  assert_eq(ui.screen(), [
    "          ", "          ", "          ", "          ",
  ])
}

///|
test "a border frames the window, not the content" {
  let tty = @driver.Headless::new(@geom.Size::new(12, 6))
  let ui = @app.App::new(
    tty,
    @app.scroll(1, lines(10), styles=@design.Styles::new(border=@design.Thin)),
  )
  ui.start()
  assert_eq(ui.screen(), [
    "┌──────────┐", "│line 0   █│", "│line 1   ░│",
    "│line 2   ░│", "│line 3   ░│", "└──────────┘",
  ])
}
