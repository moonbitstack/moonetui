// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One line of a menu: a label, the keys that do the same thing, a tick for
/// a setting that is on, or a rule between two groups of them.
pub(all) struct Item {
  label : String
  shortcut : String
  checked : Bool
  enabled : Bool
  rule : Bool
} derive(Eq, Debug)

///|
pub fn Item::new(
  label : String,
  shortcut~ : String = "",
  checked~ : Bool = false,
  enabled~ : Bool = true,
) -> Item {
  { label, shortcut, checked, enabled, rule: false, }
}

///|
pub fn Item::separator() -> Item {
  { label: "", shortcut: "", checked: false, enabled: false, rule: true, }
}

///|
pub fn Item::is_separator(self : Item) -> Bool {
  self.rule
}

///|
pub fn Item::is_enabled(self : Item) -> Bool {
  self.enabled && !self.rule
}

///|
/// A list of items in a frame: what drops from a menu bar, and what stands on
/// its own as a popup.
///
/// The arrows move over the items, skipping rules and what is off, Enter takes
/// the one highlighted and Escape closes without taking one.
pub struct Menu {
  mut items : Array[Item]
  mut highlighted : Int32
  mut taken : Int32
  mut focused : Bool
  style : @style.Style
  dim_style : @style.Style
  shortcut_style : @style.Style
  border_style : @style.Style
  highlight : @style.Style
  blurred_highlight : @style.Style
}

///|
pub fn Menu::new(
  items~ : Array[Item] = [],
  style~ : @style.Style = @style.default,
  dim_style~ : @style.Style = @style.Style::new(dim=true),
  shortcut_style~ : @style.Style = @style.Style::new(dim=true),
  border_style~ : @style.Style = @style.default,
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  blurred_highlight~ : @style.Style = @style.Style::new(dim=true, reverse=true),
) -> Menu {
  let menu : Menu = {
    items,
    highlighted: -1,
    taken: -1,
    focused: false,
    style,
    dim_style,
    shortcut_style,
    border_style,
    highlight,
    blurred_highlight,
  }
  menu.first_item()
  menu
}

///|
pub fn Menu::set_items(self : Menu, items : Array[Item]) -> Unit {
  self.items = items
  self.first_item()
}

///|
pub fn Menu::items(self : Menu) -> Array[Item] {
  self.items
}

///|
pub fn Menu::highlighted(self : Menu) -> Int32 {
  self.highlighted
}

///|
/// The item taken, if one has been.
pub fn Menu::taken(self : Menu) -> Int32? {
  if self.taken >= 0 && self.taken < self.items.length() {
    Some(self.taken)
  } else {
    None
  }
}

///|
/// The columns the widest item needs, frame included.
pub fn Menu::width_of(self : Menu) -> Int32 {
  let mut widest = 0
  for item in self.items {
    let cells = @strip.str_cells(item.label) +
      (if item.checked { 2 } else { 0 }) +
      (if item.shortcut.length() > 0 {
        @strip.str_cells(item.shortcut) + 2
      } else {
        0
      })
    if cells > widest {
      widest = cells
    }
  }
  widest + 6
}

///|
pub impl Widget for Menu with fn render_line(self, row, size) {
  if size.width < 2 || size.height < 2 {
    return @strip.Strip::blank(size.width, self.style)
  }
  if row == 0 || row == size.height - 1 {
    return frame_edge(
      size,
      "",
      self.border_style,
      self.border_style,
      top=row == 0,
    )
  }
  let inner_w = size.width - 2
  let at = row - 1
  if at >= self.items.length() {
    return @strip.Strip::join([
      @strip.Strip::of("│", self.border_style),
      @strip.Strip::blank(inner_w, self.style),
      @strip.Strip::of("│", self.border_style),
    ])
  }
  let item = self.items[at]
  if item.rule {
    return @strip.Strip::of(
      "├" + repeat_glyph("─", inner_w) + "┤",
      self.border_style,
    )
  }
  let body = {
    let on = at == self.highlighted
    let ground = if on {
      if self.focused {
        self.highlight
      } else {
        self.blurred_highlight
      }
    } else {
      self.style
    }
    let lead = if item.checked { "✓ " } else { "  " }
    let text = if item.enabled { ground } else { self.dim_style }
    let room = at_least_zero(inner_w - 2 - @strip.str_cells(item.shortcut))
    @strip.Strip::join([
      @strip.Strip::of(" ", ground),
      @strip.Strip::of(lead, ground),
      @strip.Strip::of(clip_to(item.label, room - 2), text).pad_to(
        at_least_zero(room - 2),
        ground,
      ),
      @strip.Strip::of(item.shortcut, self.shortcut_style),
      @strip.Strip::of(" ", ground),
    ])
  }
  @strip.Strip::join([
    @strip.Strip::of("│", self.border_style),
    body.pad_to(inner_w, self.style),
    @strip.Strip::of("│", self.border_style),
  ])
}

///|
pub impl Widget for Menu with fn hint(self, size) {
  let width = if self.width_of() < size.width {
    self.width_of()
  } else {
    size.width
  }
  @geom.Size::new(width, self.items.length() + 2)
}

///|
pub impl Widget for Menu with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key)
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let at = mouse.y - 1
          if at >= 0 && at < self.items.length() && self.items[at].is_enabled() {
            self.take(at, ctx)
          }
          true
        }
        Move => {
          let at = mouse.y - 1
          if at >= 0 &&
            at < self.items.length() &&
            self.items[at].is_enabled() &&
            at != self.highlighted {
            self.highlighted = at
            ctx.repaint()
          }
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Menu with fn focusable(_self) {
  true
}

///|
fn Menu::key(self : Menu, ctx : Ctx, key : @event.Key) -> Bool {
  if !key.mods.is_none() {
    return false
  }
  match key.code {
    Up => self.step(-1, ctx)
    Down => self.step(1, ctx)
    Home => self.move_to(0, ctx)
    End => self.move_to(self.items.length() - 1, ctx)
    Enter | Char(32) =>
      match self.highlighted {
        -1 => false
        at => {
          self.take(at, ctx)
          true
        }
      }
    Escape => {
      ctx.emit(Dismissed(id=ctx.id))
      true
    }
    _ => false
  }
}

///|
fn Menu::first_item(self : Menu) -> Unit {
  self.highlighted = -1
  self.step(1, Ctx::new(0, @geom.Size::new(1, 1))) |> ignore
}

///|
fn Menu::step(self : Menu, by : Int32, ctx : Ctx) -> Bool {
  let count = self.items.length()
  if count == 0 {
    return false
  }
  let mut probe = if self.highlighted < 0 {
    if by > 0 {
      -1
    } else {
      count
    }
  } else {
    self.highlighted
  }
  let mut steps = 0
  while steps < count {
    probe = probe + by
    if probe < 0 {
      probe = count - 1
    } else if probe >= count {
      probe = 0
    }
    if self.items[probe].is_enabled() {
      if probe == self.highlighted {
        return true
      }
      self.highlighted = probe
      ctx.repaint()
      return true
    }
    steps = steps + 1
  }
  false
}

///|
fn Menu::move_to(self : Menu, place : Int32, ctx : Ctx) -> Bool {
  let count = self.items.length()
  if count == 0 {
    return false
  }
  let mut probe = constrain(place, 0, count - 1)
  let mut steps = 0
  while steps < count {
    if self.items[probe].is_enabled() {
      if probe == self.highlighted {
        return true
      }
      self.highlighted = probe
      ctx.repaint()
      return true
    }
    probe = probe + 1
    if probe >= count {
      probe = 0
    }
    steps = steps + 1
  }
  false
}

///|
fn Menu::take(self : Menu, index : Int32, ctx : Ctx) -> Unit {
  if index < 0 ||
    index >= self.items.length() ||
    !self.items[index].is_enabled() {
    return
  }
  self.taken = index
  ctx.emit(Selected(id=ctx.id, index~))
  ctx.repaint()
}

///|
/// The titles along the top of a screen, and the list each one drops.
///
/// The bar is one row until a menu is open, when it grows to hold that menu
/// underneath its title, the way a select grows to hold its options. The
/// arrows move along the bar and then down the items, Enter opens and takes,
/// and Escape closes.
pub struct MenuBar {
  titles : Array[String]
  menus : Array[Menu]
  mut at : Int32
  mut open : Int32
  mut picked : (Int32, Int32)?
  mut focused : Bool
  style : @style.Style
  bar_style : @style.Style
  highlight : @style.Style
  open_style : @style.Style
}

///|
pub fn MenuBar::new(
  style~ : @style.Style = @style.default,
  bar_style~ : @style.Style = @style.default,
  highlight~ : @style.Style = @style.Style::new(reverse=true),
  open_style~ : @style.Style = @style.Style::new(reverse=true),
) -> MenuBar {
  {
    titles: [],
    menus: [],
    at: -1,
    open: -1,
    picked: None,
    focused: false,
    style,
    bar_style,
    highlight,
    open_style,
  }
}

///|
pub fn MenuBar::add(
  self : MenuBar,
  title : String,
  items : Array[Item],
) -> Unit {
  self.titles.push(title)
  self.menus.push(Menu::new(items~))
  if self.at < 0 {
    self.at = 0
  }
}

///|
pub fn MenuBar::titles(self : MenuBar) -> Array[String] {
  self.titles
}

///|
/// Whether a list is showing, and which one.
pub fn MenuBar::is_open(self : MenuBar) -> Bool {
  self.open >= 0
}

///|
pub fn MenuBar::opened(self : MenuBar) -> Int32 {
  self.open
}

///|
pub fn MenuBar::close(self : MenuBar) -> Unit {
  self.open = -1
}

///|
/// The menu and the item last taken, as a pair.
pub fn MenuBar::taken(self : MenuBar) -> (Int32, Int32)? {
  self.picked
}

///|
pub impl Widget for MenuBar with fn render_line(self, row, size) {
  if size.width <= 0 || size.height <= 0 {
    return @strip.Strip::empty()
  }
  if row == 0 {
    let segs : Array[@strip.Strip] = []
    for i in 0..<self.titles.length() {
      let ground = if i == self.at {
        if self.open >= 0 {
          self.open_style
        } else if self.focused {
          self.highlight
        } else {
          self.style
        }
      } else {
        self.bar_style
      }
      segs.push(@strip.Strip::of(" " + self.titles[i] + " ", ground))
    }
    return @strip.Strip::join(segs).pad_to(size.width, self.bar_style)
  }
  if self.open < 0 || self.open >= self.menus.length() {
    return @strip.Strip::blank(size.width, self.style)
  }
  let menu = self.menus[self.open]
  let left = self.drop_left(size.width, menu)
  let width = self.drop_width(size.width, menu)
  let height = smallest(menu.items.length() + 2, size.height - 1)
  if row >= height + 1 || width <= 0 {
    return @strip.Strip::blank(size.width, self.style)
  }
  let dropped = menu.render_line(row - 1, @geom.Size::new(width, height))
  @strip.Strip::join([
    @strip.Strip::blank(left, self.style),
    dropped,
    @strip.Strip::blank(at_least_zero(size.width - left - width), self.style),
  ])
}

///|
pub impl Widget for MenuBar with fn hint(self, size) {
  if self.open < 0 || self.open >= self.menus.length() {
    return @geom.Size::new(size.width, 1)
  }
  let menu = self.menus[self.open]
  let rows = smallest(menu.items.length() + 2, size.height - 1)
  @geom.Size::new(size.width, 1 + at_least_zero(rows))
}

///|
pub impl Widget for MenuBar with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      if !gained {
        self.open = -1
      }
      ctx.repaint()
      true
    }
    Key(key) => self.key(ctx, key)
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          if mouse.y == 0 {
            match self.title_at(mouse.x) {
              Some(index) =>
                if self.open == index {
                  self.open = -1
                  ctx.repaint()
                } else {
                  self.open = index
                  self.at = index
                  ctx.repaint()
                }
              None => ()
            }
          } else if self.open >= 0 && self.open < self.menus.length() {
            let menu = self.menus[self.open]
            let left = self.drop_left(ctx.size.width, menu)
            let width = self.drop_width(ctx.size.width, menu)
            let inside = { ..mouse, x: mouse.x - left, y: mouse.y - 1, }
            if inside.x >= 0 && inside.x < width {
              let inner = Ctx::new(
                ctx.id,
                @geom.Size::new(width, ctx.size.height - 1),
                focused=true,
              )
              menu.handle(inner, Mouse(inside)) |> ignore
              for out in inner.asked() {
                match out {
                  Selected(index~, ..) => self.choose(self.open, index, ctx)
                  TakeFocus(..) | Repaint(..) => ()
                  _ => ctx.emit(out)
                }
              }
            }
          }
          true
        }
        Move =>
          if mouse.y == 0 {
            match self.title_at(mouse.x) {
              Some(index) =>
                if index != self.at {
                  self.at = index
                  ctx.repaint()
                }
              None => ()
            }
            true
          } else {
            false
          }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for MenuBar with fn focusable(_self) {
  true
}

///|
fn MenuBar::key(self : MenuBar, ctx : Ctx, key : @event.Key) -> Bool {
  if !key.mods.is_none() || self.titles.length() == 0 {
    return false
  }
  if self.open >= 0 {
    let menu = self.menus[self.open]
    match key.code {
      Left => self.along(-1, ctx)
      Right => self.along(1, ctx)
      Escape => {
        self.open = -1
        ctx.repaint()
        true
      }
      Up => self.in_menu(menu, -1, ctx)
      Down => self.in_menu(menu, 1, ctx)
      Home => self.in_menu_to(menu, 0, ctx)
      End => self.in_menu_to(menu, menu.items.length() - 1, ctx)
      Enter | Char(32) =>
        match menu.highlighted {
          -1 => false
          at => {
            self.choose(self.open, at, ctx)
            true
          }
        }
      _ => false
    }
  } else {
    match key.code {
      Left => self.along(-1, ctx)
      Right => self.along(1, ctx)
      Down | Enter => {
        self.open = self.at
        ctx.repaint()
        true
      }
      Escape => false
      Char(code) =>
        match code.to_char() {
          Some(letter) => self.by_letter(letter.to_string(), ctx)
          None => false
        }
      _ => false
    }
  }
}

///|
/// Move along the bar, taking the open list with it.
fn MenuBar::along(self : MenuBar, by : Int32, ctx : Ctx) -> Bool {
  let count = self.titles.length()
  let next = (self.at + by + count) % count
  self.at = next
  if self.open >= 0 {
    self.open = next
  }
  ctx.repaint()
  true
}

///|
fn MenuBar::by_letter(self : MenuBar, letter : String, ctx : Ctx) -> Bool {
  let needle = letter.to_lower()
  for i in 0..<self.titles.length() {
    if self.titles[i].length() > 0 &&
      self.titles[i].to_lower().view(start_offset=0, end_offset=1) == needle {
      self.at = i
      ctx.repaint()
      return true
    }
  }
  false
}

///|
fn MenuBar::in_menu(
  _self : MenuBar,
  menu : Menu,
  by : Int32,
  ctx : Ctx,
) -> Bool {
  let inner = Ctx::new(
    ctx.id,
    @geom.Size::new(menu.width_of(), 4),
    focused=true,
  )
  let took = menu.step(by, inner)
  if took {
    ctx.repaint()
  }
  took
}

///|
fn MenuBar::in_menu_to(
  _self : MenuBar,
  menu : Menu,
  place : Int32,
  ctx : Ctx,
) -> Bool {
  let inner = Ctx::new(
    ctx.id,
    @geom.Size::new(menu.width_of(), 4),
    focused=true,
  )
  let took = menu.move_to(place, inner)
  if took {
    ctx.repaint()
  }
  took
}

///|
/// Take an item of an open list: the message carries the list and the item,
/// and the bar closes.
fn MenuBar::choose(
  self : MenuBar,
  menu : Int32,
  index : Int32,
  ctx : Ctx,
) -> Unit {
  self.picked = Some((menu, index))
  self.open = -1
  ctx.emit(MenuPicked(id=ctx.id, menu~, index~))
  ctx.repaint()
}

///|
fn MenuBar::title_at(self : MenuBar, x : Int32) -> Int32? {
  let mut at = 0
  for i in 0..<self.titles.length() {
    let span = @strip.str_cells(self.titles[i]) + 2
    if x < at + span {
      return Some(i)
    }
    at = at + span
  }
  None
}

///|
/// Where a title's list starts, which is where the title does.
fn MenuBar::title_left(self : MenuBar, index : Int32) -> Int32 {
  let mut at = 0
  for i in 0..<index {
    at = at + @strip.str_cells(self.titles[i]) + 2
  }
  at
}

///|
fn MenuBar::drop_width(_self : MenuBar, room : Int32, menu : Menu) -> Int32 {
  let wanted = menu.width_of()
  if wanted < room {
    wanted
  } else {
    room
  }
}

///|
/// A list drops under its own title, but never off the right edge.
fn MenuBar::drop_left(self : MenuBar, room : Int32, menu : Menu) -> Int32 {
  let wanted = self.title_left(self.open)
  let width = self.drop_width(room, menu)
  let most = at_least_zero(room - width)
  if wanted < most {
    wanted
  } else {
    most
  }
}

///|
pub extend Item with Debug::{to_repr}

///|
pub extend Item with Eq::{not_equal, equal}

///|
pub extend Menu with Widget::{focusable, handle, hint, render_line}

///|
pub extend MenuBar with Widget::{focusable, handle, hint, render_line}
