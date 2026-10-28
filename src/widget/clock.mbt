// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A time of day that counts itself forward from the frames it is given, so a
/// clock runs off the same `Tick` every other widget sees and needs no clock
/// of the host's.
pub(all) struct Clock {
  mut hour : Int32
  mut minute : Int32
  mut second : Int32
  mut carry : Int32
} derive(Eq, Debug)

///|
pub fn Clock::new(
  hour~ : Int32 = 0,
  minute~ : Int32 = 0,
  second~ : Int32 = 0,
) -> Clock {
  {
    hour: wrap(hour, 24),
    minute: wrap(minute, 60),
    second: wrap(second, 60),
    carry: 0,
  }
}

///|
/// The time as it is shown: hours, minutes and seconds, two digits each.
pub fn Clock::text(self : Clock) -> String {
  two(self.hour) + ":" + two(self.minute) + ":" + two(self.second)
}

///|
pub fn Clock::set(
  self : Clock,
  hour~ : Int32,
  minute~ : Int32,
  second~ : Int32,
) -> Unit {
  self.hour = wrap(hour, 24)
  self.minute = wrap(minute, 60)
  self.second = wrap(second, 60)
  self.carry = 0
}

///|
pub fn Clock::hour(self : Clock) -> Int32 {
  self.hour
}

///|
pub fn Clock::minute(self : Clock) -> Int32 {
  self.minute
}

///|
pub fn Clock::second(self : Clock) -> Int32 {
  self.second
}

///|
/// Seconds since midnight, which is what two clocks are compared by.
pub fn Clock::seconds(self : Clock) -> Int32 {
  self.hour * 3600 + self.minute * 60 + self.second
}

///|
/// Move on by `ms` milliseconds, answering whether the time it shows changed,
/// which is all a caller needs to know to ask for a frame.
pub fn Clock::advance(self : Clock, ms : Int32) -> Bool {
  if ms <= 0 {
    return false
  }
  self.carry = self.carry + ms
  if self.carry < 1000 {
    return false
  }
  let ticks = self.carry / 1000
  self.carry = self.carry % 1000
  let mut at = self.seconds() + ticks
  at = wrap(at, 86400)
  self.hour = at / 3600
  self.minute = at % 3600 / 60
  self.second = at % 60
  true
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
fn wrap(value : Int32, span : Int32) -> Int32 {
  if span <= 0 {
    return 0
  }
  let at = value % span
  if at < 0 {
    at + span
  } else {
    at
  }
}

///|
pub extend Clock with Debug::{to_repr}

///|
pub extend Clock with Eq::{not_equal, equal}
