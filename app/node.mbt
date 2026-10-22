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
pub fn Node::id(self : Node) -> Int32 {
  match self {
    Leaf(id~, ..) => id
    Stack(id~, ..) => id
  }
}

///|
pub fn Node::box(self : Node) -> @layout.Box {
  match self {
    Leaf(box~, ..) => box
    Stack(box~, ..) => box
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
    Stack(dir=own_dir, gap~, kids~, ..) => {
      let mut total = 0
      let mut widest = 0
      let mut shown = 0
      for kid in kids {
        if kid.resolve(theme, @style.default).hidden {
          continue
        }
        let want = kid.hint(space, own_dir, theme~)
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
) -> Unit {
  let res = self.resolve(theme, inherited)
  if res.hidden {
    return
  }
  let framed = res.margin.shrink_region(area)
  let visible = framed.intersection(clip)
  rects[self.id()] = visible
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
        )
      }
      // Placed after the children so the chrome lands behind them: the first
      // placement covering a column wins it.
      if res.has_chrome() {
        scene.place(id, framed, clip)
        styled[id] = res
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
