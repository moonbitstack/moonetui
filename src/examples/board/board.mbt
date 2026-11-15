// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A board of small panels, the way a personal dashboard is drawn: a clock, a
// calendar, a task list, the last commits, a load trace and the day's agenda,
// each in a frame of its own. Everything is a fixed function of the seconds
// that have passed, so the same board is drawn twice the same way.

///|
pub const PANELS : Int32 = 6

///|
pub struct Board {
  done : Array[Bool]
  mut cursor : Int32
  mut seconds : Int32
  mut beat : Int32
  mut load : Array[Double]
}

///|
/// Five things to do, and how far through them the day is.
let chores : Array[String] = [
  "frame test", "read the ci log", "release note", "patch review", "walk before dark",
]

///|
/// Six commits, newest first: a hash, a subject and whether it is pushed.
let commits : Array[(String, String, Bool)] = [
  ("6179281", "cards, felt", true),
  ("0d57b19", "mines & flags", true),
  ("10303ac", "seven pieces", true),
  ("48b8a17", "marching block", true),
  ("ca1ab9d", "Markdown page", true),
  ("71c0f2e", "width table", false),
]

///|
/// The day, as a person would keep it.
let agenda : Array[(String, String, String)] = [
  ("09:00", "standup", "15m"),
  ("11:00", "review", "45m"),
  ("13:30", "lunch Ana", "1h"),
  ("15:00", "writing", "2h"),
  ("19:00", "ship 0.4", "30m"),
]

///|
pub fn Board::new() -> Board {
  let done : Array[Bool] = []
  for i in 0..<chores.length() {
    done.push(i == 1)
  }
  let load : Array[Double] = []
  for i in 0..<28 {
    load.push(wave(i))
  }
  { done, cursor: 0, seconds: 18 * 3600 + 30 * 60, beat: 0, load, }
}

///|
/// A trace of load that looks measured: two waves of different length, so the
/// line never repeats in the width of the panel.
fn wave(at : Int32) -> Double {
  let a = (at * 13 % 40).to_double() / 40.0
  let b = (at * 7 % 23).to_double() / 23.0
  let v = 22.0 + a * 34.0 + b * 18.0
  if v > 88.0 {
    88.0
  } else {
    v
  }
}

///|
pub fn Board::done_count(self : Board) -> Int32 {
  let mut n = 0
  for on in self.done {
    if on {
      n = n + 1
    }
  }
  n
}

///|
pub fn Board::toggle(self : Board) -> Unit {
  self.done[self.cursor] = !self.done[self.cursor]
}

///|
/// The arrow keys walk the task list, and stop at its ends.
pub fn Board::shift(self : Board, delta : Int32) -> Unit {
  let next = self.cursor + delta
  if next >= 0 && next < self.done.length() {
    self.cursor = next
  }
}

///|
/// A refresh reads the machine again: the trace slides one step.
pub fn Board::refresh(self : Board) -> Unit {
  self.beat = self.beat + 1
  let next : Array[Double] = []
  for i in 1..<self.load.length() {
    next.push(self.load[i])
  }
  next.push(wave(self.load.length() + self.beat))
  self.load = next
}

///|
/// The clock, kept in seconds since midnight and wrapped at a day.
pub fn Board::tick(self : Board, ms : Int32) -> Unit {
  self.seconds = (self.seconds + ms / 1000) % 86400
}

///|
pub fn Board::clock_text(self : Board) -> String {
  two(self.seconds / 3600) +
  ":" +
  two(self.seconds / 60 % 60) +
  ":" +
  two(self.seconds % 60)
}

///|
fn two(value : Int32) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
pub fn Board::brief(self : Board) -> String {
  two(self.seconds / 3600) + ":" + two(self.seconds / 60 % 60)
}

///|
pub fn Board::seconds_text(self : Board) -> String {
  two(self.seconds % 60)
}

///|
pub fn Board::done_of(self : Board, index : Int32) -> Bool {
  self.done[index]
}
