// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The one place that talks to jj. A log is asked for with a template that
// separates its fields with 0x1F, so parsing is splitting and not guessing at
// column widths; the graph comes before the fields on the same line, and a
// line that is only lanes is a merge being drawn.

///|
/// A command that did not answer. The text is what jj said, which is the only
/// useful thing to put on a status line.
pub(all) suberror Failed {
  Failed(text~ : String)
}

///|
/// The fields a row of the log carries, in order.
const SEPARATOR : String = "\u{1f}"

///|
/// The template: change, commit, author, date, bookmarks, parents, whether the
/// change is empty, and the first line of its description.
fn template() -> String {
  "change_id.short()" +
  " ++ \"\\x1f\" ++ commit_id.short()" +
  " ++ \"\\x1f\" ++ author.name()" +
  " ++ \"\\x1f\" ++ committer.timestamp().local().format(\"%Y-%m-%d %H:%M\")" +
  " ++ \"\\x1f\" ++ bookmarks.join(\",\")" +
  " ++ \"\\x1f\" ++ parents.map(|p| p.change_id().short()).join(\",\")" +
  " ++ \"\\x1f\" ++ if(empty, \"empty\", \"full\")" +
  " ++ \"\\x1f\" ++ description.first_line()"
}

///|
/// The jj to run: the one on the PATH, or the one `MBTJJ_JJ` names, which is
/// how a reader whose jj is somewhere else points the client at it.
fn program() -> String {
  match @env.get_env_var("MBTJJ_JJ") {
    Some(path) => if path == "" { "jj" } else { path }
    None => "jj"
  }
}

///|
/// Run jj in `root` and hand back what it wrote. A non-zero exit is a failure
/// with jj's own words, which a reader can act on.
async fn run(root : String, args : Array[String]) -> String raise Failed {
  // The repository is named on the command line rather than reached by a
  // working directory: a path with a space in it, or one written with forward
  // slashes on Windows, then needs no quoting of its own. The child inherits
  // the environment, so jj finds the reader's own config.
  let argv : Array[String] = ["--repository", root]
  for arg in args {
    argv.push(arg)
  }
  let (code, out, err) = @process.collect_output(
    program(),
    argv,
    inherit_env=true,
  ) catch {
    _ => raise Failed(text="cannot run jj — is it on PATH?")
  }
  let text = out.text() catch { _ => "" }
  if code != 0 {
    let said = err.text() catch { _ => "" }
    let said = said.trim(chars=" \r\n").to_owned()
    raise Failed(
      text=if said == "" { "jj exited with " + code.to_string() } else { said },
    )
  }
  text
}

///|
/// The log, as jj draws it. An empty revset leaves jj's own default alone.
pub async fn read_log(
  root : String,
  revset~ : String = "",
) -> Array[Row] raise Failed {
  let args : Array[String] = ["log", "--color=never", "-T", template()]
  if revset != "" {
    args.push("-r")
    args.push(revset)
  }
  parse_log(run(root, args))
}

///|
/// What one change does, in jj's own words.
pub async fn diff(
  root : String,
  change~ : String,
) -> Array[String] raise Failed {
  let text = run(root, ["diff", "-r", change, "--color=never"])
  lines_of(text)
}

///|
/// The operations the repository has seen, newest first.
pub async fn operations(
  root : String,
  count~ : Int32 = 30,
) -> Array[String] raise Failed {
  let text = run(root, ["op", "log", "--color=never", "-n", count.to_string()])
  lines_of(text)
}

///|
/// A block of text as the rows of a pane.
pub fn lines_of(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in text.split("\n") {
    out.push(trim_cr(line.to_owned()))
  }
  while out.length() > 0 && out[out.length() - 1] == "" {
    ignore(out.pop())
  }
  out
}

///|
fn trim_cr(line : String) -> String {
  if line.length() > 0 && line[line.length() - 1] == '\r' {
    line[0:line.length() - 1].to_owned()
  } else {
    line
  }
}

///|
/// The rows of a log a template was asked for.
pub fn parse_log(text : String) -> Array[Row] {
  let rows : Array[Row] = []
  for raw in text.split("\n") {
    let line = trim_cr(raw.to_owned())
    if line == "" {
      continue
    }
    let fields = split_fields(line)
    if fields.length() < 8 {
      // No fields: the line is lanes between two revisions, which is how a
      // merge is drawn.
      rows.push(Row::Lane(graph=line))
      continue
    }
    let (lanes, node, after, id) = split_graph(fields[0])
    if node == "" || id == "" {
      rows.push(Row::Lane(graph=line))
      continue
    }
    rows.push(
      Revision({
        lanes,
        node,
        after,
        change_id: id,
        commit_id: fields[1],
        author: fields[2],
        date: fields[3],
        bookmarks: split_list(fields[4]),
        parents: split_list(fields[5]),
        empty: fields[6] == "empty",
        description: fields[7],
      }),
    )
  }
  rows
}

///|
fn split_fields(line : String) -> Array[String] {
  let out : Array[String] = []
  for part in line.split(SEPARATOR) {
    out.push(part.to_owned())
  }
  out
}

///|
fn split_list(text : String) -> Array[String] {
  let out : Array[String] = []
  if text == "" {
    return out
  }
  for part in text.split(",") {
    let part = part.trim(chars=" ").to_owned()
    if part != "" {
      out.push(part)
    }
  }
  out
}

///|
/// The graph cells of one row, cut into the lanes before the node, the node,
/// the cells between the node and the change id, and the id. jj writes `│ ○ ` or
/// `○ │ `: the node is one of the four glyphs it marks a revision with,
/// wherever it sits on the line, and the id is the last word.
pub fn split_graph(head : String) -> (String, String, String, String) {
  let chars = head.to_array()
  let (start, id) = tail_word(head)
  for i in 0..<chars.length() {
    let c = String::from_array([chars[i]])
    if is_node(c) {
      let after_end = if start > i + 1 { start } else { i + 1 }
      return (head[0:i].to_owned(), c, head[i + 1:after_end].to_owned(), id)
    }
  }
  ("", "", "", head)
}

///|
/// The word a row ends with, and where it starts: a change id is lowercase
/// letters and digits, so the graph's own glyphs never reach into it.
fn tail_word(text : String) -> (Int32, String) {
  let chars = text.to_array()
  let mut start = chars.length()
  while start > 0 && is_word_char(chars[start - 1]) {
    start = start - 1
  }
  (start, text[start:chars.length()].to_owned())
}

///|
fn is_word_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
}

///|
fn is_node(glyph : String) -> Bool {
  glyph == "@" || glyph == "○" || glyph == "◆" || glyph == "×"
}
