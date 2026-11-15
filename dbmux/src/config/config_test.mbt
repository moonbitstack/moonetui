// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the connection file reads names, engines and groups" {
  let text =
    #|[[connection]]
    #|name = "local"
    #|engine = "sqlite"
    #|dsn = "./app.db"
    #|
    #|[[connection]]
    #|name = "app"
    #|group = "staging"
    #|engine = "postgresql"
    #|dsn = "postgres://app@127.0.0.1:5432/app"
    #|read_only = true
  let list = @config.load(text)
  assert_eq(list.length(), 2)
  assert_eq(list[0].name, "local")
  assert_eq(list[0].engine, @config.Engine::Sqlite)
  assert_eq(list[0].read_only, false)
  assert_eq(list[1].group, "staging")
  assert_eq(list[1].read_only, true)
}

///|
test "a production connection is read-only unless the file says otherwise" {
  let text =
    #|[[connection]]
    #|name = "prod"
    #|engine = "mysql"
    #|dsn = "mysql://root@127.0.0.1:3306/app"
    #|production = true
  let list = @config.load(text)
  assert_eq(list[0].production, true)
  assert_eq(list[0].read_only, true)
  let writable =
    #|[[connection]]
    #|name = "prod"
    #|engine = "mysql"
    #|dsn = "mysql://root@127.0.0.1:3306/app"
    #|production = true
    #|read_only = false
  assert_eq(@config.load(writable)[0].read_only, false)
}

///|
test "a mistake in the file says what is wrong" {
  let no_name =
    #|[[connection]]
    #|engine = "sqlite"
    #|dsn = "./app.db"
  assert_eq(
    try {
      ignore(@config.load(no_name))
      "loaded"
    } catch {
      Refused(text~) => text
    },
    "a connection has no name",
  )
  let bad_engine =
    #|[[connection]]
    #|name = "x"
    #|engine = "oracle"
    #|dsn = "x"
  assert_eq(
    try {
      ignore(@config.load(bad_engine))
      "loaded"
    } catch {
      Refused(text~) => text
    },
    "connection x names an engine dbmux does not know: oracle",
  )
  let twice =
    #|[[connection]]
    #|name = "x"
    #|engine = "sqlite"
    #|dsn = "a.db"
    #|
    #|[[connection]]
    #|name = "x"
    #|engine = "sqlite"
    #|dsn = "b.db"
  assert_eq(
    try {
      ignore(@config.load(twice))
      "loaded"
    } catch {
      Refused(text~) => text
    },
    "two connections are named x",
  )
}

///|
test "a URL names its engine, and a bare word does not" {
  assert_eq(
    @config.Engine::of_dsn("postgres://h/db"),
    Some(@config.Engine::Postgres),
  )
  assert_eq(
    @config.Engine::of_dsn("redis://h:6379/0"),
    Some(@config.Engine::Redis),
  )
  assert_eq(
    @config.Engine::of_dsn("./app.sqlite"),
    Some(@config.Engine::Sqlite),
  )
  assert_eq(@config.Engine::of_dsn("app.db"), Some(@config.Engine::Sqlite))
  assert_eq(@config.Engine::of_dsn("h"), None)
}

///|
test "a DSN shown to the reader has no password" {
  assert_eq(
    @config.redact("postgres://app:s3cret@127.0.0.1:5432/app"),
    "postgres://app:***@127.0.0.1:5432/app",
  )
  assert_eq(
    @config.redact("postgres://app@127.0.0.1/app"),
    "postgres://app@127.0.0.1/app",
  )
  assert_eq(@config.redact("./app.db"), "./app.db")
}

///|
test "the skeleton is a file the reader can keep" {
  let list = @config.load(@config.skeleton())
  assert_eq(list.length(), 3)
  assert_eq(list[2].engine, @config.Engine::Redis)
}
