// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A live Redis connection: keys listed by `SCAN`, each key read as whatever
/// type it holds, and a console that sends whatever the reader typed.
pub struct Redis {
  client : @moonredis.Client
  db : Int32
}

///|
/// Connect to the address a `redis://` URL names. The database is the URL's
/// path — `/0` when it says nothing.
pub async fn Redis::open(dsn : String, password : String) -> Redis raise Failed {
  let endpoint = parse(dsn) catch {
    @config.Refused(text~) => raise Failed(text~)
  }
  let db = if endpoint.database == "" {
    0
  } else {
    @string.parse_int(endpoint.database) catch {
      _ => 0
    }
  }
  let mut options = @moonredis.ClientOptions::at(endpoint.host, endpoint.port)
  if password != "" {
    options = options.with_auth(None, Some(password))
  }
  options = options.with_db(db)
  let conn = @socket.Connection::connect(options) catch {
    e => raise Failed(text=redis_text(e))
  }
  { client: @moonredis.Client::new(conn), db, }
}

///|
/// The pattern the keys are listed by: what the reader typed on the filter
/// line, or `*` when they cleared it. Redis matches these itself, so `user:*`
/// asks the server for one family of keys instead of reading them all and
/// keeping some.
pub fn scan_pattern(filter : String) -> String {
  let pattern = filter.trim().to_owned()
  if pattern == "" {
    "*"
  } else {
    pattern
  }
}

///|
/// The keys a pattern matches, up to a limit, each with its type. `SCAN` walks
/// the keyspace in cursor steps, so a server with a million keys is not asked
/// for all of them at once.
pub async fn Redis::keys(
  self : Redis,
  pattern : String,
  limit : Int32,
) -> Array[(String, String)] raise Failed {
  let out : Array[(String, String)] = []
  let mut cursor = "0"
  let mut more = true
  while more && out.length() < limit {
    let (next, batch) = self.client.scan(cursor, pattern~, count=500) catch {
      e => raise Failed(text=redis_text(e))
    }
    for key in batch {
      if out.length() >= limit {
        break
      }
      let kind = self.client.type_(key) catch {
        e => raise Failed(text=redis_text(e))
      }
      out.push((key, kind))
    }
    cursor = next
    more = cursor != "0"
  }
  out
}

///|
/// One key as a small table: a string is one row, a hash two columns, a list
/// its indexes, a set its members, a sorted set its members and scores.
pub async fn Redis::view(self : Redis, key : String) -> Result raise Failed {
  let kind = self.client.type_(key) catch {
    e => raise Failed(text=redis_text(e))
  }
  match kind {
    "string" => {
      let value = self.client.get(key) catch {
        e => raise Failed(text=redis_text(e))
      }
      let cell = match value {
        None => @table.Cell::none()
        Some(bytes) => @table.Cell::of(utf8(bytes))
      }
      { columns: ["value"], rows: [[cell]], affected: 0L, }
    }
    "hash" => {
      let pairs = self.client.hgetall(key) catch {
        e => raise Failed(text=redis_text(e))
      }
      let rows : Array[Array[@table.Cell]] = []
      for (field, value) in pairs {
        rows.push([@table.Cell::of(field), @table.Cell::of(value)])
      }
      { columns: ["field", "value"], rows, affected: 0L, }
    }
    "list" => {
      let items = self.client.lrange(key, 0, 999) catch {
        e => raise Failed(text=redis_text(e))
      }
      let rows : Array[Array[@table.Cell]] = []
      let mut i = 0
      for item in items {
        rows.push([@table.Cell::of(i.to_string()), @table.Cell::of(utf8(item))])
        i = i + 1
      }
      { columns: ["index", "value"], rows, affected: 0L, }
    }
    "set" => {
      let items = self.client.smembers(key) catch {
        e => raise Failed(text=redis_text(e))
      }
      let rows : Array[Array[@table.Cell]] = []
      for item in items {
        rows.push([@table.Cell::of(item)])
      }
      { columns: ["member"], rows, affected: 0L, }
    }
    "zset" => {
      let items = self.client.zrange_scores(key, 0, 999) catch {
        e => raise Failed(text=redis_text(e))
      }
      let rows : Array[Array[@table.Cell]] = []
      for (name, score) in items {
        rows.push([@table.Cell::of(name), @table.Cell::of(score.to_string())])
      }
      { columns: ["member", "score"], rows, affected: 0L, }
    }
    _ => { columns: ["type"], rows: [[@table.Cell::of(kind)]], affected: 0L, }
  }
}

///|
/// A console line: the words of a command, sent as they are, with the reply
/// flattened into rows.
pub async fn Redis::command(self : Redis, line : String) -> Result raise Failed {
  let words = shell_words(line)
  if words.length() == 0 {
    raise Failed(text="nothing to send")
  }
  let args : Array[Bytes] = []
  for word in words {
    args.push(@moonredis.arg_string(word))
  }
  let reply = self.client.command(args) catch {
    e => raise Failed(text=redis_text(e))
  }
  reply_rows(reply)
}

///|
/// A reply as rows: an array is one row per element, a map is two columns,
/// and anything else is one row.
pub fn reply_rows(reply : @resp.RespValue) -> Result {
  match reply {
    @resp.RespValue::Array(items) | @resp.RespValue::RespSet(items) => {
      let rows : Array[Array[@table.Cell]] = []
      for item in items {
        rows.push(flatten(item))
      }
      { columns: ["value"], rows, affected: 0L, }
    }
    @resp.RespValue::RespMap(pairs) => {
      let rows : Array[Array[@table.Cell]] = []
      for (key, value) in pairs {
        rows.push([scalar(key), scalar(value)])
      }
      { columns: ["field", "value"], rows, affected: 0L, }
    }
    _ => { columns: ["value"], rows: [flatten(reply)], affected: 0L, }
  }
}

///|
/// One reply element as one row: a nested array becomes a single cell holding
/// its words, so a row is always one line.
fn flatten(value : @resp.RespValue) -> Array[@table.Cell] {
  match value {
    @resp.RespValue::Array(items) => {
      let parts : Array[String] = []
      for item in items {
        parts.push(scalar(item).text)
      }
      [@table.Cell::of(parts.join(" "))]
    }
    _ => [scalar(value)]
  }
}

///|
fn scalar(value : @resp.RespValue) -> @table.Cell {
  match value {
    @resp.RespValue::SimpleString(s) => @table.Cell::of(s)
    @resp.RespValue::Error(s) => @table.Cell::of(s)
    @resp.RespValue::BulkError(s) => @table.Cell::of(s)
    @resp.RespValue::Integer(n) => @table.Cell::of(n.to_string())
    @resp.RespValue::Double(d) => @table.Cell::of(d.to_string())
    @resp.RespValue::BigNumber(s) => @table.Cell::of(s)
    @resp.RespValue::Boolean(b) =>
      @table.Cell::of(if b { "true" } else { "false" })
    @resp.RespValue::BulkString(bytes) => @table.Cell::of(utf8(bytes))
    @resp.RespValue::VerbatimString(_, bytes) => @table.Cell::of(utf8(bytes))
    @resp.RespValue::Null => @table.Cell::none()
    @resp.RespValue::Push(items) => {
      let parts : Array[String] = []
      for item in items {
        parts.push(scalar(item).text)
      }
      @table.Cell::of(parts.join(" "))
    }
    _ => @table.Cell::of("(reply)")
  }
}

///|
/// A redis failure as a sentence: the message it carries, or the name of the
/// condition when it carries none.
fn redis_text(error : @moonredis.RedisError) -> String {
  match error {
    @moonredis.Reply(message) => message
    @moonredis.Connection(message) => message
    @moonredis.Protocol(message) => message
    @moonredis.Closed => "the connection is closed"
    @moonredis.Aborted => "the request was aborted"
  }
}

///|
fn utf8(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}

///|
/// A console line cut into words: spaces separate them, and a word may be
/// quoted with `'` or `"` when it has a space of its own.
pub fn shell_words(line : String) -> Array[String] {
  let out : Array[String] = []
  let word = StringBuilder()
  let mut quote = '\u{0}'
  for c in line {
    if quote != '\u{0}' {
      if c == quote {
        quote = '\u{0}'
      } else {
        word.write_char(c)
      }
    } else if c == '"' || c == '\'' {
      quote = c
    } else if c == ' ' || c == '\t' {
      if !word.is_empty() {
        out.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(c)
    }
  }
  if !word.is_empty() {
    out.push(word.to_string())
  }
  out
}
