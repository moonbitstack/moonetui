// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A number chosen along a line: the track, the thumb, and the value written
/// after it.
///
/// The arrows move it by one step, Page Up and Page Down by ten, Home and End
/// to the ends, and a click on the track goes to the place it landed on.
#derive(Eq, Debug)
pub struct Slider {
  mut value : Int32
  low : Int32
  high : Int32
  step : Int32
  mut focused : Bool
  style : @style.Style
  track_style : @style.Style
  bar_style : @style.Style
  thumb_style : @style.Style
}

///|
pub fn Slider::new(
  value~ : Int32 = 0,
  low~ : Int32 = 0,
  high~ : Int32 = 100,
  step~ : Int32 = 1,
  style~ : @style.Style = @style.default,
  track_style~ : @style.Style = @style.Style::new(dim=true),
  bar_style~ : @style.Style = @style.Style::new(fg=@style.cyan),
  thumb_style~ : @style.Style = @style.Style::new(
    fg=@style.bright_cyan,
    bold=true,
  ),
) -> Slider {
  let slider : Slider = {
    value: 0,
    low,
    high,
    step,
    focused: false,
    style,
    track_style,
    bar_style,
    thumb_style,
  }
  slider.set_value(value)
  slider
}

///|
pub fn Slider::value(self : Slider) -> Int32 {
  self.value
}

///|
/// Where the ends of the track are.
pub fn Slider::bounds(self : Slider) -> (Int32, Int32) {
  (self.low, self.high)
}

///|
/// How far one press of an arrow moves it.
pub fn Slider::step(self : Slider) -> Int32 {
  self.step
}

///|
/// Choose a number, held between the ends.
pub fn Slider::set_value(self : Slider, value : Int32) -> Unit {
  self.value = constrain(value, self.low, self.high)
}

///|
/// How far along the track the value is, from nothing to all of it.
pub fn Slider::ratio(self : Slider) -> Double {
  let travel = self.high - self.low
  if travel <= 0 {
    0.0
  } else {
    (self.value - self.low).to_double() / travel.to_double()
  }
}

///|
/// How much of the track the bar takes before the thumb.
fn Slider::travel(self : Slider) -> Int32 {
  self.high - self.low
}

///|
/// The cells the number takes: the widest one it can hold, so the track stays
/// where it is while the number grows a digit.
fn Slider::field(self : Slider) -> Int32 {
  let low = @strip.str_cells(self.low.to_string())
  let high = @strip.str_cells(self.high.to_string())
  if low > high {
    low
  } else {
    high
  }
}

///|
/// The cell of a track `width` cells long that the value sits on.
fn Slider::place(self : Slider, width : Int32) -> Int32 {
  if width <= 1 || self.travel() <= 0 {
    return 0
  }
  let span = (width - 1).to_double()
  (self.ratio() * span + 0.5).to_int()
}

///|
/// The number a click at `x` on a track `width` cells long asks for.
fn Slider::value_at(self : Slider, x : Int32, width : Int32) -> Int32 {
  if width <= 1 || self.travel() <= 0 {
    return self.value
  }
  let place = constrain(x, 0, width - 1)
  let ratio = place.to_double() / (width - 1).to_double()
  self.low + (ratio * self.travel().to_double() + 0.5).to_int()
}

///|
pub impl Widget for Slider with fn render_line(self, row, size) {
  if size.width <= 0 || row != 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let written = self.value.to_string()
  let field = self.field()
  let room = size.width - field - 1
  if room < 1 {
    return @strip.Strip::of(clip_to(written, size.width), self.style).pad_to(
      size.width,
      self.style,
    )
  }
  let track = room
  let place = self.place(track)
  let cells : Array[@strip.Strip] = []
  for i in 0..<track {
    if i == place {
      cells.push(@strip.Strip::of("●", self.thumb_style))
    } else if i < place {
      cells.push(@strip.Strip::of("━", self.bar_style))
    } else {
      cells.push(@strip.Strip::of("─", self.track_style))
    }
  }
  @strip.Strip::join([
    @strip.Strip::join(cells),
    @strip.Strip::of(
      " " + repeat_glyph(" ", field - @strip.str_cells(written)) + written,
      self.style,
    ),
  ])
}

///|
pub impl Widget for Slider with fn hint(_self, size) {
  @geom.Size::new(size.width, 1)
}

///|
pub impl Widget for Slider with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        let by = match key.code {
          Left | Down => -self.step
          Right | Up => self.step
          PageUp => -10 * self.step
          PageDown => 10 * self.step
          Home => self.low - self.value
          End => self.high - self.value
          _ => return false
        }
        self.move_to(self.value + by, ctx)
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let room = ctx.size.width - self.field() - 1
          self.move_to(self.value_at(mouse.x, at_least_zero(room)), ctx)
        }
        ScrollUp => self.move_to(self.value - self.step, ctx)
        ScrollDown => self.move_to(self.value + self.step, ctx)
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Slider with fn focusable(_self) {
  true
}

///|
/// Move to a number and say so when it is a different one.
fn Slider::move_to(self : Slider, value : Int32, ctx : Ctx) -> Bool {
  let next = constrain(value, self.low, self.high)
  if next == self.value {
    return false
  }
  self.value = next
  ctx.emit(Changed(id=ctx.id, value=next.to_string()))
  ctx.repaint()
  true
}

///|
pub extend Slider with Debug::{to_repr}

///|
pub extend Slider with Eq::{not_equal, equal}

///|
pub extend Slider with Widget::{focusable, handle, hint, render_line}
