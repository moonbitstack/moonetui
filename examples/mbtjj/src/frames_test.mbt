// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn key(text : String) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<text.length() {
    out.push(text[i].to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The window over the captured log, and the keys a reader presses on it. The
/// answers jj would give are handed in, so the test needs no repository.
test "the window draws the log, the change under the cursor and the keys" {
  let size = @geom.Size::new(100, 20)
  let screen = @mbtjj.Screen::new("moonetui")
  screen.set_log(@mbtjj.parse_log(@mbtjj.demo_log))
  let tty = @driver.Headless::new(size, script=[key("d")])
  let ui = @app.App::new(tty, screen.node(), sheet=@mbtjj.sheet(), quit=[
    @app.ctrl_c,
  ])
  let total = StringBuilder()
  ui.start()
  total.write_string(tty.output())
  tty.clear_output()
  @frames.announce("mbtjj/00 log", size, total.to_string(), ui.screen())
  // The band names the tool and the repository; the log names its revisions.
  assert_true(ui.screen()[0].contains("mbtjj"))
  assert_true(ui.screen()[0].contains("moonetui"))
  assert_true(ui.screen()[2].contains("LOG"))
  assert_true(ui.screen()[3].contains("aaaaaaaabbbb"))
  // The change under the cursor is the working copy, and it says so.
  assert_true(ui.screen()[3].contains("working copy"))
  // `d` asks for the diff; the host answers, and the pane changes its name.
  ui.step() |> ignore
  total.write_string(tty.output())
  tty.clear_output()
  assert_true(screen.view() is @mbtjj.View::Diff)
  screen.set_aside(@mbtjj.lines_of(@mbtjj.demo_diff))
  ui.refresh()
  ui.step() |> ignore
  total.write_string(tty.output())
  tty.clear_output()
  assert_true(ui.screen()[2].contains("DIFF"))
  assert_true(ui.screen()[3].contains("Modified regular file"))
  @frames.announce("mbtjj/01 diff", size, total.to_string(), ui.screen())
  // `?` puts the keys where the change was.
  tty.push(key("?"))
  ui.step() |> ignore
  total.write_string(tty.output())
  tty.clear_output()
  assert_true(screen.view() is @mbtjj.View::Help)
  assert_true(ui.screen()[2].contains("KEYS"))
  assert_true(ui.screen()[3].contains("revision"))
  @frames.announce("mbtjj/02 keys", size, total.to_string(), ui.screen())
  // `q` leaves: the window stops rather than drawing again.
  tty.push(key("q"))
  ui.step() |> ignore
  assert_eq(ui.screen_depth(), 1)
}
