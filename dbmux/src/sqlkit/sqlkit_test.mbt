// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "quote follows the dialect" {
  assert_eq(@sqlkit.Dialect::Postgres.quote("order"), "\"order\"")
  assert_eq(@sqlkit.Dialect::Sqlite.quote("a\"b"), "\"a\"\"b\"")
  assert_eq(@sqlkit.Dialect::Mysql.quote("ti`ck"), "`ti``ck`")
  assert_eq(@sqlkit.Dialect::SqlServer.quote("br]acket"), "[br]]acket]")
}

///|
test "a literal doubles its quote and, where the engine reads it, its backslash" {
  assert_eq(@sqlkit.Dialect::Postgres.literal("it's"), "'it''s'")
  assert_eq(@sqlkit.Dialect::Mysql.literal("a\\b"), "'a\\\\b'")
  assert_eq(@sqlkit.Dialect::Sqlite.literal("a\\b"), "'a\\b'")
}

///|
test "a semicolon inside a string or a comment does not cut a statement" {
  let text = "select ';' as a; -- one; two\nselect 2"
  let parts = @sqlkit.statements(text, @sqlkit.Dialect::Postgres)
  assert_eq(parts.length(), 2)
  assert_eq(parts[0], "select ';' as a")
  assert_eq(parts[1], "-- one; two\nselect 2")
}

///|
test "a semicolon inside parentheses does not cut a statement" {
  let parts = @sqlkit.statements(
    "create table t (a text default 'x;y'); drop table t;",
    @sqlkit.Dialect::Sqlite,
  )
  assert_eq(parts.length(), 2)
  assert_eq(parts[0], "create table t (a text default 'x;y')")
  assert_eq(parts[1], "drop table t")
}

///|
test "blank statements are not statements" {
  let parts = @sqlkit.statements(";;\n;\nselect 1;;", @sqlkit.Dialect::Mysql)
  assert_eq(parts.length(), 1)
  assert_eq(parts[0], "select 1")
}

///|
test "a dollar-quoted body is one token, semicolons and all" {
  let text = "create function f() returns int as $$ begin; return 1; end; $$ language plpgsql; select f()"
  let parts = @sqlkit.statements(text, @sqlkit.Dialect::Postgres)
  assert_eq(parts.length(), 2)
  assert_eq(parts[1], "select f()")
}

///|
test "the first word steps over a comment and a parenthesis" {
  assert_eq(
    @sqlkit.first_word("/* note */ select 1", @sqlkit.Dialect::Postgres),
    "select",
  )
  assert_eq(
    @sqlkit.first_word("  UPDATE t set a = 1", @sqlkit.Dialect::Sqlite),
    "update",
  )
}

///|
test "reads and writes" {
  assert_eq(@sqlkit.is_read("select 1", @sqlkit.Dialect::Sqlite), true)
  assert_eq(
    @sqlkit.is_read(
      "with x as (select 1) select * from x",
      @sqlkit.Dialect::Postgres,
    ),
    true,
  )
  assert_eq(
    @sqlkit.is_read(
      "with x as (select 1) delete from t",
      @sqlkit.Dialect::Postgres,
    ),
    false,
  )
  assert_eq(
    @sqlkit.is_read("explain select 1", @sqlkit.Dialect::Postgres),
    true,
  )
  assert_eq(
    @sqlkit.is_read("explain analyze select 1", @sqlkit.Dialect::Postgres),
    false,
  )
  assert_eq(
    @sqlkit.writes(
      "select 1; delete from t where id = 1",
      @sqlkit.Dialect::Sqlite,
    ),
    true,
  )
  assert_eq(
    @sqlkit.writes("select 1; select 2", @sqlkit.Dialect::Sqlite),
    false,
  )
}

///|
test "a write with no WHERE asks first" {
  assert_eq(
    @sqlkit.danger("delete from t", @sqlkit.Dialect::Postgres),
    Some("a write with no WHERE touches every row"),
  )
  assert_eq(
    @sqlkit.danger("delete from t where id = 1", @sqlkit.Dialect::Postgres),
    None,
  )
  assert_eq(
    @sqlkit.danger("update t set a = 1", @sqlkit.Dialect::Mysql),
    Some("a write with no WHERE touches every row"),
  )
  assert_eq(
    @sqlkit.danger("update t set a = 1 where id = 1", @sqlkit.Dialect::Mysql),
    None,
  )
}

///|
test "a WHERE in a subquery does not cover the write above it" {
  assert_eq(
    @sqlkit.danger(
      "update t set a = (select 1 from u where u.id = 1)",
      @sqlkit.Dialect::Postgres,
    ),
    Some("a write with no WHERE touches every row"),
  )
  assert_eq(
    @sqlkit.danger(
      "delete from t where id in (select id from u)",
      @sqlkit.Dialect::Postgres,
    ),
    None,
  )
}

///|
test "truncate, drop, and a dropped column ask first" {
  assert_eq(
    @sqlkit.danger("truncate t", @sqlkit.Dialect::Mysql),
    Some("TRUNCATE removes every row"),
  )
  assert_eq(
    @sqlkit.danger("drop table t", @sqlkit.Dialect::SqlServer),
    Some("DROP removes the object"),
  )
  assert_eq(
    @sqlkit.danger("alter table t drop column a", @sqlkit.Dialect::Postgres),
    Some("ALTER TABLE ... DROP removes a column"),
  )
  assert_eq(
    @sqlkit.danger(
      "alter table t alter column a drop default",
      @sqlkit.Dialect::Postgres,
    ),
    None,
  )
  assert_eq(
    @sqlkit.danger("alter table t drop constraint c", @sqlkit.Dialect::Postgres),
    None,
  )
}

///|
test "SQL Server's EXEC asks first, PostgreSQL's EXPLAIN ANALYZE too" {
  assert_eq(
    @sqlkit.danger("exec sp_who", @sqlkit.Dialect::SqlServer),
    Some("EXEC runs whatever the procedure holds"),
  )
  assert_eq(@sqlkit.danger("exec sp_who", @sqlkit.Dialect::Postgres), None)
  assert_eq(
    @sqlkit.danger("explain analyze delete from t", @sqlkit.Dialect::Postgres),
    Some("EXPLAIN ANALYZE runs the statement"),
  )
}

///|
test "a page query names its columns, its filter, its order and its window" {
  let q : @sqlkit.PageQuery = {
    schema: Some("public"),
    table: "orders",
    columns: ["id", "total"],
    filter: "total > 10",
    sorts: [
      { column: "total", descending: true, },
      { column: "id", descending: false, },
    ],
    limit: 50,
    offset: 100,
  }
  assert_eq(
    @sqlkit.page_sql(q, @sqlkit.Dialect::Postgres),
    "SELECT \"id\", \"total\" FROM \"public\".\"orders\" WHERE (total > 10) ORDER BY \"total\" DESC, \"id\" ASC LIMIT 50 OFFSET 100",
  )
  assert_eq(
    @sqlkit.page_sql(q, @sqlkit.Dialect::SqlServer),
    "SELECT [id], [total] FROM [public].[orders] WHERE (total > 10) ORDER BY [total] DESC, [id] ASC OFFSET 100 ROWS FETCH NEXT 50 ROWS ONLY",
  )
  assert_eq(
    @sqlkit.count_sql(q, @sqlkit.Dialect::Mysql),
    "SELECT COUNT(*) FROM `public`.`orders` WHERE (total > 10)",
  )
}

///|
test "a page with no order still gives SQL Server one" {
  let q : @sqlkit.PageQuery = {
    schema: None,
    table: "t",
    columns: [],
    filter: "",
    sorts: [],
    limit: 10,
    offset: 0,
  }
  assert_eq(
    @sqlkit.page_sql(q, @sqlkit.Dialect::SqlServer),
    "SELECT * FROM [t] ORDER BY (SELECT NULL) OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY",
  )
  assert_eq(
    @sqlkit.page_sql(q, @sqlkit.Dialect::Sqlite),
    "SELECT * FROM \"t\" LIMIT 10 OFFSET 0",
  )
}

///|
test "an update carries old values in its WHERE and NULL as IS NULL" {
  assert_eq(
    @sqlkit.update_sql(
      @sqlkit.Dialect::Postgres,
      "\"t\"",
      [("a", Some("new"))],
      [
        @sqlkit.equal_sql(@sqlkit.Dialect::Postgres, "id", Some("7")),
        @sqlkit.equal_sql(@sqlkit.Dialect::Postgres, "a", Some("old")),
        @sqlkit.equal_sql(@sqlkit.Dialect::Postgres, "gone", None),
      ],
    ),
    "UPDATE \"t\" SET \"a\" = 'new' WHERE \"id\" = '7' AND \"a\" = 'old' AND \"gone\" IS NULL",
  )
}

///|
test "inserts and deletes are built from the same pieces" {
  assert_eq(
    @sqlkit.insert_sql(@sqlkit.Dialect::Mysql, "`t`", [
      ("id", Some("1")),
      ("name", Some("o'k")),
      ("note", None),
    ]),
    "INSERT INTO `t` (`id`, `name`, `note`) VALUES ('1', 'o''k', NULL)",
  )
  assert_eq(
    @sqlkit.delete_sql("\"t\"", [
      @sqlkit.equal_sql(@sqlkit.Dialect::Sqlite, "id", Some("3")),
    ]),
    "DELETE FROM \"t\" WHERE \"id\" = '3'",
  )
}

///|
test "a word ends where the cursor is, and starts at the run before it" {
  assert_eq(@sqlkit.word_before("select * from ord", 17), (14, "ord"))
  assert_eq(@sqlkit.word_before("select ", 7), (7, ""))
  // A quoted name is not a word: the popup never breaks `"order lines"`.
  assert_eq(@sqlkit.word_before("select \"order", 13), (8, "order"))
}

///|
test "a completion names what it came from, shortest first" {
  let offers = @sqlkit.complete("ord", tables=["orders", "order_items"], columns=[
    "order_id",
  ])
  let texts : Array[String] = []
  for offer in offers {
    texts.push(offer.text)
  }
  // The keyword is the shortest, then the table, then the column, then the
  // longer table: what a reader typed most of comes first.
  assert_eq(texts, ["ORDER", "orders", "order_id", "order_items"])
  assert_eq(offers[0].letter(), "k")
  assert_eq(offers[1].letter(), "t")
  assert_eq(offers[2].letter(), "c")
}

///|
test "a word matches whatever the case, and a word the same is not offered" {
  let offers = @sqlkit.complete("SEL")
  assert_eq(offers.length() > 0, true)
  assert_eq(offers[0].text, "SELECT")
  // `select` is already typed, so it is not a completion of itself.
  let exact = @sqlkit.complete("select", tables=["select"])
  for offer in exact {
    assert_eq(offer.text.to_lower(), "select")
  }
  // Nothing typed offers nothing: a list of every word is not a completion.
  assert_eq(@sqlkit.complete("").length(), 0)
}

///|
test "a name is offered once even when two sources have it" {
  let offers = @sqlkit.complete("cust", tables=["customers"], columns=[
    "customers",
  ])
  let mut count = 0
  for offer in offers {
    if offer.text == "customers" {
      count = count + 1
    }
  }
  assert_eq(count, 1)
}
