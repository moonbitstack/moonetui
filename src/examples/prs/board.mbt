// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A pull request dashboard: the open requests, the checks on each of them, the
// card of the one the cursor is on, and what has happened on the repository
// underneath. The data is a fixture, so a frame test can merge #412 and read
// the line that says so.

///|
#derive(Eq)
pub(all) enum Review {
  Approved
  Waiting
  Changes
  Draft
  Merged
}

///|
pub extend Review with Eq::{not_equal, equal}

///|
#derive(Eq)
pub(all) enum Check {
  Pass
  Pending
  Fail
}

///|
pub extend Check with Eq::{not_equal, equal}

///|
pub struct Pull {
  number : Int32
  title : String
  author : String
  checks : Array[Check]
  mut review : Review
  branch : String
  added : Int32
  removed : Int32
  files : Int32
  commits : Int32
  comments : Int32
  age : String
}

///|
pub struct Board {
  pulls : Array[Pull]
  mut pick : Int32
  mut open : Bool
  mut note : String
  activity : Array[String]
}

///|
fn pull_of(
  number : Int32,
  title : String,
  author : String,
  checks : Array[Check],
  review : Review,
  branch : String,
  added : Int32,
  removed : Int32,
  files : Int32,
  commits : Int32,
  comments : Int32,
  age : String,
) -> Pull {
  {
    number,
    title,
    author,
    checks,
    review,
    branch,
    added,
    removed,
    files,
    commits,
    comments,
    age,
  }
}

///|
pub fn Board::new() -> Board {
  let pulls : Array[Pull] = [
    pull_of(
      412,
      "cards: a run lifted from a column",
      "heke",
      [Pass, Pass, Pass],
      Approved,
      "cards/lift",
      412,
      88,
      4,
      3,
      1,
      "2h",
    ),
    pull_of(
      409,
      "boxes: a tail that runs bottom up",
      "ana",
      [Pass, Fail, Pass],
      Waiting,
      "boxes/tail",
      286,
      140,
      3,
      5,
      7,
      "5h",
    ),
    pull_of(
      405,
      "board: six framed panels",
      "kai",
      [Pass, Pending, Pending],
      Waiting,
      "board/panels",
      604,
      12,
      6,
      2,
      3,
      "1d",
    ),
    pull_of(
      398,
      "drift: a trader in the dark",
      "heke",
      [Pending, Pending, Pending],
      Draft,
      "drift/map",
      918,
      4,
      9,
      11,
      0,
      "3d",
    ),
    pull_of(
      391,
      "read: set a table with type",
      "ana",
      [Pass, Pass, Fail],
      Changes,
      "read/tables",
      176,
      64,
      2,
      4,
      12,
      "4d",
    ),
  ]
  {
    pulls,
    pick: 0,
    open: true,
    note: "space folds the card",
    activity: [
      "09:12  ana   approved #412", "08:40  ci    #409 failed: lint", "08:02  kai   pushed 2 commits to #405",
      "07:31  heke  opened #412", "yesterday  ana  asked for changes on #391",
    ],
  }
}

///|
pub fn Board::shift(self : Board, delta : Int32) -> Unit {
  let next = self.pick + delta
  if next >= 0 && next < self.pulls.length() {
    self.pick = next
  }
}

///|
pub fn Board::fold(self : Board) -> Unit {
  self.open = !self.open
  self.note = if self.open { "card open" } else { "card folded" }
}

///|
/// Merging a request: its review turns to merged, its checks to passed, and the
/// activity list gains the line a reader would look for.
pub fn Board::merge(self : Board) -> Unit {
  let pull = self.pulls[self.pick]
  if pull.review == Merged {
    self.note = "#" + pull.number.to_string() + " is already merged"
    return
  }
  if pull.review == Draft {
    self.note = "#" + pull.number.to_string() + " is a draft"
    return
  }
  pull.review = Merged
  for i in 0..<pull.checks.length() {
    pull.checks[i] = Pass
  }
  self.note = "merged #" + pull.number.to_string()
  self.activity.push("now    heke  merged #" + pull.number.to_string())
}

///|
pub fn Board::count(self : Board, of : Review) -> Int32 {
  let mut n = 0
  for pull in self.pulls {
    if pull.review == of {
      n = n + 1
    }
  }
  n
}

///|
pub fn Board::pick(self : Board) -> Int32 {
  self.pick
}

///|
pub fn Board::review_of(self : Board, index : Int32) -> Review {
  self.pulls[index].review
}

///|
pub fn Board::number_of(self : Board, index : Int32) -> Int32 {
  self.pulls[index].number
}

///|
pub fn Board::open_card(self : Board) -> Bool {
  self.open
}
