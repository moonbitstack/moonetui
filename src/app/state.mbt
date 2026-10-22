// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One node gliding from where it was to where the layout just put it. The
/// times are milliseconds off the driver's clock.
pub(all) struct Anim {
  from : @geom.Region
  to : @geom.Region
  start : Int32
  ms : Int32
} derive(Eq, Debug)

///|
pub extend Anim with Debug::{to_repr}

///|
pub extend Anim with Eq::{not_equal, equal}

///|
/// Where the node sits at `now`: eased from the old place toward the new one,
/// and landed once the span has passed.
pub fn Anim::at(self : Anim, now : Int32) -> @geom.Region {
  if self.ms <= 0 || now - self.start >= self.ms {
    return self.to
  }
  let t = (now - self.start).to_double() / self.ms.to_double()
  let eased = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
  let dx = (self.to.x - self.from.x).to_double() * eased
  let dy = (self.to.y - self.from.y).to_double() * eased
  @geom.Region::new(
    self.from.x + dx.to_int(),
    self.from.y + dy.to_int(),
    self.to.width,
    self.to.height,
  )
}

///|
pub(all) struct Timer {
  ms : Int32
  at : Int32
  repeat : Bool
  fire : () -> Unit
} derive(Debug)

///|
pub extend Timer with Debug::{to_repr}

///|
pub(all) struct Screen {
  root : Node
  focus : Int32
}
