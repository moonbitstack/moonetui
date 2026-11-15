// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A route to walk, three creatures in the party, and what comes out of the tall
// grass. Every fourth step into grass is an encounter, and the turns are a
// fixed table, so a frame test can walk in, hit twice, and read the result.

///|
pub const WIDE : Int32 = 20

///|
pub const TALL : Int32 = 8

///|
#derive(Eq)
pub(all) enum Mode {
  Walk
  Fight
  Won
}

///|
pub extend Mode with Eq::{not_equal, equal}

///|
pub struct Beast {
  name : String
  mut level : Int32
  mut hp : Int32
  most : Int32
}

///|
pub struct Field {
  mut x : Int32
  mut y : Int32
  mut steps : Int32
  party : Array[Beast]
  mut lead : Int32
  mut mode : Mode
  mut enemy : String
  mut enemy_hp : Int32
  mut enemy_most : Int32
  mut turn : Int32
  mut log : Array[String]
  mut caught : Int32
  mut seen : Int32
  badges : Int32
  mut potions : Int32
}

///|
/// The route: open grass, two bands of tall grass to hide in, a stream and the
/// path that crosses it.
fn tile_at(x : Int32, y : Int32) -> String {
  if x < 0 || y < 0 || x >= WIDE || y >= TALL {
    return " "
  }
  if y == 0 || y == TALL - 1 {
    return "T"
  }
  if x == 9 || x == 10 {
    if y == 4 {
      return "="
    }
    return "~"
  }
  if (y == 2 || y == 5) && x > 1 && x < WIDE - 2 {
    return ":"
  }
  if x == 4 && y == 6 {
    return "T"
  }
  if x == 15 && y == 1 {
    return "T"
  }
  "."
}

///|
pub fn Field::new() -> Field {
  {
    x: 3,
    y: 4,
    steps: 0,
    party: [
      { name: "ember", level: 12, hp: 74, most: 98, },
      { name: "moss", level: 11, hp: 62, most: 62, },
      { name: "pip", level: 9, hp: 18, most: 54, },
    ],
    lead: 0,
    mode: Walk,
    enemy: "",
    enemy_hp: 0,
    enemy_most: 0,
    turn: 0,
    log: ["the route is quiet"],
    caught: 6,
    seen: 14,
    badges: 2,
    potions: 3,
  }
}

///|
pub fn Field::tile(self : Field, x : Int32, y : Int32) -> String {
  ignore(self)
  tile_at(x, y)
}

///|
pub fn Field::lead_beast(self : Field) -> Beast {
  self.party[self.lead]
}

///|
/// Walking: the trees and the water stop the party, and every fourth step into
/// tall grass brings something out.
pub fn Field::walk(self : Field, dx : Int32, dy : Int32) -> Unit {
  if self.mode == Fight {
    return
  }
  let nx = self.x + dx
  let ny = self.y + dy
  let tile = tile_at(nx, ny)
  if tile == "T" || tile == "~" || tile == " " {
    return
  }
  self.x = nx
  self.y = ny
  self.steps = self.steps + 1
  if tile == ":" && self.steps % 4 == 0 {
    self.encounter()
  }
}

///|
/// Something in the grass: a name off a fixed list, and its hit points.
fn Field::encounter(self : Field) -> Unit {
  let names : Array[String] = ["thistle", "bramble", "moth", "pebble"]
  let mark = (self.x + self.y + self.steps) % 4
  self.enemy = names[mark]
  self.enemy_most = 26 + self.lead_beast().level * 2
  self.enemy_hp = self.enemy_most
  self.mode = Fight
  self.turn = 0
  self.seen = self.seen + 1
  self.note("a wild " + self.enemy + " appeared")
}

///|
fn Field::note(self : Field, line : String) -> Unit {
  self.log.push(line)
  if self.log.length() > 4 {
    let kept : Array[String] = []
    for i in 1..<self.log.length() {
      kept.push(self.log[i])
    }
    self.log = kept
  }
}

///|
/// One turn: the party's creature strikes, then the wild one does. A hit is a
/// fixed number for the turn, so the same fight is the same fight.
pub fn Field::strike(self : Field) -> Unit {
  if self.mode != Fight {
    return
  }
  let lead = self.party[self.lead]
  self.turn = self.turn + 1
  let hit = 9 + self.turn * 3 + lead.level / 3
  self.enemy_hp = self.enemy_hp - hit
  if self.enemy_hp <= 0 {
    self.enemy_hp = 0
    self.mode = Won
    self.caught = self.caught + 1
    lead.level = lead.level + 1
    self.note(self.enemy + " fainted · caught")
    return
  }
  self.note("ember hits " + self.enemy + " for " + hit.to_string())
  let back = 6 + self.turn * 2
  lead.hp = lead.hp - back
  if lead.hp <= 0 {
    lead.hp = 0
    self.note(lead.name + " fainted")
    self.next()
  } else {
    self.note(self.enemy + " hits back for " + back.to_string())
  }
}

///|
/// The next creature in the party steps up, or the fight is lost.
fn Field::next(self : Field) -> Unit {
  let mut index = self.lead + 1
  while index < self.party.length() {
    if self.party[index].hp > 0 {
      self.lead = index
      self.note(self.party[index].name + " steps up")
      return
    }
    index = index + 1
  }
  self.mode = Walk
  self.note("the party is out of the fight")
}

///|
pub fn Field::flee(self : Field) -> Unit {
  if self.mode != Fight {
    return
  }
  self.mode = Walk
  self.note("got away from " + self.enemy)
}

///|
/// A potion heals the creature in front by twenty, and there are three of them.
pub fn Field::heal(self : Field) -> Unit {
  if self.potions == 0 {
    self.note("no potions left")
    return
  }
  let lead = self.party[self.lead]
  if lead.hp >= lead.most {
    self.note(lead.name + " is unhurt")
    return
  }
  self.potions = self.potions - 1
  lead.hp = lead.hp + 20
  if lead.hp > lead.most {
    lead.hp = lead.most
  }
  self.note(lead.name + " drinks a potion")
}

///|
pub fn Field::rest(self : Field) -> Unit {
  self.mode = Walk
  self.enemy = ""
  self.enemy_hp = 0
  self.turn = 0
  self.note("the grass closes over it")
}
