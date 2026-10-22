// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Whether a node takes part in the layout at all. Textual calls these
/// `block` and `none`; a terminal has no inline flow to take part in, so the
/// pair reads here as shown and hidden.
pub(all) enum Display {
  Block
  Hidden
} derive(Eq, Debug)

///|
pub extend Display with Debug::{to_repr}

///|
pub extend Display with Eq::{not_equal, equal}

///|
/// Where a block of content sits along the horizontal axis when it does not
/// fill it.
pub(all) enum HAlign {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub extend HAlign with Debug::{to_repr}

///|
pub extend HAlign with Eq::{not_equal, equal}

///|
/// Where a block of content sits along the vertical axis when it does not
/// fill it.
pub(all) enum VAlign {
  Top
  Middle
  Bottom
} derive(Eq, Debug)

///|
pub extend VAlign with Debug::{to_repr}

///|
pub extend VAlign with Eq::{not_equal, equal}

///|
/// Where content sits inside a node. The component along the stacking axis of
/// a container positions the whole block of children when it is shorter than
/// the container; the component across it is kept for the containers that will
/// one day not fill their children.
pub(all) struct Align {
  h : HAlign
  v : VAlign
} derive(Eq, Debug)

///|
pub extend Align with Debug::{to_repr}

///|
pub extend Align with Eq::{not_equal, equal}

///|
/// Content at the top left: the alignment of a node that never said.
pub fn Align::new(h~ : HAlign = Left, v~ : VAlign = Top) -> Align {
  { h, v, }
}

///|
/// How far along the main axis a block of content is pushed when it does not
/// fill the container, given the slack there is.
pub fn Align::main_offset(
  self : Align,
  dir : @layout.Dir,
  slack : Int32,
) -> Int32 {
  let slack = if slack < 0 { 0 } else { slack }
  match dir {
    Vertical =>
      match self.v {
        Top => 0
        Middle => slack / 2
        Bottom => slack
      }
    Horizontal =>
      match self.h {
        Left => 0
        Center => slack / 2
        Right => slack
      }
  }
}

///|
/// The four borders a terminal can draw, plus ascii for the terminals that
/// cannot. `Off` is what an unset border property resolves to.
pub(all) enum EdgeKind {
  Off
  Ascii
  Thin
  Round
  Double
  Heavy
} derive(Eq, Debug)

///|
pub extend EdgeKind with Debug::{to_repr}

///|
pub extend EdgeKind with Eq::{not_equal, equal}

///|
/// The glyphs this border is drawn with.
pub fn EdgeKind::glyphs(self : EdgeKind) -> @widget.Border {
  match self {
    Off => @widget.thin
    Ascii =>
      {
        top_left: "+",
        top: "-",
        top_right: "+",
        left: "|",
        right: "|",
        bottom_left: "+",
        bottom: "-",
        bottom_right: "+",
      }
    Thin => @widget.thin
    Round =>
      {
        top_left: "╭",
        top: "─",
        top_right: "╮",
        left: "│",
        right: "│",
        bottom_left: "╰",
        bottom: "─",
        bottom_right: "╯",
      }
    Double =>
      {
        top_left: "╔",
        top: "═",
        top_right: "╗",
        left: "║",
        right: "║",
        bottom_left: "╚",
        bottom: "═",
        bottom_right: "╝",
      }
    Heavy => @widget.heavy
  }
}

///|
/// Every style property a node can be given. Each one is optional: unset is
/// not a default, it is the instruction to let the rule below supply the
/// value — which is what makes rules stack.
///
/// What the properties do once resolved:
///
/// - `display` — a hidden node and its subtree are not placed.
/// - `width`/`height`/`min`/`max` — override the node's structural box along
///   each axis when set.
/// - `padding` — space between a node's edge and its content.
/// - `margin` — space a node keeps to itself inside the slot the layout gave
///   it.
/// - `border` — a one-cell frame drawn around the node, outside the padding.
/// - `align` — where the block of children sits inside a container.
/// - `text` — the cell style under everything a node draws: it paints the
///   border, the background, and anything a widget left unstyled.
pub(all) struct Styles {
  display : Display?
  width : @layout.Extent?
  height : @layout.Extent?
  min_width : Int32?
  max_width : Int32?
  min_height : Int32?
  max_height : Int32?
  padding : @geom.Spacing?
  margin : @geom.Spacing?
  border : EdgeKind?
  align : Align?
  text : @style.Style?
} derive(Eq, Debug)

///|
pub extend Styles with Debug::{to_repr}

///|
pub extend Styles with Eq::{not_equal, equal}

///|
/// No property set: the identity of the cascade.
pub let empty : Styles = {
  display: None,
  width: None,
  height: None,
  min_width: None,
  max_width: None,
  min_height: None,
  max_height: None,
  padding: None,
  margin: None,
  border: None,
  align: None,
  text: None,
}

///|
/// Build styles. Every property is optional, so what is left out is the part
/// the cascade supplies.
pub fn Styles::new(
  display~ : Display? = None,
  width~ : @layout.Extent? = None,
  height~ : @layout.Extent? = None,
  min_width~ : Int32? = None,
  max_width~ : Int32? = None,
  min_height~ : Int32? = None,
  max_height~ : Int32? = None,
  padding~ : @geom.Spacing? = None,
  margin~ : @geom.Spacing? = None,
  border~ : EdgeKind? = None,
  align~ : Align? = None,
  text~ : @style.Style? = None,
) -> Styles {
  {
    display,
    width,
    height,
    min_width,
    max_width,
    min_height,
    max_height,
    padding,
    margin,
    border,
    align,
    text,
  }
}

///|
/// True when no property is set.
pub fn Styles::is_empty(self : Styles) -> Bool {
  self == empty
}

///|
/// Layer `other` over `self`: every property it sets replaces the one below,
/// every property it leaves unset lets the lower one stand, and a set text
/// style merges field by field so that a rule naming only a background keeps
/// the foreground it inherits. This is the step the cascade runs once per
/// matching rule, least specific first.
pub fn Styles::merge(self : Styles, other : Styles) -> Styles {
  {
    display: pick(other.display, self.display),
    width: pick(other.width, self.width),
    height: pick(other.height, self.height),
    min_width: pick(other.min_width, self.min_width),
    max_width: pick(other.max_width, self.max_width),
    min_height: pick(other.min_height, self.min_height),
    max_height: pick(other.max_height, self.max_height),
    padding: pick(other.padding, self.padding),
    margin: pick(other.margin, self.margin),
    border: pick(other.border, self.border),
    align: pick(other.align, self.align),
    text: match (self.text, other.text) {
      (Some(lower), Some(upper)) => Some(lower.merge(upper))
      (_, Some(upper)) => Some(upper)
      (Some(lower), None) => Some(lower)
      (None, None) => None
    },
  }
}

///|
fn[T] pick(over : T?, under : T?) -> T? {
  match over {
    Some(value) => Some(value)
    None => under
  }
}

///|
/// The styles a node ends up with after the cascade has run: rule matches
/// merged in order, the node's inline styles on top, the text style inherited
/// from the container underneath, and every property resolved to a value a
/// layout can act on.
pub(all) struct Resolved {
  hidden : Bool
  margin : @geom.Spacing
  padding : @geom.Spacing
  border : EdgeKind
  align : Align
  width : @layout.Extent?
  height : @layout.Extent?
  min_width : Int32?
  max_width : Int32?
  min_height : Int32?
  max_height : Int32?
  text : @style.Style
} derive(Eq, Debug)

///|
pub extend Resolved with Debug::{to_repr}

///|
pub extend Resolved with Eq::{not_equal, equal}

///|
/// What a node with no styles at all resolves to.
pub let bare : Resolved = {
  hidden: false,
  margin: { top: 0, right: 0, bottom: 0, left: 0, },
  padding: { top: 0, right: 0, bottom: 0, left: 0, },
  border: Off,
  align: Align::new(),
  width: None,
  height: None,
  min_width: None,
  max_width: None,
  min_height: None,
  max_height: None,
  text: @style.default,
}

///|
/// Resolve styles against an inherited text style. The text style a node
/// inherits is what paints the node's own chrome, and the text style its
/// children inherit — a terminal has no transparent cells, so a container's
/// background is carried down rather than hidden by every child that never
/// named one.
pub fn Resolved::of(styles : Styles, inherited : @style.Style) -> Resolved {
  let text = match styles.text {
    Some(own) => inherited.merge(own)
    None => inherited
  }
  {
    hidden: match styles.display {
      Some(Hidden) => true
      _ => false
    },
    margin: match styles.margin {
      Some(margin) => margin
      None => bare.margin
    },
    padding: match styles.padding {
      Some(padding) => padding
      None => bare.padding
    },
    border: match styles.border {
      Some(border) => border
      None => bare.border
    },
    align: match styles.align {
      Some(align) => align
      None => bare.align
    },
    width: styles.width,
    height: styles.height,
    min_width: styles.min_width,
    max_width: styles.max_width,
    min_height: styles.min_height,
    max_height: styles.max_height,
    text,
  }
}

///|
/// The node's structural box, with the sizes the styles override. Along a
/// vertical stack the main axis is height; along a horizontal one it is width,
/// which is why a style names both and the box picks one.
pub fn Resolved::box(
  self : Resolved,
  dir : @layout.Dir,
  base : @layout.Box,
) -> @layout.Box {
  let main = match dir {
    Vertical =>
      match self.height {
        Some(height) => height
        None => base.extent
      }
    Horizontal =>
      match self.width {
        Some(width) => width
        None => base.extent
      }
  }
  let min = match dir {
    Vertical =>
      match self.min_height {
        Some(min) => min
        None => base.min
      }
    Horizontal =>
      match self.min_width {
        Some(min) => min
        None => base.min
      }
  }
  let max = match dir {
    Vertical =>
      match self.max_height {
        Some(max) => max
        None => base.max
      }
    Horizontal =>
      match self.max_width {
        Some(max) => max
        None => base.max
      }
  }
  { ..base, extent: main, min, max, }
}

///|
/// The area the node's content occupies: the area it was placed in, shrunk by
/// its border and padding. A border is one cell thick on every side, which is
/// every border a terminal can draw.
pub fn Resolved::content_region(
  self : Resolved,
  area : @geom.Region,
) -> @geom.Region {
  let ring = match self.border {
    Off => @geom.Spacing::all(0)
    _ => @geom.Spacing::all(1)
  }
  ring.add(self.padding).shrink_region(area)
}

///|
/// True when the node paints a frame or a background of its own, and so needs
/// a placement behind its content. A leaf that only carries a text style does
/// not: the style is layered under the widget's own lines.
pub fn Resolved::has_chrome(self : Resolved) -> Bool {
  self.border != Off || !self.padding.is_zero() || !self.text.is_default()
}

///|
/// The chrome a node draws around its content: the border and the background
/// behind it, in the node's resolved text style, at the size it was placed.
pub(all) struct Decor {
  border : EdgeKind
  style : @style.Style
  size : @geom.Size
} derive(Eq, Debug)

///|
pub extend Decor with Debug::{to_repr}

///|
pub extend Decor with Eq::{not_equal, equal}

///|
/// One row of chrome: the border ring and the background behind it, with
/// nothing drawn inside. `frame_line` with no padding and no content.
pub fn Decor::line(self : Decor, row : Int32) -> @strip.Strip {
  self.frame_line(@geom.Spacing::all(0), row, None)
}

///|
/// One row of a node's whole face, chrome and content together.
///
/// `row` counts from the top of the node. `content` is the row's content —
/// in the node's own style, to be laid under the node's resolved text style —
/// or `None` when this row holds none, which is every row of a container and
/// every row of padding. A border is one cell thick on every side, which is
/// every border a terminal can draw, and the padding between border and
/// content is painted rather than left showing whatever was underneath.
pub fn Decor::frame_line(
  self : Decor,
  padding : @geom.Spacing,
  row : Int32,
  content : @strip.Strip?,
) -> @strip.Strip {
  let width = self.size.width
  let height = self.size.height
  if width <= 0 || height <= 0 {
    return @strip.Strip::empty()
  }
  let ring = match self.border {
    Off => 0
    _ => 1
  }
  // What the content may occupy: inside the ring, inside the padding.
  let inner_w = at_least_zero(width - 2 * ring - padding.width())
  // The content between its horizontal padding, filling the space the ring
  // leaves. Without content the whole inside is background.
  let body = match content {
    Some(strip) =>
      @strip.Strip::join([
        @strip.Strip::blank(padding.left, self.style),
        strip.pad_to(inner_w, self.style),
        @strip.Strip::blank(
          width - 2 * ring - inner_w - padding.left,
          self.style,
        ),
      ])
    None => @strip.Strip::blank(width - 2 * ring, self.style)
  }
  match self.border {
    Off =>
      match content {
        Some(_) => body
        None => @strip.Strip::blank(width, self.style)
      }
    kind =>
      if row == 0 || row == height - 1 {
        @widget.frame(
          kind.glyphs(),
          row,
          self.size,
          self.style,
          @strip.Strip::empty(),
        )
      } else {
        @widget.frame(kind.glyphs(), row, self.size, self.style, body)
      }
  }
}

///|
fn at_least_zero(value : Int32) -> Int32 {
  if value < 0 {
    0
  } else {
    value
  }
}
