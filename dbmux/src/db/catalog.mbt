// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The catalog queries each engine answers its own way. SQLite has no
/// `information_schema` and no schemas beyond `main`; the three servers do,
/// and each spells the primary key differently.
pub fn tables_sql(engine : @config.Engine, schema : String?) -> String {
  match engine {
    @config.Engine::Sqlite =>
      "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' ORDER BY name"
    @config.Engine::Postgres => {
      let clause = match schema {
        Some(s) => "table_schema = " + @sqlkit.Dialect::Postgres.literal(s)
        None => "table_schema NOT IN ('pg_catalog', 'information_schema')"
      }
      "SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE " +
      clause +
      " ORDER BY table_schema, table_name"
    }
    @config.Engine::Mysql => {
      let clause = match schema {
        Some(s) => "table_schema = " + @sqlkit.Dialect::Mysql.literal(s)
        None => "table_schema = DATABASE()"
      }
      "SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE " +
      clause +
      " ORDER BY table_name"
    }
    @config.Engine::SqlServer => {
      let clause = match schema {
        Some(s) => "TABLE_SCHEMA = " + @sqlkit.Dialect::SqlServer.literal(s)
        None => "TABLE_SCHEMA NOT IN ('sys', 'INFORMATION_SCHEMA')"
      }
      "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES WHERE " +
      clause +
      " ORDER BY TABLE_SCHEMA, TABLE_NAME"
    }
    @config.Engine::Redis => ""
  }
}

///|
/// The columns of one table, with their types, in the order the server keeps
/// them, and which of them make up the primary key.
pub fn columns_sql(
  engine : @config.Engine,
  schema : String?,
  table : String,
) -> String {
  match engine {
    @config.Engine::Sqlite =>
      "SELECT name, type, \"notnull\", pk FROM pragma_table_info(" +
      @sqlkit.Dialect::Sqlite.literal(table) +
      ")"
    @config.Engine::Postgres => {
      let owner = "table_name = " + @sqlkit.Dialect::Postgres.literal(table)
      let schema_clause = match schema {
        Some(s) => " AND table_schema = " + @sqlkit.Dialect::Postgres.literal(s)
        None => ""
      }
      // The key is a separate question: a column is in it when its name is in
      // the primary key's constraint, which pg_index answers in one place.
      "SELECT c.column_name, c.data_type, c.is_nullable, " +
      "CASE WHEN pk.column_name IS NULL THEN 'NO' ELSE 'YES' END " +
      "FROM information_schema.columns c LEFT JOIN (" +
      "  SELECT kcu.column_name, kcu.table_schema, kcu.table_name " +
      "  FROM information_schema.table_constraints tc " +
      "  JOIN information_schema.key_column_usage kcu " +
      "    ON kcu.constraint_name = tc.constraint_name " +
      "   AND kcu.table_schema = tc.table_schema " +
      "   AND kcu.table_name = tc.table_name " +
      "  WHERE tc.constraint_type = 'PRIMARY KEY') pk " +
      "  ON pk.column_name = c.column_name " +
      " AND pk.table_schema = c.table_schema AND pk.table_name = c.table_name " +
      "WHERE " +
      owner +
      schema_clause +
      " ORDER BY c.ordinal_position"
    }
    @config.Engine::Mysql => {
      let owner = "c.table_name = " + @sqlkit.Dialect::Mysql.literal(table)
      let schema_clause = match schema {
        Some(s) => " AND c.table_schema = " + @sqlkit.Dialect::Mysql.literal(s)
        None => " AND c.table_schema = DATABASE()"
      }
      "SELECT c.column_name, c.column_type, c.is_nullable, " +
      "CASE WHEN c.column_key = 'PRI' THEN 'YES' ELSE 'NO' END " +
      "FROM information_schema.columns c WHERE " +
      owner +
      schema_clause +
      " ORDER BY c.ordinal_position"
    }
    @config.Engine::SqlServer => {
      let owner = "c.TABLE_NAME = " + @sqlkit.Dialect::SqlServer.literal(table)
      let schema_clause = match schema {
        Some(s) =>
          " AND c.TABLE_SCHEMA = " + @sqlkit.Dialect::SqlServer.literal(s)
        None => ""
      }
      "SELECT c.COLUMN_NAME, c.DATA_TYPE, c.IS_NULLABLE, " +
      "CASE WHEN pk.COLUMN_NAME IS NULL THEN 'NO' ELSE 'YES' END " +
      "FROM INFORMATION_SCHEMA.COLUMNS c LEFT JOIN (" +
      "  SELECT kcu.COLUMN_NAME, kcu.TABLE_SCHEMA, kcu.TABLE_NAME " +
      "  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc " +
      "  JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu " +
      "    ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME " +
      "   AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA " +
      "   AND kcu.TABLE_NAME = tc.TABLE_NAME " +
      "  WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY') pk " +
      "  ON pk.COLUMN_NAME = c.COLUMN_NAME " +
      " AND pk.TABLE_SCHEMA = c.TABLE_SCHEMA AND pk.TABLE_NAME = c.TABLE_NAME " +
      "WHERE " +
      owner +
      schema_clause +
      " ORDER BY c.ORDINAL_POSITION"
    }
    @config.Engine::Redis => ""
  }
}

///|
/// The schemas or databases worth listing in the tree. SQLite has one; the
/// servers keep theirs in `information_schema`.
pub fn schemas_sql(engine : @config.Engine) -> String {
  match engine {
    @config.Engine::Sqlite => "SELECT 'main'"
    @config.Engine::Postgres =>
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema') ORDER BY schema_name"
    @config.Engine::Mysql =>
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys') ORDER BY schema_name"
    @config.Engine::SqlServer =>
      "SELECT name FROM sys.schemas WHERE name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest') ORDER BY name"
    @config.Engine::Redis => ""
  }
}
