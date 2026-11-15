// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The engines dbmux talks to. Each one has its own driver package underneath
/// and its own way of naming a catalog; the connection file holds the word.
#derive(Eq, Debug)
pub(all) enum Engine {
  Postgres
  Mysql
  Sqlite
  SqlServer
  Redis
}

///|
pub extend Engine with Eq::{not_equal, equal}

///|
pub extend Engine with Debug::{to_repr}

///|
pub fn Engine::parse(text : String) -> Engine? {
  match text.to_lower() {
    "postgres" | "postgresql" | "pg" => Some(Postgres)
    "mysql" | "mariadb" => Some(Mysql)
    "sqlite" | "sqlite3" => Some(Sqlite)
    "sqlserver" | "mssql" | "sqls" => Some(SqlServer)
    "redis" => Some(Redis)
    _ => None
  }
}

///|
pub fn Engine::name(self : Engine) -> String {
  match self {
    Postgres => "postgresql"
    Mysql => "mysql"
    Sqlite => "sqlite"
    SqlServer => "sqlserver"
    Redis => "redis"
  }
}

///|
/// The SQL dialect, or `None` for Redis, which speaks no SQL.
pub fn Engine::dialect(self : Engine) -> @sqlkit.Dialect? {
  match self {
    Postgres => Some(@sqlkit.Dialect::Postgres)
    Mysql => Some(@sqlkit.Dialect::Mysql)
    Sqlite => Some(@sqlkit.Dialect::Sqlite)
    SqlServer => Some(@sqlkit.Dialect::SqlServer)
    Redis => None
  }
}

///|
/// One connection a session may open. A production connection defaults to
/// read-only: the file has to say `read_only = false` to write on it.
pub(all) struct Connection {
  name : String
  group : String
  engine : Engine
  dsn : String
  read_only : Bool
  production : Bool
  password_env : String?
  delimiter : String
}

///|
/// What a DSN's scheme says the engine is.
pub fn Engine::of_dsn(dsn : String) -> Engine? {
  let lowered = dsn.to_lower()
  if lowered.has_prefix("postgres://") || lowered.has_prefix("postgresql://") {
    Some(Postgres)
  } else if lowered.has_prefix("mysql://") || lowered.has_prefix("mariadb://") {
    Some(Mysql)
  } else if lowered.has_prefix("sqlserver://") || lowered.has_prefix("mssql://") {
    Some(SqlServer)
  } else if lowered.has_prefix("redis://") || lowered.has_prefix("rediss://") {
    Some(Redis)
  } else if dsn.has_suffix(".db") ||
    dsn.has_suffix(".sqlite") ||
    dsn.has_suffix(".sqlite3") {
    Some(Sqlite)
  } else {
    None
  }
}

///|
/// A DSN with the password taken out, for the header and the tree.
pub fn redact(dsn : String) -> String {
  match dsn.find("://") {
    None => dsn
    Some(at) => {
      let scheme = dsn.exact_view(end=at + 3)
      let rest = dsn.exact_view(start=at + 3)
      match rest.find("@") {
        None => dsn
        Some(userinfo_end) => {
          let userinfo = rest.exact_view(end=userinfo_end)
          let after = rest.exact_view(start=userinfo_end)
          match userinfo.find(":") {
            None => scheme.to_owned() + userinfo.to_owned() + after.to_owned()
            Some(colon) =>
              scheme.to_owned() +
              userinfo.exact_view(end=colon).to_owned() +
              ":***" +
              after.to_owned()
          }
        }
      }
    }
  }
}

///|
#derive(Eq, Debug)
pub(all) suberror Refused {
  Refused(text~ : String)
}

///|
pub extend Refused with Eq::{equal, not_equal}

///|
pub extend Refused with Debug::{to_repr}

///|
/// Read a `connections.toml`: a `[[connection]]` per connection, each with a
/// name, an engine, and a DSN. The file is Tom's, so a mistake in it says
/// which line.
pub fn load(text : String) -> Array[Connection] raise Refused {
  let root = @moontoml.loads(text) catch {
    err => raise Refused(text=json_failure(err))
  }
  let entries = match lookup(root, "connection") {
    None => []
    Some(v) =>
      match list_of(v) {
        Some(items) => items
        None => raise Refused(text="`connection` must be an array of tables")
      }
  }
  let out : Array[Connection] = []
  let seen : Map[String, Unit] = Map([])
  for entry in entries {
    let name = string_of(entry, "name")
    if name == "" {
      raise Refused(text="a connection has no name")
    }
    if seen.contains(name) {
      raise Refused(text="two connections are named " + name)
    }
    seen[name] = ()
    let engine_word = string_of(entry, "engine")
    let engine = match Engine::parse(engine_word) {
      Some(e) => e
      None =>
        raise Refused(
          text="connection " +
            name +
            " names an engine dbmux does not know: " +
            engine_word,
        )
    }
    let dsn = string_of(entry, "dsn")
    if dsn == "" {
      raise Refused(text="connection " + name + " has no dsn")
    }
    let production = bool_of(entry, "production", false)
    let read_only = bool_of(entry, "read_only", production)
    out.push({
      name,
      group: string_of(entry, "group"),
      engine,
      dsn,
      read_only,
      production,
      password_env: match lookup(entry, "password_env") {
        Some(v) => text_of(v)
        None => None
      },
      delimiter: match string_of(entry, "delimiter") {
        "" => ":"
        d => d
      },
    })
  }
  out
}

///|
fn json_failure(err : Error) -> String {
  "the connection file is not TOML: " + err.to_string()
}

///|
fn string_of(entry : @json.Json, key : String) -> String {
  match lookup(entry, key) {
    Some(v) =>
      match text_of(v) {
        Some(s) => s
        None => ""
      }
    None => ""
  }
}

///|
fn lookup(entry : @json.Json, key : String) -> @json.Json? {
  if entry is Object(map) {
    map.get(key)
  } else {
    None
  }
}

///|
fn text_of(v : @json.Json) -> String? {
  if v is String(s) {
    Some(s)
  } else {
    None
  }
}

///|
fn list_of(v : @json.Json) -> Array[@json.Json]? {
  if v is Array(items) {
    Some(items)
  } else {
    None
  }
}

///|
fn bool_of(entry : @json.Json, key : String, fallback : Bool) -> Bool {
  match lookup(entry, key) {
    Some(True) => true
    Some(False) => false
    _ => fallback
  }
}

///|
/// The connection a command line describes: a SQLite path, or a URL whose
/// scheme names the engine. An unknown shape is not guessed at.
pub fn of_target(target : String) -> Connection raise Refused {
  match Engine::of_dsn(target) {
    None =>
      raise Refused(
        text="cannot tell which engine " +
          target +
          " is: give a postgres://, mysql://, sqlserver:// or redis:// URL, or a .db file",
      )
    Some(engine) =>
      {
        name: target,
        group: "",
        engine,
        dsn: target,
        read_only: false,
        production: false,
        password_env: None,
        delimiter: ":",
      }
  }
}

///|
/// The file written when dbmux starts with no configuration: one commented
/// example per engine, so the shape is in front of the reader.
pub fn skeleton() -> String {
  let text =
    #|# One [[connection]] per database. `dbmux <name>` opens one; `dbmux` alone
    #|# lists them all. A production connection is read-only unless it says
    #|# `read_only = false`.
    #|
    #|[[connection]]
    #|name = "local"
    #|engine = "sqlite"
    #|dsn = "./app.db"
    #|
    #|[[connection]]
    #|name = "app"
    #|group = "staging"
    #|engine = "postgresql"
    #|dsn = "postgres://app@127.0.0.1:5432/app?sslmode=disable"
    #|password_env = "APP_PASSWORD"
    #|read_only = true
    #|
    #|[[connection]]
    #|name = "cache"
    #|engine = "redis"
    #|dsn = "redis://127.0.0.1:6379/0"
  text
}
