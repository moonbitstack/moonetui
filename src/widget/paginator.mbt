// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which page of a longer list is on show: an arrow at each end and the pages
/// between them, with the one you are on picked out.
///
/// The arrows step a page, Home and End go to the first and the last, and a
/// click on a number goes to that page.
#derive(Eq, Debug)
pub struct Paginator {
  mut page : Int32
  mut pages : Int32
  style : @style.Style
  current_style : @style.Style
  arrow_style : @style.Style
}

///|
pub fn Paginator::new(
  page~ : Int32 = 0,
  pages~ : Int32 = 1,
  style~ : @style.Style = @style.default,
  current_style~ : @style.Style = @style.Style::new(reverse=true),
  arrow_style~ : @style.Style = @style.Style::new(dim=true),
) -> Paginator {
  let pager : Paginator = {
    page: 0,
    pages: 1,
    style,
    current_style,
    arrow_style,
  }
  pager.set_pages(pages)
  pager.set_page(page)
  pager
}

///|
/// The page on show, counted from nothing.
pub fn Paginator::page(self : Paginator) -> Int32 {
  self.page
}

///|
/// How many pages there are.
pub fn Paginator::pages(self : Paginator) -> Int32 {
  self.pages
}

///|
/// How many pages there are, held to at least one, with the page on show kept
/// inside them.
pub fn Paginator::set_pages(self : Paginator, pages : Int32) -> Unit {
  self.pages = at_least_one(pages)
  self.page = constrain(self.page, 0, self.pages - 1)
}

///|
/// Go to a page, held to the ones there are.
pub fn Paginator::set_page(self : Paginator, page : Int32) -> Unit {
  self.page = constrain(page, 0, self.pages - 1)
}

///|
/// The width one page number takes: its digits and the space after it.
fn Paginator::slot(self : Paginator) -> Int32 {
  let mut digits = 1
  let mut rest = self.pages
  while rest > 9 {
    digits = digits + 1
    rest = rest / 10
  }
  digits + 1
}

///|
/// Where each thing on the row sits: a page number, or the ellipsis that
/// stands for the ones left out, which answers -1.
fn Paginator::layout(
  self : Paginator,
  width : Int32,
) -> Array[(Int32, Int32, Int32)] {
  let out : Array[(Int32, Int32, Int32)] = []
  if width <= 0 {
    return out
  }
  let slot = self.slot()
  // Two cells for the arrows, and the space an ellipsis needs at each end.
  let room = at_least_zero(width - 4)
  let all = self.pages * slot
  let mut first = 0
  let mut shown = self.pages
  if all > room {
    shown = at_least_one((room - 2) / slot)
    first = self.page - shown / 2
    first = constrain(first, 0, at_least_zero(self.pages - shown))
  }
  let mut at = 2
  if first > 0 {
    out.push((at, 1, -1))
    at = at + 1
  }
  for i in 0..<shown {
    out.push((at, slot, first + i))
    at = at + slot
  }
  if first + shown < self.pages {
    out.push((at, 1, -1))
  }
  out
}

///|
/// The page a click at `x` lands on, if it lands on one.
fn Paginator::page_at(self : Paginator, x : Int32, width : Int32) -> Int32? {
  for slot in self.layout(width) {
    let (at, span, page) = slot
    if page >= 0 && x >= at && x < at + span {
      return Some(page)
    }
  }
  None
}

///|
pub impl Widget for Paginator with fn render_line(self, row, size) {
  if size.width <= 0 || row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let cells : Array[@strip.Strip] = [@strip.Strip::of("‹ ", self.arrow_style)]
  for slot in self.layout(size.width) {
    let (_, span, page) = slot
    if page < 0 {
      cells.push(@strip.Strip::of("…", self.arrow_style))
    } else {
      let ink = if page == self.page { self.current_style } else { self.style }
      let written = (page + 1).to_string()
      cells.push(@strip.Strip::of(written, ink).pad_to(span, ink))
    }
  }
  cells.push(@strip.Strip::of(" ›", self.arrow_style))
  @strip.Strip::join(cells).pad_to(size.width, self.style)
}

///|
pub impl Widget for Paginator with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Paginator with fn handle(self, ctx, msg) {
  match msg {
    Focus(_gained) => {
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        match key.code {
          Left | Up => self.go(self.page - 1, ctx)
          Right | Down => self.go(self.page + 1, ctx)
          Home => self.go(0, ctx)
          End => self.go(self.pages - 1, ctx)
          _ => false
        }
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          match self.page_at(mouse.x, ctx.size.width) {
            Some(page) => self.go(page, ctx)
            None => true
          }
        }
        ScrollUp => self.go(self.page - 1, ctx)
        ScrollDown => self.go(self.page + 1, ctx)
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Paginator with fn focusable(_self) {
  true
}

///|
/// Go to a page and say so when it is a different one.
fn Paginator::go(self : Paginator, page : Int32, ctx : Ctx) -> Bool {
  let next = constrain(page, 0, self.pages - 1)
  if next == self.page {
    return false
  }
  self.page = next
  ctx.emit(Selected(id=ctx.id, index=next))
  ctx.repaint()
  true
}

///|
pub extend Paginator with Debug::{to_repr}

///|
pub extend Paginator with Eq::{not_equal, equal}

///|
pub extend Paginator with Widget::{focusable, handle, hint, render_line}
