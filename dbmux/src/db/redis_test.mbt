// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a console line is cut into words, quotes and all" {
  assert_eq(@db.shell_words("GET greeting").length(), 2)
  assert_eq(@db.shell_words("SET k \"a b\""), ["SET", "k", "a b"])
  assert_eq(@db.shell_words("  HSET  user:1 name Ada  ").length(), 4)
  assert_eq(@db.shell_words("").length(), 0)
}

///|
test "a reply becomes rows: an array one each, a map two columns" {
  let array = @db.reply_rows(
    @resp.RespValue::Array([
      @resp.RespValue::BulkString(b"a"),
      @resp.RespValue::BulkString(b"b"),
    ]),
  )
  assert_eq(array.columns.length(), 1)
  assert_eq(array.rows.length(), 2)
  assert_eq(array.rows[0][0].text, "a")

  let map = @db.reply_rows(
    @resp.RespValue::RespMap([
      (
        @resp.RespValue::BulkString(b"name"),
        @resp.RespValue::BulkString(b"Ada"),
      ),
    ]),
  )
  assert_eq(map.columns.length(), 2)
  assert_eq(map.rows[0][1].text, "Ada")
}

///|
test "a nested array stays one row, so a line is a line" {
  let result = @db.reply_rows(
    @resp.RespValue::Array([
      @resp.RespValue::Array([
        @resp.RespValue::Integer(1L),
        @resp.RespValue::Integer(2L),
      ]),
    ]),
  )
  assert_eq(result.rows.length(), 1)
  assert_eq(result.rows[0][0].text, "1 2")
}

///|
test "a nil reply is a NULL cell, not an empty string" {
  let result = @db.reply_rows(@resp.RespValue::Null)
  assert_eq(result.rows[0][0].is_null, true)
}

///|
test "a password in the DSN is used when the caller holds none" {
  let endpoint = @db.Endpoint::{
    host: "127.0.0.1",
    port: 5432,
    user: "postgres",
    password: "dbmux",
    database: "shop",
    path: "",
    ssl: "",
  }
  assert_eq(@db.secret_of("", endpoint), "dbmux")
  assert_eq(@db.secret_of("from-env", endpoint), "from-env")
}
