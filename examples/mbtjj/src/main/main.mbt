// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The words on the command line.
fn usage() -> Unit {
  println("mbtjj: Jujutsu in a terminal")
  println("")
  println("  mbtjj                 the repository in this directory")
  println("  mbtjj <path>          the repository there")
  println("  mbtjj --revset 'x'    open on a revset")
  println(
    "  mbtjj --demo          a log captured from a repository, for a screenshot",
  )
  println(
    "  mbtjj --headless      draw a few frames and print them, for a check",
  )
  println("")
  println(
    "  keys: ↑↓ move, / revset, d what it does, o operations, ? all keys, q quit",
  )
}

///|
fn flag(args : Array[String], name : String) -> String {
  let mut at = -1
  for i in 0..<args.length() {
    if args[i] == name && i + 1 < args.length() {
      at = i + 1
    }
  }
  if at >= 0 {
    args[at]
  } else {
    ""
  }
}

///|
fn has(args : Array[String], name : String) -> Bool {
  for arg in args {
    if arg == name {
      return true
    }
  }
  false
}

///|
/// The first word that is not a flag and not a flag's value.
fn positional(args : Array[String]) -> String {
  let mut skip = false
  for arg in args {
    if skip {
      skip = false
      continue
    }
    if arg.has_prefix("--") {
      if arg == "--revset" || arg == "--frames" {
        skip = true
      }
      continue
    }
    return arg
  }
  ""
}

///|
async fn main {
  // The first word is the program itself.
  let all = @env.args()
  let args : Array[String] = []
  for i in 1..<all.length() {
    args.push(all[i])
  }
  if has(args, "--help") || has(args, "-h") {
    usage()
    return
  }
  let demo = has(args, "--demo")
  let given = positional(args)
  let root = if given == "" { "." } else { given }
  let screen = @mbtjj.Screen::new(root)
  let revset = flag(args, "--revset")
  if demo {
    screen.set_log(@mbtjj.parse_log(@mbtjj.demo_log))
  } else {
    screen.open(revset~)
    if screen.rows().length() == 0 {
      // jj said why, or there is nothing to show. Either way there is nothing
      // to draw: say it, and leave with a code a script can read.
      println("mbtjj: " + screen.status())
      @env.exit(1)
    }
  }
  // A terminal when there is one, a fixed screen when there is not: the same
  // window either way, so what a check draws is what a reader sees.
  let frames = if has(args, "--headless") {
    let asked = @string.parse_int(flag(args, "--frames")) catch { _ => 3 }
    if asked < 1 {
      3
    } else {
      asked
    }
  } else {
    0
  }
  if frames > 0 {
    let tty = @driver.Headless::new(@geom.Size::new(100, 24))
    let ui = @app.App::new(tty, screen.node(), sheet=@mbtjj.sheet(), quit=[
      @app.ctrl_c,
    ])
    ui.start()
    for _ in 0..<frames {
      ignore(ui.step() catch { _ => false })
      ignore(ui.drain())
      match screen.take() {
        Some(req) => {
          screen.serve(req)
          ui.refresh()
        }
        None => ()
      }
    }
    for row in ui.screen() {
      println(row)
    }
    ui.stop()
    return
  }
  let ui = @app.App::new(
    @native.NativeTty::new(),
    screen.node(),
    sheet=@mbtjj.sheet(),
    quit=[@app.ctrl_c],
  )
  ui.start()
  let mut alive = true
  while alive {
    alive = ui.step() catch { _ => false }
    ignore(ui.drain())
    match screen.take() {
      Some(req) => {
        screen.serve(req)
        ui.refresh()
      }
      None => ()
    }
  }
  ui.stop()
}
