// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A frame, a title and padding around any other widget. The widget inside is
/// drawn and driven at the size the frame leaves it, so a `Block` goes round
/// a widget without that widget knowing.
pub struct Block {
  inner : &Widget
  border : Border?
  mut title : String
  title_align : Align
  padding : @geom.Spacing
  style : @style.Style
  border_style : @style.Style
  title_style : @style.Style
}

///|
pub fn Block::new(
  inner : &Widget,
  title~ : String = "",
  border~ : Border? = Some(thin),
  padding~ : @geom.Spacing = @geom.Spacing::all(0),
  title_align~ : Align = Left,
  style~ : @style.Style = @style.default,
  border_style~ : @style.Style = @style.default,
  title_style~ : @style.Style = @style.Style::new(bold=true),
) -> Block {
  {
    inner,
    border,
    title,
    title_align,
    padding,
    style,
    border_style,
    title_style,
  }
}

///|
pub fn Block::title(self : Block) -> String {
  self.title
}

///|
pub fn Block::set_title(self : Block, title : String) -> Unit {
  self.title = title
}

///|
/// How many rows and columns the frame and padding take off each side.
pub fn Block::padding_of(self : Block) -> @geom.Spacing {
  let ring = match self.border {
    Some(_) => 1
    None => 0
  }
  @geom.Spacing::all(ring).add(self.padding)
}

///|
pub impl Widget for Block with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 {
    return @strip.Strip::empty()
  }
  let inset = self.padding_of()
  let inner_w = at_least_zero(size.width - inset.width())
  let inner_h = at_least_zero(size.height - inset.height())
  let content_row = row - inset.top
  let body = if content_row >= 0 && content_row < inner_h && inner_w > 0 {
    let line = self.inner.render_line(
      content_row,
      @geom.Size::new(inner_w, inner_h),
    )
    @strip.Strip::join([
      @strip.Strip::blank(self.padding.left, self.style),
      line.pad_to(inner_w, self.style),
      @strip.Strip::blank(self.padding.right, self.style),
    ])
  } else {
    @strip.Strip::blank(
      at_least_zero(size.width - ring_of(self.border) * 2),
      self.style,
    )
  }
  match self.border {
    None => body
    Some(frame) =>
      if row == 0 {
        self.edge_line(frame, size, top=true)
      } else if row == size.height - 1 {
        self.edge_line(frame, size, top=false)
      } else {
        @strip.Strip::join([
          @strip.Strip::of(frame.left, self.border_style),
          body,
          @strip.Strip::of(frame.right, self.border_style),
        ])
      }
  }
}

///|
pub impl Widget for Block with fn hint(self, size) {
  let inset = self.padding_of()
  let room = @geom.Size::new(
    at_least_zero(size.width - inset.width()),
    at_least_zero(size.height - inset.height()),
  )
  let want = self.inner.hint(room)
  @geom.Size::new(want.width + inset.width(), want.height + inset.height())
}

///|
pub impl Widget for Block with fn handle(self, ctx, msg) {
  let inset = self.padding_of()
  let room = @geom.Size::new(
    at_least_zero(ctx.size.width - inset.width()),
    at_least_zero(ctx.size.height - inset.height()),
  )
  let inner_msg = match msg {
    Mouse(mouse) =>
      Mouse({ ..mouse, x: mouse.x - inset.left, y: mouse.y - inset.top, })
    _ => msg
  }
  forward(self.inner, ctx, room, inner_msg)
}

///|
pub impl Widget for Block with fn focusable(self) {
  self.inner.focusable()
}

///|
/// The top or bottom edge, with the title let into the top one.
fn Block::edge_line(
  self : Block,
  frame : Border,
  size : @geom.Size,
  top~ : Bool,
) -> @strip.Strip {
  let start = if top { frame.top_left } else { frame.bottom_left }
  let end = if top { frame.top_right } else { frame.bottom_right }
  let edge = if top { frame.top } else { frame.bottom }
  if size.width < 2 {
    return @strip.Strip::of(clip_to(start + end, size.width), self.border_style)
  }
  let span = size.width - 2
  let head = @strip.Strip::of(start, self.border_style)
  let tail = @strip.Strip::of(end, self.border_style)
  let bar = (n : Int32) => {
    @strip.Strip::of(repeat_glyph(edge, n), self.border_style)
  }
  if !top || self.title.length() == 0 {
    return @strip.Strip::join([head, bar(span), tail])
  }
  let label = " " + self.title + " "
  let used = @strip.str_cells(label)
  if used >= span {
    return @strip.Strip::join([
      head,
      @strip.Strip::of(clip_to(self.title, span), self.title_style).pad_to(
        span,
        self.title_style,
      ),
      tail,
    ])
  }
  let slack = span - used
  let before = match self.title_align {
    Left => 0
    Centre => slack / 2
    Right => slack
  }
  @strip.Strip::join([
    head,
    bar(before),
    @strip.Strip::of(label, self.title_style),
    bar(slack - before),
    tail,
  ])
}

///|
fn ring_of(border : Border?) -> Int32 {
  match border {
    Some(_) => 1
    None => 0
  }
}

///|
pub extend Block with Widget::{focusable, handle, hint, render_line}
