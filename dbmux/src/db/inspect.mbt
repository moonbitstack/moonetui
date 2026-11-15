// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The schemas the tree offers: one for SQLite, the server's own for the rest.
pub async fn Session::schemas(self : Session) -> Array[String] raise Failed {
  let result = self.query(schemas_sql(self.engine))
  let out : Array[String] = []
  for row in result.rows {
    if row.length() > 0 {
      out.push(row[0].text)
    }
  }
  out
}

///|
/// The tables and views of one schema, or of the default one.
pub async fn Session::tables(
  self : Session,
  schema : String?,
) -> Array[TableInfo] raise Failed {
  let result = self.query(tables_sql(self.engine, schema))
  let out : Array[TableInfo] = []
  for row in result.rows {
    if self.engine is @config.Engine::Sqlite {
      if row.length() >= 2 {
        out.push({
          schema: Some("main"),
          name: row[0].text,
          is_view: row[1].text.to_lower() == "view",
        })
      }
    } else if row.length() >= 3 {
      out.push({
        schema: Some(row[0].text),
        name: row[1].text,
        is_view: row[2].text.to_lower().contains("view"),
      })
    }
  }
  out
}

///|
/// The columns of a table, in the server's order, with the primary key
/// marked.
pub async fn Session::columns(
  self : Session,
  schema : String?,
  table : String,
) -> Array[ColumnInfo] raise Failed {
  let result = self.query(columns_sql(self.engine, schema, table))
  let out : Array[ColumnInfo] = []
  for row in result.rows {
    if row.length() >= 4 {
      out.push({
        name: row[0].text,
        type_name: row[1].text,
        nullable: row[2].text.to_lower() != "no",
        primary: row[3].text.to_upper() == "YES" ||
        row[3].text == "1" ||
        row[3].text.to_lower() == "true",
      })
    }
  }
  out
}

///|
/// One page of a table: its rows, and the key a save names a row by.
pub async fn Session::page(
  self : Session,
  q : @sqlkit.PageQuery,
) -> @table.Page raise Failed {
  let columns = self.columns(q.schema, q.table)
  let shown : Array[String] = []
  if q.columns.length() == 0 {
    for column in columns {
      shown.push(column.name)
    }
  } else {
    shown.append(q.columns)
  }
  let keys : Array[String] = []
  for column in columns {
    if column.primary {
      keys.push(column.name)
    }
  }
  let result = self.query(@sqlkit.page_sql(q, self.dialect))
  @table.Page::new(q.schema, q.table, shown, result.rows, keys)
}

///|
/// How many rows the filter matches, for the page count.
pub async fn Session::count(
  self : Session,
  q : @sqlkit.PageQuery,
) -> Int64 raise Failed {
  let result = self.query(@sqlkit.count_sql(q, self.dialect))
  if result.rows.length() > 0 && result.rows[0].length() > 0 {
    let text = result.rows[0][0].text
    let total = @string.parse_int64(text) catch { _ => 0L }
    total
  } else {
    0L
  }
}
