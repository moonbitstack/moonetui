// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum Display {
  Block
  Hidden
} derive(Eq, Debug)

///|
pub extend Display with Debug::{to_repr}

///|
pub extend Display with Eq::{not_equal, equal}

///|
pub(all) enum HAlign {
  Left
  Centre
  Right
} derive(Eq, Debug)

///|
pub extend HAlign with Debug::{to_repr}

///|
pub extend HAlign with Eq::{not_equal, equal}

///|
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
pub(all) struct Align {
  h : HAlign
  v : VAlign
} derive(Eq, Debug)

///|
pub extend Align with Debug::{to_repr}

///|
pub extend Align with Eq::{not_equal, equal}

///|
pub fn Align::new(h~ : HAlign = Left, v~ : VAlign = Top) -> Align {
  { h, v, }
}

///|
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
        Centre => slack / 2
        Right => slack
      }
  }
}

///|
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
pub fn Styles::is_empty(self : Styles) -> Bool {
  self == empty
}

///|
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
pub fn Resolved::has_chrome(self : Resolved) -> Bool {
  self.border != Off || !self.padding.is_zero() || !self.text.is_default()
}

///|
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
pub fn Decor::line(self : Decor, row : Int32) -> @strip.Strip {
  self.frame_line(@geom.Spacing::all(0), row, None)
}

///|
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
  let inner_w = at_least_zero(width - 2 * ring - padding.width())
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
