// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Where a connection goes, taken apart from its URL: the driver packages take
/// host, port, user, password and database separately, and none of them parses
/// a DSN.
pub(all) struct Endpoint {
  host : String
  port : Int32
  user : String
  password : String
  database : String
  path : String
  ssl : String
}

///|
/// The port each engine listens on when the URL does not say.
pub fn default_port(engine : @config.Engine) -> Int32 {
  match engine {
    @config.Engine::Postgres => 5432
    @config.Engine::Mysql => 3306
    @config.Engine::SqlServer => 1433
    @config.Engine::Redis => 6379
    @config.Engine::Sqlite => 0
  }
}

///|
/// Split a DSN. A SQLite DSN is a file path and nothing else; the others are
/// `scheme://user:password@host:port/database?params`.
pub fn parse(dsn : String) -> Endpoint raise @config.Refused {
  match dsn.find("://") {
    None =>
      {
        host: "",
        port: 0,
        user: "",
        password: "",
        database: dsn,
        path: dsn,
        ssl: "",
      }
    Some(at) => {
      let scheme = dsn.exact_view(end=at).to_owned()
      let engine = match @config.Engine::parse(scheme) {
        Some(e) => e
        None => raise @config.Refused(text="unknown scheme: " + scheme)
      }
      let rest = dsn.exact_view(start=at + 3).to_owned()
      let (authority, tail) = match rest.find("/") {
        Some(slash) =>
          (
            rest.exact_view(end=slash).to_owned(),
            rest.exact_view(start=slash + 1).to_owned(),
          )
        None => (rest, "")
      }
      let (database, params) = match tail.find("?") {
        Some(q) =>
          (
            tail.exact_view(end=q).to_owned(),
            tail.exact_view(start=q + 1).to_owned(),
          )
        None => (tail, "")
      }
      let (userinfo, hostport) = match authority.find("@") {
        Some(at_) =>
          (
            authority.exact_view(end=at_).to_owned(),
            authority.exact_view(start=at_ + 1).to_owned(),
          )
        None => ("", authority)
      }
      let (user, password) = match userinfo.find(":") {
        Some(colon) =>
          (
            userinfo.exact_view(end=colon).to_owned(),
            userinfo.exact_view(start=colon + 1).to_owned(),
          )
        None => (userinfo, "")
      }
      let (host, port) = split_port(hostport, default_port(engine))
      {
        host,
        port,
        user: percent_decode(user),
        password: percent_decode(password),
        database,
        path: "",
        ssl: param(params, "sslmode"),
      }
    }
  }
}

///|
fn split_port(hostport : String, fallback : Int32) -> (String, Int32) {
  match hostport.find(":") {
    None => (hostport, fallback)
    Some(colon) => {
      let host = hostport.exact_view(end=colon).to_owned()
      let port_text = hostport.exact_view(start=colon + 1).to_owned()
      let port = @string.parse_int(port_text) catch { _ => fallback }
      (host, port)
    }
  }
}

///|
/// A query parameter, empty when it is not there.
pub fn param(params : String, key : String) -> String {
  for pair in params.split("&") {
    match pair.find("=") {
      Some(eq) =>
        if pair.exact_view(end=eq) == key {
          return pair.exact_view(start=eq + 1).to_owned()
        }
      None => ()
    }
  }
  ""
}

///|
/// A user name or password with its `%xx` escapes taken back out, so a
/// password with `@` or `/` in it survives the URL.
pub fn percent_decode(text : String) -> String {
  if !text.contains_char('%') {
    return text
  }
  let buf = StringBuilder()
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '%' && i + 2 < chars.length() {
      let hex = String::from_array([chars[i + 1], chars[i + 2]])
      let code = @string.parse_int(hex, base=16) catch { _ => -1 }
      if code >= 0 {
        buf.write_char(code.unsafe_to_char())
        i = i + 3
        continue
      }
    }
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}
