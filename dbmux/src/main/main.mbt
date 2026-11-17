// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The stylesheet: a chrome bar, framed panes, and a heavy frame around the
/// pane that has the keyboard.
fn sheet() -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(),
    @design.Styles::new(text=@style.Style::new(fg=@style.bright_white)),
  )
  sheet.add(
    @design.Sel::new(name="Header"),
    @design.Styles::new(text=@style.Style::new(bold=true, fg=@style.cyan)),
  )
  sheet.add(
    @design.Sel::new(classes=["framed"]),
    @design.Styles::new(
      border=@design.Round,
      padding=@geom.Spacing::horizontal(1),
    ),
  )
  sheet
}

///|
/// What the window is looking at: a SQL session, or a Redis one. Both answer
/// the same commands — open, reload, run, save — with what each can do, so the
/// window itself does not branch on the engine.
enum Link {
  Sql(@db.Session)
  Redis(@db.Redis)
}

///|
/// The name of the virtual table that lists Redis keys.
let keys_table : String = "keys"

///|
/// A table page from what the grid is showing: its filter, its ordering, its
/// limit and the page it is on.
fn query_of(grid : @table.Grid) -> @sqlkit.PageQuery {
  {
    schema: grid.page.schema,
    table: grid.page.table,
    columns: [],
    filter: grid.filter,
    sorts: grid.sorts,
    limit: grid.limit,
    offset: grid.offset,
  }
}

///|
/// Load the page the grid asks for, and set its total so the status line can
/// say how far the reader is.
async fn load(
  session : @db.Session,
  grid : @table.Grid,
) -> Unit raise @db.Failed {
  let q = query_of(grid)
  let page = session.page(q)
  let total = session.count(q)
  grid.page = page
  grid.total = Some(total)
  grid.changes = Map([])
  grid.added = []
  grid.deleted = []
  let rows = grid.row_count()
  if grid.cursor_row >= rows && rows > 0 {
    grid.cursor_row = rows - 1
  }
}

///|
/// The rows of a Redis table: the keys themselves, or one key's value. A key
/// opens as a table named `key:<name>`, which is what the tab strip shows and
/// what a reload asks for again.
async fn redis_page(
  redis : @db.Redis,
  table : String,
) -> @table.Page raise @db.Failed {
  if table.has_prefix("key:") {
    let key = table.exact_view(start=4).to_owned()
    let view = redis.view(key)
    @table.Page::new(None, table, view.columns, view.rows, [])
  } else {
    let pairs = redis.keys("*", 500)
    let rows : Array[Array[@table.Cell]] = []
    for (key, kind) in pairs {
      rows.push([@table.Cell::of(key), @table.Cell::of(kind)])
    }
    @table.Page::new(None, keys_table, ["key", "type"], rows, ["key"])
  }
}

///|
/// Open a table in the pane that has the keyboard.
async fn open_table(
  link : Link,
  state : @shell.State,
  schema : String?,
  table : String,
) -> Unit {
  match link {
    Sql(session) => {
      let page = session.page({
        schema,
        table,
        columns: [],
        filter: "",
        sorts: [],
        limit: 100,
        offset: 0L,
      }) catch {
        @db.Failed(text~) => {
          state.message = text
          return
        }
      }
      state.show_page(page)
      state.message = ""
    }
    Redis(redis) => {
      let page = redis_page(redis, table) catch {
        @db.Failed(text~) => {
          state.message = text
          return
        }
      }
      state.show_page(page)
      state.message = ""
    }
  }
}

///|
/// Reload the page the active grid is on.
async fn reload(link : Link, state : @shell.State) -> Unit {
  match state.grid() {
    None => ()
    Some(grid) =>
      match link {
        Sql(session) =>
          load(session, grid) catch {
            @db.Failed(text~) => state.message = text
          }
        Redis(redis) => {
          let page = redis_page(redis, grid.page.table) catch {
            @db.Failed(text~) => {
              state.message = text
              return
            }
          }
          grid.page = page
          grid.total = Some(grid.row_count().to_int64())
          grid.changes = Map([])
          grid.added = []
          grid.deleted = []
        }
      }
  }
}

///|
/// Run what the editor holds: a script for SQL, one command for Redis. The
/// last result becomes a tab of its own.
async fn run(link : Link, state : @shell.State, text : String) -> Unit {
  match state.refusal(text) {
    Some(refusal) => state.message = refusal
    None =>
      match link {
        Sql(session) => {
          let pieces = @sqlkit.statements(text, state.dialect)
          let mut last : @db.Result? = None
          let mut failure = ""
          for piece in pieces {
            let result = session.query(piece) catch {
              @db.Failed(text~) => {
                failure = text
                break
              }
            }
            last = Some(result)
          }
          if failure != "" {
            state.message = failure
          } else {
            match last {
              Some(result) =>
                if result.columns.length() > 0 {
                  state.result = Some(result)
                  state.show_page(
                    @table.Page::new(
                      None,
                      "result",
                      result.columns,
                      result.rows,
                      [],
                    ),
                  )
                  state.message = result.rows.length().to_string() + " rows"
                } else {
                  state.message = result.affected.to_string() + " rows affected"
                }
              None => state.message = "nothing to run"
            }
          }
        }
        Redis(redis) => {
          let result = redis.command(text) catch {
            @db.Failed(text~) => {
              state.message = text
              return
            }
          }
          state.result = Some(result)
          state.show_page(
            @table.Page::new(None, "reply", result.columns, result.rows, []),
          )
          state.message = result.rows.length().to_string() + " rows"
        }
      }
  }
}

///|
/// Run a save: one transaction for SQL; Redis has no such thing here, and says
/// so rather than pretend.
async fn save(
  link : Link,
  state : @shell.State,
  statements : Array[String],
  expected : Array[Int64],
) -> Unit {
  match link {
    Sql(session) => {
      let mut saved = true
      session.run(statements, expected) catch {
        @db.Failed(text~) => {
          state.message = text
          saved = false
        }
      }
      if saved {
        state.message = "saved"
        match state.grid() {
          Some(grid) => {
            grid.revert()
            load(session, grid) catch {
              @db.Failed(text~) => state.message = text
            }
          }
          None => ()
        }
      }
    }
    Redis(redis) => {
      let mut saved = true
      for statement in statements {
        let outcome = Ok(redis.command(statement)) catch {
          @db.Failed(text~) => Err(text)
        }
        match outcome {
          Ok(_) => ()
          Err(text) => {
            state.message = text
            saved = false
          }
        }
      }
      if saved {
        match state.grid() {
          Some(grid) => grid.revert()
          None => ()
        }
        reload(link, state)
        state.message = "saved"
      }
    }
  }
}

///|
/// A small database to look at with no server and no file: three tables, a
/// primary key each, and enough rows to page through.
async fn seed(session : @db.Session) -> Unit raise @db.Failed {
  let statements = [
    "create table customers (id integer primary key, name text, city text, joined text)",
    "create table orders (id integer primary key, customer_id integer, total real, status text, note text)",
    "create table products (id integer primary key, sku text, price real)", "insert into customers values (1, 'Ada', 'London', '2024-01-04')",
    "insert into customers values (2, 'Blaise', 'Paris', '2024-02-11')", "insert into customers values (3, 'Grace', 'New York', '2024-03-02')",
    "insert into orders values (1, 1, 10.5, 'paid', null)", "insert into orders values (2, 2, 7.0, 'open', 'rush')",
    "insert into orders values (3, 1, 99.9, 'paid', null)", "insert into orders values (4, 3, 42.0, 'refunded', 'damaged box')",
    "insert into products values (1, 'SKU-1', 3.5)", "insert into products values (2, 'SKU-2', 12.0)",
  ]
  for statement in statements {
    ignore(session.query(statement))
  }
}

///|
/// The first argument that is not a flag, or the empty string.
fn positional(args : Array[String]) -> String {
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if !arg.has_prefix("--") {
      return arg
    }
    i = i + 1
  }
  ""
}

///|
/// The value of a flag, or the empty string.
fn flag(args : Array[String], name : String) -> String {
  let mut i = 1
  while i < args.length() {
    if args[i] == name && i + 1 < args.length() {
      return args[i + 1]
    }
    i = i + 1
  }
  ""
}

///|
fn has_flag(args : Array[String], name : String) -> Bool {
  let mut found = false
  for arg in args {
    if arg == name {
      found = true
    }
  }
  found
}

///|
async fn main {
  let args = @env.args()
  let demo = has_flag(args, "--demo")
  let target = positional(args)
  if !demo && target == "" {
    println("dbmux: a database client")
    println("")
    println(
      "  dbmux --demo                     a SQLite database in memory, with sample rows",
    )
    println("  dbmux ./app.db                   a SQLite file")
    println(
      "  dbmux postgres://me@host/app     PostgreSQL, MySQL, SQL Server by their URL",
    )
    println(
      "  dbmux redis://127.0.0.1:6379/0   Redis: the keys, a key's value, a console",
    )
    println("")
    println(
      "  keys: j k move, s sort, f filter, e edit, C-s save, C-v split, ? all keys, q quit",
    )
    println("  files: --config connections.toml, --keymap keymaps.toml")
    return
  }
  // A target that is not a URL and not a file is a name from the connection
  // file; with no name, the file is read only to say what it holds.
  let config_path = {
    let given = flag(args, "--config")
    if given != "" {
      Some(given)
    } else {
      match @env.get_env_var("DBMUX_CONFIG") {
        Some(value) => Some(value)
        None =>
          if @fs.path_exists("connections.toml") {
            Some("connections.toml")
          } else {
            None
          }
      }
    }
  }
  let from_file : Array[@config.Connection] = match config_path {
    None => []
    Some(path) => {
      let text = @fs.read_file_to_string(path) catch { _ => "" }
      if text == "" {
        []
      } else {
        @config.load(text) catch {
          @config.Refused(text~) => {
            println("dbmux: " + text)
            return
          }
        }
      }
    }
  }
  let named = if target != "" &&
    !target.contains("://") &&
    !target.has_suffix(".db") &&
    !target.has_suffix(".sqlite") &&
    !target.has_suffix(".sqlite3") {
    let mut found : @config.Connection? = None
    for entry in from_file {
      if entry.name == target {
        found = Some(entry)
      }
    }
    match found {
      Some(entry) => Some(entry)
      None => {
        if from_file.length() > 0 {
          println("dbmux: no connection is named " + target + "; the file has:")
          for entry in from_file {
            println("  " + entry.name + "  " + entry.engine.name())
          }
          return
        }
        None
      }
    }
  } else {
    None
  }
  let connection : @config.Connection = if demo {
    {
      name: "demo",
      group: "",
      engine: @config.Engine::Sqlite,
      dsn: ":memory:",
      read_only: false,
      production: false,
      password_env: None,
      delimiter: ":",
    }
  } else {
    match named {
      Some(entry) => entry
      None =>
        @config.of_target(target) catch {
          @config.Refused(text~) => {
            println(text)
            return
          }
        }
    }
  }
  let password = match connection.password_env {
    Some(name) =>
      match @env.get_env_var(name) {
        Some(value) => value
        None => ""
      }
    None => ""
  }
  let dialect = match connection.engine.dialect() {
    Some(d) => d
    None => @sqlkit.Dialect::Sqlite
  }
  // The keymap file is found the way the connection file is: a flag, the environment, then the
  // working directory. A name it binds that no action has stops here rather than at a dead key.
  let keymap_path = {
    let given = flag(args, "--keymap")
    if given != "" {
      Some(given)
    } else {
      match @env.get_env_var("DBMUX_KEYMAP") {
        Some(value) => Some(value)
        None =>
          if @fs.path_exists("keymaps.toml") {
            Some("keymaps.toml")
          } else {
            None
          }
      }
    }
  }
  let keymap = match keymap_path {
    None => @keymap.Keymap::default()
    Some(path) => {
      let text = @fs.read_file_to_string(path) catch {
        _ => {
          println("dbmux: cannot read " + path)
          return
        }
      }
      @keymap.Keymap::default().over(text) catch {
        @config.Refused(text~) => {
          println("dbmux: " + path + ": " + text)
          return
        }
      }
    }
  }
  let state = @shell.State::new(
    connection.name,
    connection.engine,
    dialect,
    connection.read_only,
    connection.production,
    keymap,
  )
  // The queries run before, from `--history`, `DBMUX_HISTORY`, or `.dbmux_history` at home.
  let home = match @env.get_env_var("HOME") {
    Some(h) => Some(h)
    None => @env.get_env_var("USERPROFILE")
  }
  state.history.keep_in(
    {
      let given = flag(args, "--history")
      if given != "" {
        Some(given)
      } else {
        match @env.get_env_var("DBMUX_HISTORY") {
          Some(value) => Some(value)
          None => home.map(h => h + "/.dbmux_history")
        }
      }
    },
  )
  match state.history.path() {
    Some(path) if @fs.path_exists(path) =>
      state.history.load(@fs.read_file_to_string(path) catch { _ => "" })
    _ => ()
  }
  let link = match connection.engine {
    @config.Engine::Redis => {
      let redis = @db.Redis::open(connection.dsn, password) catch {
        @db.Failed(text~) => {
          println("dbmux: " + text)
          return
        }
      }
      state.set_catalog([], [
        { schema: None, name: keys_table, is_view: false, },
      ])
      Link::Redis(redis)
    }
    _ => {
      let session = @db.Session::open(connection, password) catch {
        @db.Failed(text~) => {
          println("dbmux: " + text)
          return
        }
      }
      if demo {
        seed(session) catch {
          @db.Failed(text~) => {
            println("dbmux: " + text)
            session.close()
            return
          }
        }
      }
      let tables = session.tables(None) catch {
        @db.Failed(text~) => {
          println("dbmux: " + text)
          session.close()
          return
        }
      }
      state.set_catalog([], tables)
      Link::Sql(session)
    }
  }
  let wanted = flag(args, "--table")
  let first = if wanted != "" {
    wanted
  } else {
    match state.tables {
      [] => ""
      [table, ..] => table.name
    }
  }
  if first != "" {
    open_table(link, state, None, first)
    state.message = ""
  } else {
    state.message = "no tables; press C-r to run SQL once the editor has some"
  }
  let screen = @ui.Screen::new(state)
  screen.refresh()
  let headless = has_flag(args, "--headless")
  let frames = if headless {
    let text = flag(args, "--frames")
    match text {
      "" => 3
      _ => @string.parse_int(text) catch { _ => 3 }
    }
  } else {
    0
  }
  if headless {
    let head = @driver.Headless::new(@geom.Size::new(110, 32))
    let keys = flag(args, "--keys")
    if keys != "" {
      for chunk in keys_to_chunks(keys) {
        head.push(chunk)
      }
    }
    drive(head, screen, link, state, frames)
  } else {
    drive(@native.NativeTty::new(), screen, link, state, 0)
  }
  match link {
    Link::Sql(session) => session.close()
    Link::Redis(_) => ()
  }
}

///|
/// A key script on the command line, in chunks: `jj` is two downs, `\e` is
/// escape and `\x13` is Ctrl-S, so a test can press what a reader presses, and
/// `|` ends a chunk. One chunk is read per frame, so a key that opens a table
/// and a key that acts on the open table are in different chunks.
fn keys_to_chunks(text : String) -> Array[Bytes] {
  let out : Array[Bytes] = []
  for part in text.split("|") {
    out.push(keys_to_bytes(part.to_owned()))
  }
  out
}

///|
/// One chunk of a key script, as the bytes a terminal would send.
fn keys_to_bytes(text : String) -> Bytes {
  let chars = text.to_array()
  let out : Array[Byte] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' && i + 1 < chars.length() {
      let next = chars[i + 1]
      if next == 'e' {
        out.push(b'\x1b')
        i = i + 2
        continue
      } else if next == 'x' && i + 3 < chars.length() {
        let hex = String::from_array([chars[i + 2], chars[i + 3]])
        let code = @db.hex_code(hex)
        out.push(code.to_byte())
        i = i + 4
        continue
      } else if next == 't' {
        out.push(b'\t')
        i = i + 2
        continue
      }
    }
    out.push(c.to_int().to_byte())
    i = i + 1
  }
  Bytes::from_array(out)
}

///|
/// The loop: draw, read a key, run what it asked for. `frames` above zero
/// means no terminal is attached — the headless driver draws a fixed size and
/// the loop stops after that many frames, which is how CI checks the screen
/// without a tty.
async fn[D : @driver.Driver] drive(
  driver : D,
  screen : @ui.Screen,
  link : Link,
  state : @shell.State,
  frames : Int32,
) -> Unit {
  let ui = @app.App::new(driver, screen.node(), sheet=sheet(), quit=[
    @app.ctrl_c, @app.esc, @app.q,
  ])
  ui.start()
  let mut alive = true
  let mut drawn = 0
  let mut shown = state.layout
  while alive {
    screen.refresh()
    // A split changes the tree itself, so the root is swapped when the layout
    // does; everything else is a repaint.
    if !(state.layout == shown) {
      ui.swap_root(screen.node())
      shown = state.layout
    }
    // The pane with the keyboard has to be the one the application delivers
    // keys to; a split moves it, and so does C-o.
    let want = @ui.pane_id(state.pane)
    let mut tries = 0
    while ui.focused() != want && tries < 8 {
      ui.focus_next(1)
      tries = tries + 1
    }
    ui.refresh()
    alive = ui.step() catch { _ => false }
    ignore(ui.drain())
    for command in screen.bus().take() {
      match command {
        @shell.Command::Quit => alive = false
        @shell.Command::OpenTable(schema~, table~) =>
          open_table(link, state, schema, table)
        @shell.Command::Reload => reload(link, state)
        @shell.Command::RunQuery(text~) => {
          run(link, state, text)
          state.history.add(text)
          if state.history.path() is Some(path) {
            @fs.write_string_to_file(path, state.history.text()) catch {
              _ => ()
            }
          }
        }
        @shell.Command::Save(statements~, expected~) =>
          save(link, state, statements, expected)
        @shell.Command::ExportCsv(path~) =>
          match state.grid() {
            Some(grid) => {
              let text = @export.csv(grid.visible(), grid.export_rows())
              @fs.write_string_to_file(path, text) catch {
                _ => state.message = "could not write " + path
              }
              state.message = "wrote " + path
            }
            None => ()
          }
        @shell.Command::ExportJson(path~) =>
          match state.grid() {
            Some(grid) => {
              let text = @export.json(grid.visible(), grid.export_rows())
              @fs.write_string_to_file(path, text) catch {
                _ => state.message = "could not write " + path
              }
              state.message = "wrote " + path
            }
            None => ()
          }
      }
    }
    drawn = drawn + 1
    if frames > 0 && drawn >= frames {
      alive = false
    }
  }
  if frames > 0 {
    println(ui.screen().join("\n"))
  }
  ui.stop()
}
