// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A table or a view as the catalog lists it.
pub(all) struct TableInfo {
  schema : String?
  name : String
  is_view : Bool
}

///|
/// A column, with the type the server gave it and whether it is part of the
/// primary key — the grid needs the key to write an UPDATE that names one row.
pub(all) struct ColumnInfo {
  name : String
  type_name : String
  nullable : Bool
  primary : Bool
}

///|
/// What one statement returned: columns and rows for a read, a count for a
/// write.
pub(all) struct Result {
  columns : Array[String]
  rows : Array[Array[@table.Cell]]
  affected : Int64
}

///|
/// A failure that reached the reader: the driver's own words, not a wrapper
/// invented here.
pub(all) suberror Failed {
  Failed(text~ : String)
}

///|
/// The live connection. One variant per driver, because each driver has its
/// own type; the methods below are the only place that sees the difference.
pub(all) enum Backend {
  Sqlite(@moonsqlite.SqliteDriver)
  Postgres(@moonpostgres.PgConn)
  Mysql(@client.MysqlConn)
  SqlServer(@moonsqls.SqlServerConn)
}

///|
pub struct Session {
  name : String
  engine : @config.Engine
  dialect : @sqlkit.Dialect
  read_only : Bool
  production : Bool
  mut backend : Backend?
}

///|
/// Open the connection the file named. The password is passed in rather than
/// read here, so where it comes from — the DSN, the environment, a command —
/// stays the caller's decision.
pub async fn Session::open(
  conn : @config.Connection,
  password : String,
) -> Session raise Failed {
  let endpoint = parse(conn.dsn) catch {
    @config.Refused(text~) => raise Failed(text~)
  }
  let dialect = match conn.engine.dialect() {
    Some(d) => d
    None => raise Failed(text="redis speaks no SQL")
  }
  let backend = match conn.engine {
    @config.Engine::Sqlite =>
      Backend::Sqlite(
        @moonsqlite.SqliteDriver::open(endpoint.path) catch {
          e => raise Failed(text=driver_text(e))
        },
      )
    @config.Engine::Postgres =>
      Backend::Postgres(
        @moonpostgres.PgConn::connect(
          endpoint.host,
          endpoint.port,
          endpoint.user,
          password,
          endpoint.database,
        ) catch {
          e => raise Failed(text=driver_text(e))
        },
      )
    @config.Engine::Mysql =>
      Backend::Mysql(
        @client.MysqlConn::connect(
          endpoint.host,
          endpoint.port,
          endpoint.user,
          password,
          endpoint.database,
        ) catch {
          e => raise Failed(text=driver_text(e))
        },
      )
    @config.Engine::SqlServer =>
      Backend::SqlServer(
        @moonsqls.SqlServerConn::connect(
          endpoint.host,
          endpoint.port,
          endpoint.user,
          password,
          endpoint.database,
        ) catch {
          e => raise Failed(text=driver_text(e))
        },
      )
    @config.Engine::Redis => raise Failed(text="redis speaks no SQL")
  }
  {
    name: conn.name,
    engine: conn.engine,
    dialect,
    read_only: conn.read_only,
    production: conn.production,
    backend: Some(backend),
  }
}

///|
/// A driver error as the sentence it already is.
fn driver_text(e : Error) -> String {
  e.to_string()
}

///|
pub async fn Session::close(self : Session) -> Unit {
  match self.backend {
    None => ()
    Some(Backend::Sqlite(driver)) => driver.close()
    Some(Backend::Postgres(conn)) => conn.close()
    Some(Backend::Mysql(conn)) => conn.close()
    Some(Backend::SqlServer(conn)) => conn.close()
  }
  self.backend = None
}

///|
/// Run one statement. A read returns rows; anything else returns the number of
/// rows it touched. The text is classified before it is sent, which is how a
/// read-only session refuses a write and how a dangerous one gets confirmed.
pub async fn Session::query(
  self : Session,
  sql : String,
) -> Result raise Failed {
  let reads = @sqlkit.is_read(sql, self.dialect)
  let backend = match self.backend {
    None => raise Failed(text="the connection is closed")
    Some(b) => b
  }
  if reads {
    let rows = match backend {
      Backend::Sqlite(driver) =>
        driver.query(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
      Backend::Postgres(conn) =>
        conn.query(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
      Backend::Mysql(conn) =>
        conn.query(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
      Backend::SqlServer(conn) =>
        conn.query(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
    }
    { columns: columns_of(rows), rows: cells_of(rows), affected: 0L, }
  } else {
    let affected = match backend {
      Backend::Sqlite(driver) =>
        driver.execute(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
      Backend::Postgres(conn) =>
        conn.execute(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
      Backend::Mysql(conn) =>
        conn.execute(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
      Backend::SqlServer(conn) =>
        conn.execute(sql, []) catch {
          e => raise Failed(text=driver_text(e))
        }
    }
    { columns: [], rows: [], affected: affected.rows_affected, }
  }
}

///|
/// The column names of the first row; one row is enough, and a result with no
/// rows has them from the driver's description.
fn columns_of(rows : Array[@moondb.Row]) -> Array[String] {
  if rows.length() == 0 {
    []
  } else {
    rows[0].columns
  }
}

///|
fn cells_of(rows : Array[@moondb.Row]) -> Array[Array[@table.Cell]] {
  let out : Array[Array[@table.Cell]] = []
  for row in rows {
    let line : Array[@table.Cell] = []
    let mut i = 0
    while i < row.values.length() {
      let value = row.values[i]
      line.push(
        match value {
          @moondb.Value::Null => @table.Cell::none()
          _ => @table.Cell::of(value.to_string())
        },
      )
      i = i + 1
    }
    out.push(line)
  }
  out
}

///|
/// Every statement of a save, in one transaction: it either all lands or none
/// of it does. A statement that matches a different number of rows than the
/// plan expected rolls the whole thing back, which is what catches a row that
/// someone else changed after it was read.
pub async fn Session::run(
  self : Session,
  statements : Array[String],
  expected : Array[Int64],
) -> Unit raise Failed {
  let backend = match self.backend {
    None => raise Failed(text="the connection is closed")
    Some(b) => b
  }
  begin(backend) catch {
    e => raise Failed(text=driver_text(e))
  }
  let mut done = 0
  for statement in statements {
    let affected = execute(backend, statement) catch {
      e => {
        rollback(backend) catch {
          _ => ()
        }
        raise Failed(text=driver_text(e))
      }
    }
    let want = if done < expected.length() { expected[done] } else { -1L }
    if want >= 0L && affected != want {
      rollback(backend) catch {
        _ => ()
      }
      raise Failed(
        text="row " +
          (done + 1).to_string() +
          " matched " +
          affected.to_string() +
          " rows, not " +
          want.to_string() +
          "; nothing was saved",
      )
    }
    done = done + 1
  }
  commit(backend) catch {
    e => {
      rollback(backend) catch {
        _ => ()
      }
      raise Failed(text=driver_text(e))
    }
  }
}

///|
async fn begin(backend : Backend) -> Unit {
  match backend {
    Backend::Sqlite(driver) => driver.begin()
    Backend::Postgres(conn) => conn.begin()
    Backend::Mysql(conn) => conn.begin()
    Backend::SqlServer(conn) => conn.begin()
  }
}

///|
async fn commit(backend : Backend) -> Unit {
  match backend {
    Backend::Sqlite(driver) => driver.commit()
    Backend::Postgres(conn) => conn.commit()
    Backend::Mysql(conn) => conn.commit()
    Backend::SqlServer(conn) => conn.commit()
  }
}

///|
async fn rollback(backend : Backend) -> Unit {
  match backend {
    Backend::Sqlite(driver) => driver.rollback()
    Backend::Postgres(conn) => conn.rollback()
    Backend::Mysql(conn) => conn.rollback()
    Backend::SqlServer(conn) => conn.rollback()
  }
}

///|
async fn execute(backend : Backend, sql : String) -> Int64 {
  let result = match backend {
    Backend::Sqlite(driver) => driver.execute(sql, [])
    Backend::Postgres(conn) => conn.execute(sql, [])
    Backend::Mysql(conn) => conn.execute(sql, [])
    Backend::SqlServer(conn) => conn.execute(sql, [])
  }
  result.rows_affected
}
