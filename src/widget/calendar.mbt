// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A month laid out as a grid, one day picked out: the title, the weekdays and
/// six rows of days, Monday first.
///
/// The arrows walk a day or a week, Page Up and Page Down walk a month, Home
/// and End go to the ends of the month, and a click on a day goes to it.
#derive(Eq, Debug)
pub struct Calendar {
  mut date : @moondate.Date
  style : @style.Style
  title_style : @style.Style
  weekday_style : @style.Style
  day_style : @style.Style
  selected_style : @style.Style
}

///|
/// Days are drawn in three cells, so a month is twenty-one cells wide.
pub let calendar_width : Int32 = 21

///|
pub fn Calendar::new(
  date? : @moondate.Date,
  style~ : @style.Style = @style.default,
  title_style~ : @style.Style = @style.Style::new(bold=true, fg=@style.cyan),
  weekday_style~ : @style.Style = @style.Style::new(dim=true),
  day_style~ : @style.Style = @style.default,
  selected_style~ : @style.Style = @style.Style::new(reverse=true),
) -> Calendar {
  {
    date: date.unwrap_or(@moondate.Date::of_days(0)),
    style,
    title_style,
    weekday_style,
    day_style,
    selected_style,
  }
}

///|
/// A calendar on a day given as three numbers, each held to a real one: a
/// builder for callers that know the date rather than hold a `Date`.
pub fn Calendar::on(
  year : Int32,
  month : Int32,
  day : Int32,
  style~ : @style.Style = @style.default,
  title_style~ : @style.Style = @style.Style::new(bold=true, fg=@style.cyan),
  weekday_style~ : @style.Style = @style.Style::new(dim=true),
  day_style~ : @style.Style = @style.default,
  selected_style~ : @style.Style = @style.Style::new(reverse=true),
) -> Calendar {
  let month = constrain(month, 1, 12)
  let day = constrain(day, 1, @moondate.length(year, month))
  let calendar = Calendar::new(
    style~,
    title_style~,
    weekday_style~,
    day_style~,
    selected_style~,
  )
  // The numbers are held to a day that exists, so the fallback is the epoch
  // and not a value a caller can reach.
  let date = @moondate.Date::new(year, month, day) catch {
    _ => @moondate.Date::of_days(0)
  }
  calendar.set_date(date)
  calendar
}

///|
/// The day picked out.
pub fn Calendar::date(self : Calendar) -> @moondate.Date {
  self.date
}

///|
/// Pick a day out; the month on show follows it.
pub fn Calendar::set_date(self : Calendar, date : @moondate.Date) -> Unit {
  self.date = date
}

///|
/// How many rows a whole month is drawn in, title and weekdays included.
pub fn Calendar::height(_self : Calendar) -> Int32 {
  8
}

///|
fn Calendar::first(self : Calendar) -> @moondate.Date {
  @moondate.Date::plus_days(self.date, 1 - self.date.day)
}

///|
/// The blanks before the first of the month, Monday being the first column.
fn Calendar::lead(self : Calendar) -> Int32 {
  self.first().isoweekday() - 1
}

///|
/// The day number the cell at `row`, `column` of the grid holds, or nothing
/// when the month has no such day.
fn Calendar::day_at(self : Calendar, row : Int32, column : Int32) -> Int32? {
  let day = (row - 2) * 7 + column - self.lead() + 1
  let last = @moondate.length(self.date.year, self.date.month)
  if day < 1 || day > last {
    None
  } else {
    Some(day)
  }
}

///|
pub impl Widget for Calendar with fn render_line(self, row, size) {
  if size.width <= 0 || row < 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  match row {
    0 => {
      let title = months[self.date.month - 1] + " " + self.date.year.to_string()
      @strip.Strip::of(title, self.title_style).pad_to(size.width, self.style)
    }
    1 =>
      @strip.Strip::of(" Mo Tu We Th Fr Sa Su", self.weekday_style).pad_to(
        size.width,
        self.style,
      )
    _ => {
      let cells : Array[@strip.Strip] = []
      for column in 0..<7 {
        match self.day_at(row, column) {
          None => cells.push(@strip.Strip::blank(3, self.style))
          Some(day) => {
            let chosen = day == self.date.day
            let lead = if day < 10 { " " } else { "" }
            let written = lead + day.to_string()
            cells.push(
              @strip.Strip::of(
                written,
                if chosen {
                  self.selected_style
                } else {
                  self.day_style
                },
              ).pad_to(3, if chosen { self.selected_style } else { self.style }),
            )
          }
        }
      }
      @strip.Strip::join(cells).pad_to(size.width, self.style)
    }
  }
}

///|
pub impl Widget for Calendar with fn hint(_self, size) {
  @geom.Size::new(size.width, 8)
}

///|
pub impl Widget for Calendar with fn handle(self, ctx, msg) {
  match msg {
    Focus(_gained) => {
      ctx.repaint()
      true
    }
    Key(key) =>
      if key.mods.is_none() {
        match key.code {
          Left => self.go(self.date.plus_days(-1), ctx)
          Right => self.go(self.date.plus_days(1), ctx)
          Up => self.go(self.date.plus_days(-7), ctx)
          Down => self.go(self.date.plus_days(7), ctx)
          PageUp => self.go(self.date.plus_months(-1), ctx)
          PageDown => self.go(self.date.plus_months(1), ctx)
          Home => self.go(self.first(), ctx)
          End => {
            let next = @moondate.Date::plus_months(self.first(), 1)
            self.go(next.plus_days(-1), ctx)
          }
          _ => false
        }
      } else {
        false
      }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let column = mouse.x / 3
          if column < 0 || column > 6 || mouse.y < 2 {
            return true
          }
          match self.day_at(mouse.y, column) {
            Some(day) => self.go(self.first().plus_days(day - 1), ctx)
            None => true
          }
        }
        ScrollUp => self.go(self.date.plus_months(-1), ctx)
        ScrollDown => self.go(self.date.plus_months(1), ctx)
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Calendar with fn focusable(_self) {
  true
}

///|
/// Pick a day out and say so when it is a different one.
fn Calendar::go(self : Calendar, date : @moondate.Date, ctx : Ctx) -> Bool {
  if date.equal(self.date) {
    return false
  }
  self.date = date
  ctx.emit(Changed(id=ctx.id, value=date.to_string()))
  ctx.emit(Selected(id=ctx.id, index=date.day))
  ctx.repaint()
  true
}

///|
let months : Array[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
pub extend Calendar with Debug::{to_repr}

///|
pub extend Calendar with Eq::{not_equal, equal}

///|
pub extend Calendar with Widget::{focusable, handle, hint, render_line}
