// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Klondike: fifty-two cards, seven columns, four foundations and one card drawn
// at a time. The shuffle is a fixed seed, so a deal is always the same deal and
// the frame test can name the card it lifts.

///|
pub const SUITS : Int32 = 4

///|
pub const RANKS : Int32 = 13

///|
pub const COLUMNS : Int32 = 7

///|
/// A card is a rank from one to thirteen standing for ace to king, a suit from
/// nought to three, and whether its face is turned up.
pub struct Card {
  rank : Int32
  suit : Int32
  up : Bool
}

///|
pub fn Card::new(rank : Int32, suit : Int32, up : Bool) -> Card {
  { rank, suit, up, }
}

///|
/// Hearts and diamonds are red, spades and clubs black: the only property of a
/// suit that the stacking rule asks about.
pub fn Card::red(self : Card) -> Bool {
  self.suit == 1 || self.suit == 2
}

///|
pub fn Card::mark(self : Card) -> String {
  match self.suit {
    0 => "♠"
    1 => "♥"
    2 => "♦"
    _ => "♣"
  }
}

///|
pub fn Card::rank_text(self : Card) -> String {
  match self.rank {
    1 => "A"
    11 => "J"
    12 => "Q"
    13 => "K"
    _ => self.rank.to_string()
  }
}

///|
/// The rank and the suit in three cells, which is the inside of a card: ` A♠`
/// for a single-letter rank, `10♦` for a two-letter one.
pub fn Card::face_text(self : Card) -> String {
  let text = self.rank_text()
  if text.length() == 1 {
    " " + text + self.mark()
  } else {
    text + self.mark()
  }
}

///|
/// A card named the way a person would say it, for the line that reports the
/// last move: `A♠`, `10♦`.
pub fn Card::name(self : Card) -> String {
  self.rank_text() + self.mark()
}

///|
/// The deck in the order it is dealt: every suit from ace to king, shuffled by
/// a Lehmer generator from a fixed seed. Same seed, same deal, forever.
fn shuffled() -> Array[Card] {
  let deck : Array[Card] = []
  for suit in 0..<SUITS {
    for rank in 1..<=RANKS {
      deck.push(Card::new(rank, suit, false))
    }
  }
  let mut state : Int64 = 20261115
  let mut i = deck.length() - 1
  while i > 0 {
    state = state * 48271 % 2147483647
    let j = (state % (i + 1).to_int64()).to_int()
    let held = deck[i]
    deck[i] = deck[j]
    deck[j] = held
    i = i - 1
  }
  deck
}

///|
/// The hand that a deal turns over, for the test: one card, its rank and suit.
pub fn deal_shape() -> Array[(Int32, Int32)] {
  let deck = shuffled()
  let out : Array[(Int32, Int32)] = []
  for card in deck {
    out.push((card.rank, card.suit))
  }
  out
}

///|
pub fn make_deck() -> Array[Card] {
  shuffled()
}
