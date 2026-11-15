// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A trader working six ports on a chart: the chart with the ship's position and
// the course it has set, the market at the port it is in, and the hold. Prices
// are a function of the port and the good, so the same port always pays the
// same, and a jump costs fuel measured off the chart.

///|
pub const GOODS : Int32 = 4

///|
pub const HOLD : Int32 = 20

///|
pub const FUEL : Int32 = 10

///|
let names : Array[String] = ["water", "ore", "medicine", "spice"]

///|
let bases : Array[Int32] = [12, 38, 90, 64]

///|
pub struct Port {
  code : String
  name : String
  x : Int32
  y : Int32
}

///|
pub struct Ship {
  ports : Array[Port]
  mut here : Int32
  mut course : Int32
  mut credits : Int32
  mut fuel : Int32
  mut hull : Int32
  bay : Array[Int32]
  mut good : Int32
  mut note : String
  mut log : Array[String]
  mut jumps : Int32
}

///|
pub fn Ship::new() -> Ship {
  let ports : Array[Port] = [
    { code: "sol", name: "Sol", x: 2, y: 3, },
    { code: "kep", name: "Kepler", x: 10, y: 3, },
    { code: "rig", name: "Rigel", x: 22, y: 3, },
    { code: "veg", name: "Vega", x: 10, y: 0, },
    { code: "den", name: "Deneb", x: 2, y: 6, },
    { code: "alt", name: "Altair", x: 22, y: 6, },
  ]
  let bay : Array[Int32] = []
  for _ in 0..<GOODS {
    bay.push(0)
  }
  {
    ports,
    here: 0,
    course: 1,
    credits: 1240,
    fuel: 8,
    hull: 92,
    bay,
    good: 0,
    note: "j jumps · b buys · s sells",
    log: ["signed on at sol with 1,240 credits"],
    jumps: 0,
  }
}

///|
pub fn Ship::held(self : Ship) -> Int32 {
  let mut total = 0
  for count in self.bay {
    total = total + count
  }
  total
}

///|
/// What a good costs at a port: a base price moved by the port's own weather,
/// so ore is dear at Rigel and cheap at Deneb, and always the same either way.
pub fn price_at(port : Int32, good : Int32) -> Int32 {
  let swing = (port * 7 + good * 5) % 9 - 4
  let price = bases[good] + swing * bases[good] / 20
  if price < 1 {
    1
  } else {
    price
  }
}

///|
pub fn Ship::price(self : Ship, good : Int32) -> Int32 {
  price_at(self.here, good)
}

///|
/// How much fuel a jump to a port costs: a hop within a neighbouring column is
/// one, a crossing is three.
pub fn Ship::cost_to(self : Ship, port : Int32) -> Int32 {
  let from = self.ports[self.here]
  let to = self.ports[port]
  let dx = (from.x - to.x).abs()
  let dy = (from.y - to.y).abs()
  let span = (dx + dy) / 6
  if span < 1 {
    1
  } else {
    span
  }
}

///|
pub fn Ship::walk(self : Ship, delta : Int32) -> Unit {
  let n = self.ports.length()
  self.course = (self.course + delta + n) % n
}

///|
pub fn Ship::pick(self : Ship, delta : Int32) -> Unit {
  let next = self.good + delta
  if next >= 0 && next < GOODS {
    self.good = next
  }
}

///|
pub fn Ship::buy(self : Ship) -> Unit {
  if self.held() >= HOLD {
    self.note = "the hold is full"
    return
  }
  let price = self.price(self.good)
  if self.credits < price {
    self.note = "not enough credits for " + names[self.good]
    return
  }
  self.credits = self.credits - price
  self.bay[self.good] = self.bay[self.good] + 1
  self.note = "bought " + names[self.good] + " at " + price.to_string()
  self.record(self.note)
}

///|
pub fn Ship::sell(self : Ship) -> Unit {
  if self.bay[self.good] == 0 {
    self.note = "no " + names[self.good] + " in the hold"
    return
  }
  let price = self.price(self.good)
  self.credits = self.credits + price
  self.bay[self.good] = self.bay[self.good] - 1
  self.note = "sold " + names[self.good] + " at " + price.to_string()
  self.record(self.note)
}

///|
/// A jump: the fuel is spent, the ship is where the course pointed, and the
/// hull takes a little of the crossing.
pub fn Ship::jump(self : Ship) -> Unit {
  if self.course == self.here {
    self.note = "the ship is already at " + self.ports[self.here].name
    return
  }
  let cost = self.cost_to(self.course)
  if self.fuel < cost {
    self.note = "not enough fuel: " + cost.to_string() + " needed"
    return
  }
  self.fuel = self.fuel - cost
  self.here = self.course
  self.jumps = self.jumps + 1
  if self.hull > 40 {
    self.hull = self.hull - 4
  }
  self.note = "docked at " + self.ports[self.here].name
  self.record(self.note)
}

///|
/// A port is a day's work: it sells fuel, and it patches the hull, at a price.
pub fn Ship::refuel(self : Ship) -> Unit {
  if self.fuel >= FUEL {
    self.note = "the tanks are full"
    return
  }
  if self.credits < 40 {
    self.note = "fuel is 40 credits"
    return
  }
  self.credits = self.credits - 40
  self.fuel = self.fuel + 1
  self.note = "one unit of fuel"
  self.record(self.note)
}

///|
pub fn Ship::patch(self : Ship) -> Unit {
  if self.hull >= 100 {
    self.note = "the hull is sound"
    return
  }
  if self.credits < 120 {
    self.note = "a patch is 120 credits"
    return
  }
  self.credits = self.credits - 120
  self.hull = self.hull + 8
  if self.hull > 100 {
    self.hull = 100
  }
  self.note = "hull patched"
  self.record(self.note)
}

///|
/// A line in the logbook, kept to the last six.
fn Ship::record(self : Ship, line : String) -> Unit {
  self.log.push(line)
  if self.log.length() > 6 {
    let kept : Array[String] = []
    for i in 1..<self.log.length() {
      kept.push(self.log[i])
    }
    self.log = kept
  }
}

///|
pub fn Ship::wealth(self : Ship) -> Int32 {
  let mut worth = self.credits
  for good in 0..<GOODS {
    worth = worth + self.bay[good] * bases[good]
  }
  worth
}
