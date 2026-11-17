// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a log line is a graph, a node and the fields the template asked for" {
  let rows = @mbtjj.parse_log(@mbtjj.demo_log)
  // Nine lines: seven revisions and the two lanes a merge is drawn with.
  assert_eq(rows.length(), 9)
  let first = match rows[0] {
    Revision(change) => change
    Lane(_) => abort("the first row is a revision")
  }
  assert_eq(first.node, "@")
  assert_eq(first.change_id, "aaaaaaaabbbb")
  assert_eq(first.commit_id, "111111111111")
  assert_eq(first.author, "leo")
  assert_eq(first.date, "2026-11-17 19:41")
  assert_eq(first.bookmarks, ["main"])
  assert_eq(first.parents, ["ccccccccdddd", "eeeeeeeeffff"])
  assert_eq(first.empty, false)
  assert_eq(first.description, "feat: a frame redraws the rows that changed")
}

///|
test "the lane between two revisions is a row of its own" {
  let rows = @mbtjj.parse_log(@mbtjj.demo_log)
  match rows[1] {
    Lane(graph~) => assert_eq(graph, "├─╮  ")
    Revision(_) => abort("row 1 is a lane")
  }
  match rows[4] {
    Lane(graph~) => assert_eq(graph, "├─╯  ")
    Revision(_) => abort("row 3 is a lane")
  }
}

///|
test "the node is found wherever jj put it, and the lanes keep their order" {
  let (lanes, node, after, id) = @mbtjj.split_graph("○ │  aaaaaaaabbbb")
  assert_eq((lanes, node, after, id), ("", "○", " │  ", "aaaaaaaabbbb"))
  let (lanes, node, after, id) = @mbtjj.split_graph("│ ○  ccccccccdddd")
  assert_eq((lanes, node, after, id), ("│ ", "○", "  ", "ccccccccdddd"))
  let (lanes, node, after, id) = @mbtjj.split_graph("@    eeeeeeeeffff")
  assert_eq((lanes, node, after, id), ("", "@", "    ", "eeeeeeeeffff"))
}

///|
test "a revision with no description says so, and an empty one too" {
  let rows = @mbtjj.parse_log(@mbtjj.demo_log)
  let last = match rows[8] {
    Revision(change) => change
    Lane(_) => abort("the last row is a revision")
  }
  assert_eq(last.description, "root()")
  assert_eq(last.empty, true)
}

///|
test "the cursor starts on the working copy and the log follows it" {
  let repo = @mbtjj.Repo::new(".")
  repo.set_log(@mbtjj.parse_log(@mbtjj.demo_log))
  let pick = match repo.pick() {
    Some(change) => change
    None => abort("a revision under the cursor")
  }
  assert_eq(pick.node, "@")
  // Three rows down from the working copy, across a merge.
  repo.shift(1)
  repo.shift(1)
  repo.shift(1)
  let at = match repo.pick() {
    Some(change) => change
    None => abort("a revision under the cursor")
  }
  assert_eq(at.change_id, "gggggggghhhh")
}
