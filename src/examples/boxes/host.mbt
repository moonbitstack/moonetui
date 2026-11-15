// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Six containers on one host: a list on the left with a dot for each state, the
// chosen one opened on the right — its id, image, uptime and ports, and the log
// it is writing. Nothing here talks to a daemon: the numbers are a function of
// the beat, so a frame test can name the row it stops.

///|
#derive(Eq)
pub(all) enum State {
  Running
  Restarting
  Exited
}

///|
pub extend State with Eq::{not_equal, equal}

///|
pub struct Box {
  name : String
  image : String
  ports : String
  id : String
  mut cpu : Int32
  mut mem : Int32
  mut state : State
  mut up : Int32
  mut logs : Array[(String, String, String)]
}

///|
pub struct Host {
  boxes : Array[Box]
  mut pick : Int32
  mut beat : Int32
  mut paused : Bool
  mut note : String
}

///|
fn box_of(
  name : String,
  image : String,
  ports : String,
  id : String,
  cpu : Int32,
  mem : Int32,
) -> Box {
  {
    name,
    image,
    ports,
    id,
    cpu,
    mem,
    state: Running,
    up: 60 * 24 * 2,
    logs: [],
  }
}

///|
pub fn Host::new() -> Host {
  let boxes : Array[Box] = [
    box_of("api-gateway", "ghcr.io/moon/api:0.4.2", "8080", "a1f9c2b", 1, 128),
    box_of("postgres", "postgres:17-alpine", "5432", "77de410", 12, 612),
    box_of("redis", "redis:7-alpine", "6379", "3c8ab92", 1, 48),
    box_of("worker", "ghcr.io/moon/worker:0.4", "-", "9f02d51", 34, 1204),
    box_of("stripe-cli", "stripe/stripe-cli:latest", "-", "5b7e13a", 0, 0),
    box_of("web", "ghcr.io/moon/web:0.4.2", "3000", "c4d9e07", 1, 96),
  ]
  for item in boxes {
    item.logs = script(item.name)
  }
  { boxes, pick: 0, beat: 0, paused: false, note: "r restarts · s stops", }
}

///|
/// A log for a container, the way one reads: a request, a slow query, a retry.
fn script(name : String) -> Array[(String, String, String)] {
  let out : Array[(String, String, String)] = []
  if name == "api-gateway" {
    out.push(("18:29:58", "info", "listening on :8080"))
    out.push(("18:30:02", "info", "GET /v1/orders 200 12ms"))
    out.push(("18:30:03", "warn", "retry stripe (1/3) 502"))
    out.push(("18:30:04", "info", "stripe ok, 2 attempts left"))
    out.push(("18:30:07", "info", "POST /v1/checkout 201 84ms"))
  } else if name == "postgres" {
    out.push(("18:29:41", "info", "database system is ready"))
    out.push(("18:30:02", "warn", "checkpoint starting: time"))
    out.push(("18:30:05", "info", "checkpoint complete: 612 mb"))
  } else if name == "redis" {
    out.push(("18:29:44", "info", "ready to accept connections"))
    out.push(("18:30:01", "info", "10 changes in 5 seconds"))
  } else if name == "worker" {
    out.push(("18:29:50", "info", "queue orders, concurrency 8"))
    out.push(("18:30:02", "info", "job 8412 sent in 240ms"))
    out.push(("18:30:02", "info", "job 8413 sent in 118ms"))
    out.push(("18:30:03", "error", "job 8414 failed: timeout"))
    out.push(("18:30:03", "warn", "backing off 4s"))
  } else if name == "stripe-cli" {
    out.push(("18:29:30", "info", "ready, listening for events"))
    out.push(("18:29:31", "info", "no events yet"))
  } else {
    out.push(("18:29:47", "info", "vite ready in 312ms"))
    out.push(("18:30:04", "info", "GET / 200 3ms"))
    out.push(("18:30:06", "info", "GET /assets/app.js 200 8ms"))
  }
  out
}

///|
pub fn Host::picked(self : Host) -> Box {
  self.boxes[self.pick]
}

///|
pub fn Host::shift(self : Host, delta : Int32) -> Unit {
  let next = self.pick + delta
  if next >= 0 && next < self.boxes.length() {
    self.pick = next
  }
}

///|
pub fn Host::running(self : Host) -> Int32 {
  let mut n = 0
  for item in self.boxes {
    if item.state == Running {
      n = n + 1
    }
  }
  n
}

///|
/// A restart: the state settles back to running after a moment, and the uptime
/// starts again from zero.
pub fn Host::restart(self : Host) -> Unit {
  let item = self.boxes[self.pick]
  item.state = Restarting
  item.up = 0
  item.logs.push(("18:30:09", "info", "restarting at the request of a reader"))
  self.note = "restarted " + item.name
}

///|
pub fn Host::stop(self : Host) -> Unit {
  let item = self.boxes[self.pick]
  item.state = Exited
  item.cpu = 0
  item.mem = 0
  item.logs.push(("18:30:09", "warn", "stopped by a reader"))
  self.note = "stopped " + item.name
}

///|
/// One beat: a restart finishes, uptimes grow, and a running container writes a
/// line of its own now and then.
pub fn Host::advance(self : Host) -> Unit {
  self.beat = self.beat + 1
  for item in self.boxes {
    if item.state == Restarting {
      item.state = Running
      item.up = 0
      item.logs.push(("18:30:12", "info", "up, healthy"))
    }
    if item.state == Running {
      item.up = item.up + 1
      if (self.beat + item.name.length()) % 4 == 0 {
        item.logs.push(
          (
            "18:30:" + two(10 + self.beat % 45),
            "info",
            "tick " + self.beat.to_string() + " ok",
          ),
        )
      }
    }
  }
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
pub fn Host::state_of(self : Host, index : Int32) -> State {
  self.boxes[index].state
}

///|
pub fn Host::logs_of(self : Host, index : Int32) -> Int32 {
  self.boxes[index].logs.length()
}

///|
pub fn Host::name_of(self : Host, index : Int32) -> String {
  self.boxes[index].name
}

///|
pub fn Host::pick(self : Host) -> Int32 {
  self.pick
}

///|
pub fn Host::pause(self : Host) -> Unit {
  self.paused = !self.paused
  self.note = if self.paused { "tail paused" } else { "tail running" }
}
