// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct LoadingIndicator {
  mut frame : Int32
  style : @style.Style
  dim_style : @style.Style
} derive(Eq, Debug)

///|
pub fn LoadingIndicator::new(
  style~ : @style.Style = @style.Style::new(),
  dim_style~ : @style.Style = @style.Style::new(dim=true),
) -> LoadingIndicator {
  { frame: 0, style, dim_style, }
}

///|
pub fn LoadingIndicator::frame(self : LoadingIndicator) -> Int32 {
  self.frame
}

///|
pub impl Widget for LoadingIndicator with fn render_line(self, row, size) {
  let segs : Array[@strip.Seg] = []
  for dot in 0..<5 {
    let style = if (self.frame + dot) % 5 == 0 {
      self.style
    } else {
      self.dim_style
    }
    segs.push(@strip.Seg::new("●", style))
    if dot < 4 {
      segs.push(@strip.Seg::new(" ", self.style))
    }
  }
  let dots = @strip.Strip::from_segs(segs)
  let middle = if size.height > 0 { (size.height - 1) / 2 } else { 0 }
  if row != middle || size.width < dots.cell_length() {
    if size.width < dots.cell_length() && row == middle {
      return dots.crop(0, size.width)
    }
    return @strip.Strip::blank(size.width, self.style)
  }
  let left = (size.width - dots.cell_length()) / 2
  @strip.Strip::join([
    @strip.Strip::blank(left, self.style),
    dots,
    @strip.Strip::blank(size.width - left - dots.cell_length(), self.style),
  ])
}

///|
pub impl Widget for LoadingIndicator with fn hint(_self, size) {
  size
}

///|
pub impl Widget for LoadingIndicator with fn handle(self, ctx, msg) {
  match msg {
    Tick(_) => {
      self.frame = self.frame + 1
      ctx.repaint()
      true
    }
    Key(_) | Mouse(_) => true
    _ => false
  }
}

///|
pub impl Widget for LoadingIndicator with fn focusable(_self) {
  false
}

///|
pub extend LoadingIndicator with Debug::{to_repr}

///|
pub extend LoadingIndicator with Eq::{not_equal, equal}

///|
pub extend LoadingIndicator with Widget::{focusable, handle, hint, render_line}
