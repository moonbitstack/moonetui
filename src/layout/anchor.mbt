// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which edges of the parent a box is held to. A held edge keeps its distance
/// however the parent is sized; an axis with both of its edges held stretches
/// the box to fill what lies between them. A box held to no edge keeps the
/// size it asked for and sits where its pivot says.
pub(all) struct Anchor {
  top : Bool
  right : Bool
  bottom : Bool
  left : Bool
} derive(Eq, Debug)

///|
/// Held to nothing: the box floats, placed by its pivot.
pub let free : Anchor = {
  top: false,
  right: false,
  bottom: false,
  left: false,
}

///|
/// Held to every edge: the box fills its parent.
pub let stretch : Anchor = { top: true, right: true, bottom: true, left: true, }

///|
pub fn Anchor::new(
  top~ : Bool = false,
  right~ : Bool = false,
  bottom~ : Bool = false,
  left~ : Bool = false,
) -> Anchor {
  { top, right, bottom, left, }
}

///|
pub fn Anchor::is_free(self : Anchor) -> Bool {
  !self.top && !self.right && !self.bottom && !self.left
}

///|
/// Whether both horizontal edges are held, which stretches the box across.
pub fn Anchor::spans_x(self : Anchor) -> Bool {
  self.left && self.right
}

///|
/// Whether both vertical edges are held, which stretches the box down.
pub fn Anchor::spans_y(self : Anchor) -> Bool {
  self.top && self.bottom
}

///|
/// The four corners and the four edge midpoints, as anchors: the anchors a
/// bar or a status line is usually given.
pub fn corners() -> Array[Anchor] {
  [
    Anchor::new(top=true, left=true),
    Anchor::new(top=true, right=true),
    Anchor::new(bottom=true, left=true),
    Anchor::new(bottom=true, right=true),
  ]
}

///|
/// Where a box no edge holds sits in the space its parent left it.
pub(all) enum Pivot {
  TopLeft
  TopCentre
  TopRight
  MiddleLeft
  Middle
  MiddleRight
  BottomLeft
  BottomCentre
  BottomRight
} derive(Eq, Debug)

///|
pub let centre : Pivot = Middle

///|
/// How far across the free space the box starts, as a fraction of it.
pub fn Pivot::frac_x(self : Pivot) -> Double {
  match self {
    TopLeft | MiddleLeft | BottomLeft => 0.0
    TopCentre | Middle | BottomCentre => 0.5
    TopRight | MiddleRight | BottomRight => 1.0
  }
}

///|
/// How far down the free space the box starts, as a fraction of it.
pub fn Pivot::frac_y(self : Pivot) -> Double {
  match self {
    TopLeft | TopCentre | TopRight => 0.0
    MiddleLeft | Middle | MiddleRight => 0.5
    BottomLeft | BottomCentre | BottomRight => 1.0
  }
}

///|
/// Where `want` lands inside `area`: held to the edges `anchor` names, or, on
/// an axis no edge holds, of the size it asked for and put where `pivot`
/// says. `margin` holds the box off the parent before either is applied.
pub fn anchor_region(
  area : @geom.Region,
  want : @geom.Size,
  anchor~ : Anchor = free,
  pivot~ : Pivot = TopLeft,
  margin~ : @geom.Spacing = @geom.Spacing::all(0),
) -> @geom.Region {
  let field = margin.shrink_region(area)
  let width = if anchor.spans_x() {
    field.width
  } else if want.width < field.width {
    want.width
  } else {
    field.width
  }
  let height = if anchor.spans_y() {
    field.height
  } else if want.height < field.height {
    want.height
  } else {
    field.height
  }
  let slack_x = field.width - width
  let slack_y = field.height - height
  let x = if anchor.left {
    field.x
  } else if anchor.right {
    field.x + slack_x
  } else {
    field.x + (slack_x.to_double() * pivot.frac_x()).to_int()
  }
  let y = if anchor.top {
    field.y
  } else if anchor.bottom {
    field.y + slack_y
  } else {
    field.y + (slack_y.to_double() * pivot.frac_y()).to_int()
  }
  @geom.Region::new(x, y, width, height)
}

///|
/// The nine pivots, in the order they read: across, then down.
pub fn pivots() -> Array[Pivot] {
  [
    TopLeft,
    TopCentre,
    TopRight,
    MiddleLeft,
    Middle,
    MiddleRight,
    BottomLeft,
    BottomCentre,
    BottomRight,
  ]
}

///|
pub extend Anchor with Debug::{to_repr}

///|
pub extend Anchor with Eq::{not_equal, equal}

///|
pub extend Pivot with Debug::{to_repr}

///|
pub extend Pivot with Eq::{not_equal, equal}
