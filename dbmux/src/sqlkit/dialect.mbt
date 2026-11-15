// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The SQL dialect a connection speaks. Redis is absent on purpose: it has no
/// SQL, so its console is matched against a command table instead.
#derive(Eq)
pub(all) enum Dialect {
  Postgres
  Mysql
  Sqlite
  SqlServer
}

///|
pub extend Dialect with Eq::{not_equal, equal}

///|
pub fn Dialect::name(self : Dialect) -> String {
  match self {
    Postgres => "postgresql"
    Mysql => "mysql"
    Sqlite => "sqlite"
    SqlServer => "sqlserver"
  }
}

///|
/// The dialect a configuration file names, by its engine word.
pub fn Dialect::parse(text : String) -> Dialect? {
  match text.to_lower() {
    "postgres" | "postgresql" | "pg" => Some(Postgres)
    "mysql" | "mariadb" => Some(Mysql)
    "sqlite" | "sqlite3" => Some(Sqlite)
    "sqlserver" | "mssql" | "sqls" => Some(SqlServer)
    _ => None
  }
}

///|
/// An identifier as the dialect wants it in generated SQL: doubled quotes
/// inside, and the dialect's own bracket pair outside.
pub fn Dialect::quote(self : Dialect, name : String) -> String {
  match self {
    Mysql => "`" + name.replace_all(old="`", new="``") + "`"
    SqlServer => "[" + name.replace_all(old="]", new="]]") + "]"
    _ => "\"" + name.replace_all(old="\"", new="\"\"") + "\""
  }
}

///|
/// `schema.table`, or the bare table when the schema is not part of the name.
pub fn Dialect::qualify(
  self : Dialect,
  schema : String?,
  table : String,
) -> String {
  match schema {
    Some(s) if s != "" => self.quote(s) + "." + self.quote(table)
    _ => self.quote(table)
  }
}

///|
/// A string literal, with the dialect's escaping. MySQL and SQL Server also
/// read a backslash as an escape unless the server was told not to, so the
/// backslash is doubled there.
pub fn Dialect::literal(self : Dialect, text : String) -> String {
  let body = match self {
    Mysql | SqlServer =>
      text.replace_all(old="\\", new="\\\\").replace_all(old="'", new="''")
    _ => text.replace_all(old="'", new="''")
  }
  "'" + body + "'"
}
