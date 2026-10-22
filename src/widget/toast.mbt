// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum ToastLevel {
  Information
  Warning
  Error
} derive(Eq, Debug)

///|
pub extend ToastLevel with Debug::{to_repr}

///|
pub extend ToastLevel with Eq::{not_equal, equal}

///|
pub struct Toast {
  title : String
  mut message : String
  level : ToastLevel
  duration : Int32
  mut elapsed : Int32
  style : @style.Style
  title_style : @style.Style
  bar_info : @style.Style
  bar_warning : @style.Style
  bar_error : @style.Style
} derive(Eq, Debug)

///|
pub extend Toast with Debug::{to_repr}

///|
pub extend Toast with Eq::{not_equal, equal}

///|
pub fn Toast::new(
  message : String,
  title~ : String = "",
  level~ : ToastLevel = Information,
  duration~ : Int32 = 4000,
  style~ : @style.Style = @style.Style::new(),
  title_style~ : @style.Style = @style.Style::new(fg=@style.white, bold=true),
) -> Toast {
  {
    title,
    message,
    level,
    duration,
    elapsed: 0,
    style,
    title_style,
    bar_info: @style.Style::new(fg=@style.green),
    bar_warning: @style.Style::new(fg=@style.yellow),
    bar_error: @style.Style::new(fg=@style.red),
  }
}

///|
pub fn Toast::set_message(self : Toast, message : String) -> Unit {
  self.message = message
  self.elapsed = 0
}

///|
pub fn Toast::bar_style(self : Toast) -> @style.Style {
  match self.level {
    Information => self.bar_info
    Warning => self.bar_warning
    Error => self.bar_error
  }
}

///|
pub fn Toast::expired(self : Toast) -> Bool {
  self.duration > 0 && self.elapsed >= self.duration
}

///|
pub impl Widget for Toast with fn render_line(self, row, size) {
  let inner = size.width - 4
  let lines = if inner > 0 {
    wrap_text(self.message, inner)
  } else {
    [self.message]
  }
  let bar = @strip.Seg::new("▌", self.bar_style())
  let pad = @strip.Seg::new(" ", self.style)
  let total = lines.length() + (if self.title == "" { 0 } else { 1 })
  if row < 0 || row >= total {
    return @strip.Strip::blank(size.width, self.style)
  }
  let body = if self.title != "" && row == 0 {
    @strip.Seg::new(self.title, self.title_style)
  } else {
    let index = if self.title == "" { row } else { row - 1 }
    @strip.Seg::new(lines[index], self.style)
  }
  @strip.Strip::from_segs([bar, pad, body]).pad_to(size.width, self.style)
}

///|
pub impl Widget for Toast with fn hint(self, _size) {
  let inner = 60 - 4
  let lines = wrap_text(self.message, if inner > 0 { inner } else { 1 })
  let rows = lines.length() + (if self.title == "" { 0 } else { 1 })
  let mut widest = @strip.str_cells(self.title)
  for line in lines {
    let cells = @strip.str_cells(line)
    if cells > widest {
      widest = cells
    }
  }
  @geom.Size::new(widest + 4, rows)
}

///|
pub impl Widget for Toast with fn focusable(_self) {
  false
}

///|
pub impl Widget for Toast with fn handle(self, ctx, msg) {
  match msg {
    Tick(ms) => {
      if self.duration <= 0 {
        return false
      }
      self.elapsed = self.elapsed + ms
      if self.expired() {
        ctx.emit(Dismissed(id=ctx.id))
      }
      false
    }
    Mouse(_) => {
      if self.expired() {
        return false
      }
      // A click retires a toast early, like a notification dismissed by hand.
      self.elapsed = self.duration
      ctx.emit(Dismissed(id=ctx.id))
      true
    }
    _ => false
  }
}

///|
pub extend Toast with Widget::{focusable, handle, hint, render_line}
