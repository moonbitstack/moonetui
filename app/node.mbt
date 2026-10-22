// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The widget tree.
///
/// A leaf is a widget; a stack is a row or a column of nodes. Containers hold no
/// widget of their own, so nothing has to pretend to render a container, and the
/// compositor only ever asks a real widget for a line.
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
/// What a node is styled against: the rules, which widget holds focus, and the
/// style the application paints uncovered cells in. Focus is part of it because
/// a `:focus` rule restyles a node the moment focus moves onto it, which is
/// every frame the focus is somewhere new.
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
/// A theme over no rules, no focus, and the terminal's own colours.
pub fn Theme::new(
  sheet~ : @design.Stylesheet = @design.Stylesheet::new(),
  focus~ : Int32 = -1,
  base~ : @style.Style = @style.default,
) -> Theme {
  { sheet, focus, base, }
}

///|
/// A widget in the tree.
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
/// A column of nodes.
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
/// A row of nodes.
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
/// The node's own id.
pub fn Node::id(self : Node) -> Int32 {
  match self {
    Leaf(id~, ..) => id
    Stack(id~, ..) => id
  }
}

///|
/// How the node asks to be sized, before any style has its say.
pub fn Node::box(self : Node) -> @layout.Box {
  match self {
    Leaf(box~, ..) => box
    Stack(box~, ..) => box
  }
}

///|
/// What the rules, the inline styles, and the container together say this node
/// looks like. The rules come first, the inline styles over them — which is the
/// whole of CSS in one merge — and the container's text style under both.
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
/// What the node would like along `dir`, which is what an automatic extent
/// resolves to. A node asks for its content plus everything it wraps the
/// content in — border, padding, margin — so a bordered node that asks for its
/// own size still has room to draw its text inside the frame.
///
/// A stack asks for the sum of its children along the stacking axis and for
/// the largest of them across it; a hidden child is not asking.
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
/// The cells a node takes on top of its content along an axis: a border is one
/// cell each side, then the padding, then the margin outside it all.
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
/// Walk the tree, placing every node, and add the leaves to a scene.
///
/// Placements go in front-to-back order, and a child is added after its parent,
/// so a child covers the container it sits in — which is what makes a container
/// a background rather than something that paints over its contents. A node
/// with a border, padding, or a background of its own is added too, behind its
/// children: its chrome shows wherever they do not reach.
///
/// Every leaf's resolved styles are collected into `styled`, so the frame that
/// renders a line knows what the node carries — and a leaf carries its
/// inherited text style even when it draws no chrome, because the container's
/// background has to reach the characters a widget never styled.
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
      // How much of the content the children left unused, and where the
      // alignment says that slack goes.
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
      // The children are placed before this container's own chrome, because
      // the compositor settles a contested column for the placement that came
      // first: a background goes behind whatever sits inside it.
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
      if res.has_chrome() {
        scene.place(id, framed, clip)
        styled[id] = res
      }
    }
  }
}

///|
/// The leaf widget with this id, if the tree has one.
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
/// The ids of the leaves that can hold focus, in the order they appear.
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
