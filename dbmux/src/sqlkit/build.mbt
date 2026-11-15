// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One column's ordering. A table page is ordered by a list of these, the
/// first one deciding, the next breaking its ties.
pub(all) struct SortKey {
  column : String
  descending : Bool
}

///|
/// What a page of a table asks for. `columns` empty means every column,
/// `filter` is the user's WHERE text verbatim, and `offset` walks the pages.
pub(all) struct PageQuery {
  schema : String?
  table : String
  columns : Array[String]
  filter : String
  sorts : Array[SortKey]
  limit : Int32
  offset : Int64
}

///|
fn table_ref(q : PageQuery, dialect : Dialect) -> String {
  dialect.qualify(q.schema, q.table)
}

///|
fn where_clause(filter : String) -> String {
  let text = filter.trim().to_owned()
  if text == "" {
    ""
  } else {
    " WHERE (" + text + ")"
  }
}

///|
fn order_clause(sorts : Array[SortKey], dialect : Dialect) -> String {
  if sorts.length() == 0 {
    match dialect {
      // FETCH NEXT needs an ORDER BY; a constant orders nothing and costs nothing.
      SqlServer => " ORDER BY (SELECT NULL)"
      _ => ""
    }
  } else {
    let parts : Array[String] = []
    for key in sorts {
      parts.push(
        dialect.quote(key.column) +
        (if key.descending { " DESC" } else { " ASC" }),
      )
    }
    " ORDER BY " + parts.join(", ")
  }
}

///|
/// The page's SELECT. MySQL, SQLite and PostgreSQL take LIMIT/OFFSET;
/// SQL Server takes OFFSET/FETCH, which it only accepts after an ORDER BY.
pub fn page_sql(q : PageQuery, dialect : Dialect) -> String {
  let cols = if q.columns.length() == 0 {
    "*"
  } else {
    let quoted : Array[String] = []
    for c in q.columns {
      quoted.push(dialect.quote(c))
    }
    quoted.join(", ")
  }
  let head = "SELECT " + cols + " FROM " + table_ref(q, dialect)
  let window = match dialect {
    SqlServer =>
      " OFFSET " +
      q.offset.to_string() +
      " ROWS FETCH NEXT " +
      q.limit.to_string() +
      " ROWS ONLY"
    _ => " LIMIT " + q.limit.to_string() + " OFFSET " + q.offset.to_string()
  }
  head + where_clause(q.filter) + order_clause(q.sorts, dialect) + window
}

///|
/// How many rows the filter matches, for the page count in the status line.
pub fn count_sql(q : PageQuery, dialect : Dialect) -> String {
  "SELECT COUNT(*) FROM " + table_ref(q, dialect) + where_clause(q.filter)
}

///|
/// An assignment for an UPDATE's SET list or an INSERT's column list.
pub fn assign_sql(
  dialect : Dialect,
  column : String,
  value : String?,
) -> String {
  dialect.quote(column) + " = " + value_sql(dialect, value)
}

///|
/// An equality predicate. A NULL cannot be compared with `=`, so it is asked
/// for as `IS NULL`.
pub fn equal_sql(dialect : Dialect, column : String, value : String?) -> String {
  match value {
    None => dialect.quote(column) + " IS NULL"
    Some(_) => dialect.quote(column) + " = " + value_sql(dialect, value)
  }
}

///|
/// A value as SQL text. Everything is an untyped literal, which every engine
/// coerces to the column's own type; NULL is the word for it.
pub fn value_sql(dialect : Dialect, value : String?) -> String {
  match value {
    None => "NULL"
    Some(text) => dialect.literal(text)
  }
}

///|
/// One UPDATE, its SET list and its WHERE joined. The WHERE carries the old
/// values of the row, so a row someone else changed matches nothing.
pub fn update_sql(
  dialect : Dialect,
  table_ref_ : String,
  sets : Array[(String, String?)],
  predicates : Array[String],
) -> String {
  let parts : Array[String] = []
  for (column, value) in sets {
    parts.push(assign_sql(dialect, column, value))
  }
  let mut sql = "UPDATE " + table_ref_ + " SET " + parts.join(", ")
  if predicates.length() > 0 {
    sql = sql + " WHERE " + predicates.join(" AND ")
  }
  sql
}

///|
/// One INSERT of a whole row.
pub fn insert_sql(
  dialect : Dialect,
  table_ref_ : String,
  row : Array[(String, String?)],
) -> String {
  let cols : Array[String] = []
  let vals : Array[String] = []
  for (column, value) in row {
    cols.push(dialect.quote(column))
    vals.push(value_sql(dialect, value))
  }
  "INSERT INTO " +
  table_ref_ +
  " (" +
  cols.join(", ") +
  ") VALUES (" +
  vals.join(", ") +
  ")"
}

///|
/// One DELETE of one row, matched by the values it had when it was read.
pub fn delete_sql(table_ref_ : String, predicates : Array[String]) -> String {
  let mut sql = "DELETE FROM " + table_ref_
  if predicates.length() > 0 {
    sql = sql + " WHERE " + predicates.join(" AND ")
  }
  sql
}
