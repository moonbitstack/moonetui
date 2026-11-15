// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The table: seven columns, four foundations, a stock and a waste. The cursor
// is a slot — nought to six for a column, seven the stock, eight the waste, nine
// to twelve the foundations — and in a column it also holds a card, so a run
// can be lifted from the middle of a pile.

///|
#derive(Eq)
pub(all) enum Phase {
  Title
  Playing
  Won
}

///|
pub extend Phase with Eq::{not_equal, equal}

///|
/// What the table looked like before the last move, so `u` can take it back.
struct Snap {
  stock : Array[Card]
  waste : Array[Card]
  found : Array[Array[Card]]
  piles : Array[Array[Card]]
  score : Int32
  moves : Int32
  passes : Int32
}

///|
pub struct Table {
  mut stock : Array[Card]
  mut waste : Array[Card]
  mut found : Array[Array[Card]]
  mut piles : Array[Array[Card]]
  mut pick : Int32
  mut depth : Int32
  mut holding : Bool
  mut origin : Int32
  mut hold_from : Int32
  mut score : Int32
  mut moves : Int32
  mut passes : Int32
  mut clock : Int32
  mut cheer : Int32
  mut phase : Phase
  mut note : String
  mut history : Array[Snap]
}

///|
pub fn Table::new() -> Table {
  let found : Array[Array[Card]] = []
  let piles : Array[Array[Card]] = []
  for _ in 0..<SUITS {
    found.push([])
  }
  for _ in 0..<COLUMNS {
    piles.push([])
  }
  {
    stock: [],
    waste: [],
    found,
    piles,
    pick: 0,
    depth: 0,
    holding: false,
    origin: 0,
    hold_from: 0,
    score: 0,
    moves: 0,
    passes: 0,
    clock: 0,
    cheer: 0,
    phase: Title,
    note: "space deals",
    history: [],
  }
}

///|
pub fn Table::phase(self : Table) -> Phase {
  self.phase
}

///|
pub fn Table::score(self : Table) -> Int32 {
  self.score
}

///|
pub fn Table::moves(self : Table) -> Int32 {
  self.moves
}

///|
pub fn Table::clock(self : Table) -> Int32 {
  self.clock
}

///|
pub fn Table::note(self : Table) -> String {
  self.note
}

///|
pub fn Table::pick(self : Table) -> Int32 {
  self.pick
}

///|
pub fn Table::holding(self : Table) -> Bool {
  self.holding
}

///|
pub fn Table::pile(self : Table, index : Int32) -> Array[Card] {
  if index <= 6 {
    self.piles[index]
  } else if index == 7 {
    self.stock
  } else if index == 8 {
    self.waste
  } else {
    self.found[index - 9]
  }
}

///|
pub fn Table::home_count(self : Table) -> Int32 {
  let mut total = 0
  for pile in self.found {
    total = total + pile.length()
  }
  total
}

///|
/// Deal a game: one card to the first column, two to the second, and so on to
/// seven, each column's last card turned up; the twenty-four that are left wait
/// in the stock.
pub fn Table::deal(self : Table) -> Unit {
  let deck = shuffled()
  let mut at = deck.length() - 1
  let piles : Array[Array[Card]] = []
  for column in 0..<COLUMNS {
    let pile : Array[Card] = []
    for row in 0..<=column {
      let card = deck[at]
      at = at - 1
      pile.push(Card::new(card.rank, card.suit, row == column))
    }
    piles.push(pile)
  }
  let stock : Array[Card] = []
  while at >= 0 {
    let card = deck[at]
    stock.push(Card::new(card.rank, card.suit, false))
    at = at - 1
  }
  self.stock = stock
  self.waste = []
  self.piles = piles
  for i in 0..<SUITS {
    self.found[i] = []
  }
  self.pick = 0
  self.depth = piles[0].length() - 1
  self.holding = false
  self.score = 0
  self.moves = 0
  self.passes = 0
  self.clock = 0
  self.cheer = 0
  self.phase = Playing
  self.note = "enter draws · f sends a card home"
  self.history = []
}

///|
fn Table::remember(self : Table) -> Unit {
  let found : Array[Array[Card]] = []
  for pile in self.found {
    found.push(pile.copy())
  }
  let piles : Array[Array[Card]] = []
  for pile in self.piles {
    piles.push(pile.copy())
  }
  let snap = {
    stock: self.stock.copy(),
    waste: self.waste.copy(),
    found,
    piles,
    score: self.score,
    moves: self.moves,
    passes: self.passes,
  }
  if self.history.length() >= 60 {
    let kept : Array[Snap] = []
    for i in 1..<self.history.length() {
      kept.push(self.history[i])
    }
    self.history = kept
  }
  self.history.push(snap)
}

///|
/// Take the last move back. Nothing is remembered before the deal, so `u` on a
/// fresh table says so rather than doing nothing.
pub fn Table::undo(self : Table) -> Unit {
  if self.phase == Title {
    return
  }
  if self.history.length() == 0 {
    self.note = "nothing to take back"
    return
  }
  let snap = self.history.pop().unwrap()
  self.stock = snap.stock
  self.waste = snap.waste
  self.found = snap.found
  self.piles = snap.piles
  self.score = snap.score
  self.moves = snap.moves
  self.passes = snap.passes
  self.holding = false
  if self.phase == Won {
    self.phase = Playing
  }
  self.settle()
  self.note = "taken back"
}

///|
/// Keep the card cursor on a card that can be lifted: the top of the pile, or
/// as deep as the face-up run goes.
fn Table::settle(self : Table) -> Unit {
  if self.pick > 6 {
    return
  }
  let pile = self.piles[self.pick]
  let n = pile.length()
  if n == 0 {
    self.depth = 0
    return
  }
  let mut first = n - 1
  while first > 0 && pile[first - 1].up {
    first = first - 1
  }
  if self.depth < first {
    self.depth = first
  }
  if self.depth > n - 1 {
    self.depth = n - 1
  }
}

///|
pub fn Table::aim(self : Table, delta : Int32) -> Unit {
  let next = self.pick + delta
  if self.pick <= 6 {
    if next >= 0 && next <= 6 {
      self.pick = next
      self.settle()
    }
  } else if next >= 7 && next <= 12 {
    self.pick = next
  }
}

///|
/// Move the card cursor up or down a column, and stop at the first card that is
/// still face down.
pub fn Table::lift(self : Table, delta : Int32) -> Unit {
  if self.pick > 6 {
    return
  }
  let pile = self.piles[self.pick]
  let n = pile.length()
  if n == 0 {
    return
  }
  let next = self.depth + delta
  if next >= 0 && next <= n - 1 && pile[next].up {
    self.depth = next
  }
}

///|
pub fn Table::jump(self : Table, column : Int32) -> Unit {
  if column >= 0 && column < COLUMNS {
    self.pick = column
    self.settle()
  }
}

///|
/// The cards that `space` would lift, in the order they are stacked.
fn Table::moving(self : Table) -> Array[Card] {
  let out : Array[Card] = []
  if !self.holding {
    return out
  }
  if self.origin == 8 {
    if self.waste.length() > 0 {
      out.push(self.waste[self.waste.length() - 1])
    }
  } else if self.origin <= 6 {
    let pile = self.piles[self.origin]
    for i in self.hold_from..<pile.length() {
      out.push(pile[i])
    }
  }
  out
}

///|
/// True when the cards from `from` down are a run: every card turned up, each
/// one a step lower than the one above it, and the colour alternating.
fn run_ok(pile : Array[Card], from : Int32) -> Bool {
  let n = pile.length()
  if from < 0 || from >= n {
    return false
  }
  let mut i = from
  while i < n {
    if !pile[i].up {
      return false
    }
    if i + 1 < n {
      let above = pile[i]
      let below = pile[i + 1]
      if !below.up || below.rank != above.rank - 1 || below.red() == above.red() {
        return false
      }
    }
    i = i + 1
  }
  true
}

///|
/// Lift what the cursor holds: a run from the middle of a column, the top card
/// of the waste. A column stays as it is until the cards are put down again, so
/// putting them back needs no bookkeeping.
pub fn Table::grab(self : Table) -> Unit {
  if self.phase != Playing || self.holding {
    return
  }
  if self.pick == 7 {
    self.draw()
    return
  }
  if self.pick >= 9 {
    self.note = "a card that is home stays there"
    return
  }
  if self.pick == 8 {
    if self.waste.length() == 0 {
      self.note = "the waste is empty"
      return
    }
    self.holding = true
    self.origin = 8
    self.hold_from = 0
    let card = self.waste[self.waste.length() - 1]
    self.note = "holding " + card.name() + " · space drops it"
    return
  }
  let pile = self.piles[self.pick]
  if pile.length() == 0 {
    self.note = "an empty column takes a king"
    return
  }
  if !run_ok(pile, self.depth) {
    self.note = "that is not a run to move"
    return
  }
  let card = pile[self.depth]
  let count = pile.length() - self.depth
  self.holding = true
  self.origin = self.pick
  self.hold_from = self.depth
  self.note = if count == 1 {
    "holding " + card.name() + " · space drops it"
  } else {
    "holding " +
    card.name() +
    " and " +
    (count - 1).to_string() +
    " more · space drops them"
  }
}

///|
/// True when `slot` would take `card` on top: a column takes the next card down
/// in the other colour, an empty column a king, a foundation the next rank of
/// its own suit.
pub fn Table::accepts(self : Table, slot : Int32, card : Card) -> Bool {
  if slot <= 6 {
    let pile = self.piles[slot]
    if pile.length() == 0 {
      return card.rank == 13
    }
    let top = pile[pile.length() - 1]
    top.up && top.rank == card.rank + 1 && top.red() != card.red()
  } else if slot >= 9 {
    let suit = slot - 9
    card.suit == suit && card.rank == self.found[suit].length() + 1
  } else {
    false
  }
}

///|
/// Why a slot will not take a card, in a line a reader can act on.
fn Table::refusal(self : Table, slot : Int32, card : Card) -> String {
  if slot <= 6 {
    let pile = self.piles[slot]
    if pile.length() == 0 {
      "an empty column takes a king"
    } else {
      let top = pile[pile.length() - 1]
      if !top.up {
        "that card is face down"
      } else {
        "a " +
        card.name() +
        " goes on a " +
        (card.rank + 1).to_string() +
        " of the other colour"
      }
    }
  } else if slot >= 9 {
    let suit = slot - 9
    "the " + suit.to_string() + " foundation wants " + (suit + 1).to_string()
  } else {
    "there is nothing to put a card on"
  }
}

///|
/// Put the lifted cards down on the slot the cursor is on, if that slot takes
/// them. A slot that does not leaves the cards in the hand, so a wrong guess
/// costs nothing but the line at the top.
pub fn Table::place(self : Table) -> Unit {
  if !self.holding {
    return
  }
  let moved = self.moving()
  if moved.length() == 0 {
    self.holding = false
    return
  }
  let head = moved[0]
  if self.pick == self.origin {
    self.holding = false
    self.note = "put " + head.name() + " back"
    return
  }
  if !self.accepts(self.pick, head) {
    self.note = self.refusal(self.pick, head)
    return
  }
  self.remember()
  let target = self.pick
  // Take the cards off where they were, and turn up the card underneath.
  if self.origin == 8 {
    ignore(self.waste.pop())
  } else {
    let pile = self.piles[self.origin]
    let kept : Array[Card] = []
    for i in 0..<self.hold_from {
      kept.push(pile[i])
    }
    self.piles[self.origin] = kept
    if kept.length() > 0 {
      let last = kept[kept.length() - 1]
      if !last.up {
        kept[kept.length() - 1] = Card::new(last.rank, last.suit, true)
        self.score = self.score + 5
      }
    }
  }
  // And put them down.
  if target <= 6 {
    let dest = self.piles[target]
    for card in moved {
      dest.push(card)
    }
  } else {
    self.found[target - 9].push(head)
    self.score = self.score + 10
  }
  if self.origin == 8 && target <= 6 {
    self.score = self.score + 5
  }
  self.holding = false
  self.moves = self.moves + 1
  self.pick = target
  self.settle()
  self.note = if moved.length() == 1 {
    head.name() + " down"
  } else {
    head.name() + " and " + (moved.length() - 1).to_string() + " down"
  }
  self.check()
}

///|
/// Send the card the cursor is on to its foundation: `f` is the move a player
/// makes most often, and it should take one key.
pub fn Table::home(self : Table) -> Unit {
  if self.phase != Playing {
    return
  }
  if self.holding {
    let moved = self.moving()
    if moved.length() != 1 {
      self.note = "one card at a time goes home"
      return
    }
    let card = moved[0]
    let slot = 9 + card.suit
    if self.accepts(slot, card) {
      self.pick = slot
      self.place()
    } else {
      self.note = self.refusal(slot, card)
    }
    return
  }
  if self.pick == 8 {
    if self.waste.length() == 0 {
      self.note = "the waste is empty"
      return
    }
    let card = self.waste[self.waste.length() - 1]
    self.holding = true
    self.origin = 8
    self.hold_from = 0
    self.pick = 9 + card.suit
    self.place()
    return
  }
  if self.pick >= 9 {
    self.note = "a card that is home stays there"
    return
  }
  let pile = self.piles[self.pick]
  if pile.length() == 0 {
    self.note = "an empty column takes a king"
    return
  }
  let top = pile[pile.length() - 1]
  if !top.up {
    self.note = "that card is face down"
    return
  }
  let slot = 9 + top.suit
  if !self.accepts(slot, top) {
    self.note = self.refusal(slot, top)
    return
  }
  self.holding = true
  self.origin = self.pick
  self.hold_from = pile.length() - 1
  self.pick = slot
  self.place()
}

///|
/// Turn the next card of the stock face up onto the waste. When the stock runs
/// out, the waste is turned back over as a whole and the pass is counted.
pub fn Table::draw(self : Table) -> Unit {
  if self.phase != Playing {
    return
  }
  if self.holding {
    self.note = "put the cards down first"
    return
  }
  if self.stock.length() > 0 {
    self.remember()
    let card = self.stock.pop().unwrap()
    self.waste.push(Card::new(card.rank, card.suit, true))
    self.moves = self.moves + 1
    self.pick = 8
    self.note = "drew " + card.name()
    return
  }
  if self.waste.length() > 0 {
    self.remember()
    let back : Array[Card] = []
    let n = self.waste.length()
    for i in 0..<n {
      let card = self.waste[n - 1 - i]
      back.push(Card::new(card.rank, card.suit, false))
    }
    self.stock = back
    self.waste = []
    self.passes = self.passes + 1
    if self.score >= 20 {
      self.score = self.score - 20
    } else {
      self.score = 0
    }
    self.moves = self.moves + 1
    self.pick = 8
    self.note = "deck turned · pass " + self.passes.to_string()
    return
  }
  self.note = "no cards left to draw"
}

///|
fn Table::check(self : Table) -> Unit {
  if self.home_count() == SUITS * RANKS {
    self.phase = Won
    self.cheer = 0
    self.note = "every card is home"
  }
}

///|
pub fn Table::tick(self : Table, ms : Int32) -> Unit {
  if self.phase == Playing {
    self.clock = self.clock + ms
  } else if self.phase == Won {
    self.cheer = self.cheer + ms
  }
}
