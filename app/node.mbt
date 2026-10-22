// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub enum Node {
  Leaf(
    id~ : Int32,
    widget~ : &@widget.Widget,
    box~ : @layout.Box,
    name~ : String,
    classes~ : Array[String],
    styles~ : @design.Styles
  )
  Stack(
    id~ : Int32,
    dir~ : @layout.Dir,
    box~ : @layout.Box,
    gap~ : Int32,
    kids~ : Array[Node],
    name~ : String,
    classes~ : Array[String],
    styles~ : @design.Styles
  )
  Scroll(
    id~ : Int32,
    kid~ : Node,
    box~ : @layout.Box,
    state~ : ScrollState,
    bar~ : @style.Style,
    name~ : String,
    classes~ : Array[String],
    styles~ : @design.Styles
  )
}

///|
pub(all) struct Theme {
  sheet : @design.Stylesheet
  focus : Int32
  base : @style.Style
} derive(Eq, Debug)

///|
pub extend Theme with Debug::{to_repr}

///|
pub extend Theme with Eq::{not_equal, equal}

///|
pub fn Theme::new(
  sheet~ : @design.Stylesheet = @design.Stylesheet::new(),
  focus~ : Int32 = -1,
  base~ : @style.Style = @style.default,
) -> Theme {
  { sheet, focus, base, }
}

///|
pub fn leaf(
  id : Int32,
  widget : &@widget.Widget,
  box~ : @layout.Box = @layout.Box::new(),
  name~ : String = "",
  classes~ : Array[String] = [],
  styles~ : @design.Styles = @design.empty,
) -> Node {
  Leaf(id~, widget~, box~, name~, classes~, styles~)
}

///|
pub fn column(
  id : Int32,
  kids : Array[Node],
  box~ : @layout.Box = @layout.Box::new(extent=Frac(1)),
  gap~ : Int32 = 0,
  name~ : String = "",
  classes~ : Array[String] = [],
  styles~ : @design.Styles = @design.empty,
) -> Node {
  Stack(id~, dir=Vertical, box~, gap~, kids~, name~, classes~, styles~)
}

///|
pub fn row(
  id : Int32,
  kids : Array[Node],
  box~ : @layout.Box = @layout.Box::new(extent=Frac(1)),
  gap~ : Int32 = 0,
  name~ : String = "",
  classes~ : Array[String] = [],
  styles~ : @design.Styles = @design.empty,
) -> Node {
  Stack(id~, dir=Horizontal, box~, gap~, kids~, name~, classes~, styles~)
}

///|
pub fn scroll(
  id : Int32,
  kid : Node,
  box~ : @layout.Box = @layout.Box::new(extent=Frac(1)),
  state~ : ScrollState = ScrollState::new(),
  bar~ : @style.Style = @style.Style::new(reverse=true),
  name~ : String = "",
  classes~ : Array[String] = [],
  styles~ : @design.Styles = @design.empty,
) -> Node {
  Scroll(id~, kid~, box~, state~, bar~, name~, classes~, styles~)
}

///|
pub fn Node::id(self : Node) -> Int32 {
  match self {
    Leaf(id~, ..) => id
    Stack(id~, ..) => id
    Scroll(id~, ..) => id
  }
}

///|
pub fn Node::box(self : Node) -> @layout.Box {
  match self {
    Leaf(box~, ..) => box
    Stack(box~, ..) => box
    Scroll(box~, ..) => box
  }
}

///|
pub fn Node::resolve(
  self : Node,
  theme : Theme,
  inherited : @style.Style,
) -> @design.Resolved {
  let (name, id, classes, styles) = match self {
    Leaf(name~, id~, classes~, styles~, ..) => (name, id, classes, styles)
    Stack(name~, id~, classes~, styles~, ..) => (name, id, classes, styles)
    Scroll(name~, id~, classes~, styles~, ..) => (name, id, classes, styles)
  }
  let rules = theme.sheet.pick(name, id, classes, theme.focus == id)
  @design.Resolved::of(rules.merge(styles), inherited)
}

///|
pub fn Node::hint(
  self : Node,
  space : @geom.Size,
  dir : @layout.Dir,
  theme~ : Theme = Theme::new(),
) -> Int32 {
  let res = self.resolve(theme, @style.default)
  let chrome = outer_extent(res, dir)
  match self {
    Leaf(widget~, ..) => @layout.main_of(widget.hint(space), dir) + chrome
    Scroll(kid~, ..) => kid.hint(space, dir, theme~) + chrome
    Stack(dir=own_dir, gap~, kids~, ..) => {
      let mut total = 0
      let mut widest = 0
      let mut shown = 0
      for kid in kids {
        if kid.resolve(theme, @style.default).hidden {
          continue
        }
        let want = kid.hint(space, dir, theme~)
        total = total + want
        if want > widest {
          widest = want
        }
        shown = shown + 1
      }
      if own_dir == dir {
        total + gap * at_least_zero(shown - 1) + chrome
      } else {
        widest + chrome
      }
    }
  }
}

///|
fn outer_extent(res : @design.Resolved, dir : @layout.Dir) -> Int32 {
  let ring = match res.border {
    @design.Off => 0
    _ => 2
  }
  let pad = match dir {
    Vertical => res.padding.height()
    Horizontal => res.padding.width()
  }
  let margin = match dir {
    Vertical => res.margin.height()
    Horizontal => res.margin.width()
  }
  ring + pad + margin
}

///|
pub fn Node::place(
  self : Node,
  area : @geom.Region,
  clip : @geom.Region,
  scene : @comp.Scene,
  rects : Map[Int32, @geom.Region],
  styled~ : Map[Int32, @design.Resolved] = Map([]),
  theme~ : Theme = Theme::new(),
  inherited~ : @style.Style = @style.default,
  views~ : Map[Int32, View] = Map([]),
  bare~ : Map[Int32, @geom.Region] = Map([]),
) -> Unit {
  let res = self.resolve(theme, inherited)
  if res.hidden {
    return
  }
  let framed = res.margin.shrink_region(area)
  let visible = framed.intersection(clip)
  rects[self.id()] = visible
  bare[self.id()] = framed
  match self {
    Leaf(id~, widget~, ..) => {
      ignore(widget)
      scene.place(id, framed, clip)
      styled[id] = res
    }
    Stack(id~, dir~, gap~, kids~, ..) => {
      let content = res.content_region(framed)
      let shown : Array[(Node, @design.Resolved)] = []
      for kid in kids {
        let kid_res = kid.resolve(theme, res.text)
        if !kid_res.hidden {
          shown.push((kid, kid_res))
        }
      }
      let boxes : Array[@layout.Box] = []
      let wants : Array[Int32] = []
      for pair in shown {
        boxes.push(pair.1.box(dir, pair.0.box()))
        wants.push(pair.0.hint(content.size(), dir, theme~))
      }
      let slots = @layout.arrange(content, dir, boxes, wants, gap~)
      let mut used = 0
      for slot in slots {
        used = used + @layout.main_of(slot.size(), dir)
      }
      used = used + gap * at_least_zero(shown.length() - 1)
      let slack = @layout.main_of(content.size(), dir) - used
      let shift : @geom.Offset = match dir {
        Vertical => { x: 0, y: res.align.main_offset(dir, slack), }
        Horizontal => { x: res.align.main_offset(dir, slack), y: 0, }
      }
      for i in 0..<shown.length() {
        let (kid, _) = shown[i]
        kid.place(
          slots[i].translate(shift),
          visible,
          scene,
          rects,
          styled~,
          theme~,
          inherited=res.text,
          views~,
          bare~,
        )
      }
      // Placed after the children so the chrome lands behind them: the first
      // placement covering a column wins it.
      if res.has_chrome() {
        scene.place(id, framed, clip)
        styled[id] = res
      }
    }
    Scroll(id~, kid~, state~, bar~, ..) => {
      let content = res.content_region(framed)
      let want_h = kid.hint(content.size(), Vertical, theme~)
      let want_w = kid.hint(content.size(), Horizontal, theme~)
      let vbar = content.height > 0 && want_h > content.height
      let hbar = content.width > 0 && want_w > content.width
      let vw = if vbar {
        at_least_zero(content.width - 1)
      } else {
        content.width
      }
      let vh = if hbar {
        at_least_zero(content.height - 1)
      } else {
        content.height
      }
      state.vw = vw
      state.vh = vh
      state.cw = if want_w > vw { want_w } else { vw }
      state.ch = if want_h > vh { want_h } else { vh }
      state.scroll_to() |> ignore
      let inner = @geom.Region::new(content.x, content.y, vw, vh)
      let child = @geom.Region::new(
        content.x - state.x,
        content.y - state.y,
        state.cw,
        state.ch,
      )
      kid.place(
        child,
        inner.intersection(visible),
        scene,
        rects,
        styled~,
        theme~,
        inherited=res.text,
        views~,
        bare~,
      )
      views[id] = { state, bar, vbar, hbar, }
      styled[id] = res
      if res.has_chrome() || vbar || hbar {
        scene.place(id, framed, clip)
      }
    }
  }
}

///|
pub fn Node::find(self : Node, id : Int32) -> &@widget.Widget? {
  match self {
    Leaf(id=own, widget~, ..) => if own == id { Some(widget) } else { None }
    Stack(kids~, ..) => {
      for kid in kids {
        match kid.find(id) {
          Some(found) => return Some(found)
          None => ()
        }
      }
      None
    }
    Scroll(kid~, ..) => kid.find(id)
  }
}

///|
pub fn Node::focus_ring(self : Node) -> Array[Int32] {
  let out : Array[Int32] = []
  self.collect_focusable(out)
  out
}

///|
fn Node::collect_focusable(self : Node, out : Array[Int32]) -> Unit {
  match self {
    Leaf(id~, widget~, ..) => if widget.focusable() { out.push(id) }
    Stack(kids~, ..) =>
      for kid in kids {
        kid.collect_focusable(out)
      }
    Scroll(id~, kid~, ..) => {
      out.push(id)
      kid.collect_focusable(out)
    }
  }
}

///|
pub fn Node::contains_id(self : Node, id : Int32) -> Bool {
  if self.id() == id {
    return true
  }
  match self {
    Leaf(..) => false
    Stack(kids~, ..) => {
      for kid in kids {
        if kid.contains_id(id) {
          return true
        }
      }
      false
    }
    Scroll(kid~, ..) => kid.contains_id(id)
  }
}

///|
/// The innermost scroll container holding this id, deepest first. A scroll
/// counts itself, so the container holding key focus scrolls on the keys the
/// widget under focus did not take.
pub fn Node::scroll_around(self : Node, id : Int32) -> (Int32, ScrollState)? {
  match self {
    Leaf(..) => None
    Stack(kids~, ..) => {
      for kid in kids {
        match kid.scroll_around(id) {
          Some(found) => return Some(found)
          None => ()
        }
      }
      None
    }
    Scroll(id=own, kid~, state~, ..) =>
      match kid.scroll_around(id) {
        Some(found) => Some(found)
        None =>
          if own == id || kid.contains_id(id) {
            Some((own, state))
          } else {
            None
          }
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
