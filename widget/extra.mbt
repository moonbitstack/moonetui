// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum PlaceholderVariant {
  Default
  Size
  Text
} derive(Eq, Debug)

///|
pub struct Placeholder {
  label : String
  mut variant : PlaceholderVariant
  colour : Int32
  style : @style.Style
} derive(Eq, Debug)

///|
pub fn Placeholder::new(
  label~ : String = "Placeholder",
  variant~ : PlaceholderVariant = Default,
  colour~ : Int32 = 0,
  style~ : @style.Style = @style.Style::new(),
) -> Placeholder {
  let paint = placeholder_palette(colour % 12)
  { label, variant, colour, style: { ..style, bg: paint, }, }
}

///|
pub fn Placeholder::variant(self : Placeholder) -> PlaceholderVariant {
  self.variant
}

///|
pub fn Placeholder::cycle(self : Placeholder) -> Unit {
  self.variant = match self.variant {
    Default => Size
    Size => Text
    Text => Default
  }
}

///|
pub impl Widget for Placeholder with fn render_line(self, row, size) {
  let content = match self.variant {
    Default => [self.label]
    Size => ["\{size.width} x \{size.height}"]
    Text => {
      let out : Array[String] = []
      for _ in 0..<5 {
        for line in lorem_lines() {
          out.push(line)
        }
      }
      out
    }
  }
  let middle = if size.height > 0 { (size.height - 1) / 2 } else { 0 }
  let start = middle - content.length() / 2
  let at = row - start
  if at < 0 || at >= content.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  align_line(clip_to(content[at], size.width), size.width, Centre, self.style)
}

///|
pub impl Widget for Placeholder with fn hint(_self, size) {
  size
}

///|
pub impl Widget for Placeholder with fn handle(self, ctx, msg) {
  match msg {
    Mouse(mouse) =>
      if mouse.kind == Down {
        self.cycle()
        ctx.repaint()
        true
      } else {
        false
      }
    _ => false
  }
}

///|
pub impl Widget for Placeholder with fn focusable(_self) {
  false
}

///|
fn placeholder_palette(index : Int32) -> @style.Colour {
  let table : Array[(Int32, Int32, Int32)] = [
    (0x88, 0x11, 0x77),
    (0xAA, 0x33, 0x55),
    (0xCC, 0x66, 0x66),
    (0xEE, 0x99, 0x44),
    (0xEE, 0xDD, 0x00),
    (0x99, 0xDD, 0x55),
    (0x44, 0xDD, 0x88),
    (0x22, 0xCC, 0xBB),
    (0x00, 0xBB, 0xCC),
    (0x00, 0x99, 0xCC),
    (0x33, 0x66, 0xBB),
    (0x66, 0x33, 0x99),
  ]
  let (r, g, b) = table[index]
  @style.Colour::rgb(r, g, b)
}

///|
fn lorem_lines() -> Array[String] {
  [
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam", "feugiat ac elit sit amet accumsan. Suspendisse bibendum nec",
    "libero quis gravida. Phasellus id eleifend ligula. Nullam", "imperdiet sem tellus, sed vehicula nisl faucibus sit amet.",
    "Praesent iaculis tempor ultricies. Sed lacinia, tellus id", "rutrum lacinia, sapien sapien congue mauris, sit amet",
    "pellentesque quam quam vel nisl. Curabitur vulputate erat", "pellentesque mauris posuere, non dictum risus mattis.",
  ]
}

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
pub extend PlaceholderVariant with Debug::{to_repr}

///|
pub extend PlaceholderVariant with Eq::{not_equal, equal}

///|
pub extend Placeholder with Debug::{to_repr}

///|
pub extend Placeholder with Eq::{not_equal, equal}

///|
pub extend Placeholder with Widget::{focusable, handle, hint, render_line}

///|
pub extend LoadingIndicator with Debug::{to_repr}

///|
pub extend LoadingIndicator with Eq::{not_equal, equal}

///|
pub extend LoadingIndicator with Widget::{focusable, handle, hint, render_line}
