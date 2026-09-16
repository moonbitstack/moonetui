// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The widget tree.
///
/// A leaf is a widget; a stack is a row or a column of nodes. Containers hold no
/// widget of their own, so nothing has to pretend to render a container, and the
/// compositor only ever asks a real widget for a line.
pub enum Node {
  Leaf(id~ : Int, widget~ : &@widget.Widget, box~ : @layout.Box)
  Stack(
    id~ : Int,
    dir~ : @layout.Dir,
    box~ : @layout.Box,
    gap~ : Int,
    kids~ : Array[Node]
  )
}

///|
/// A widget in the tree.
pub fn leaf(
  id : Int,
  widget : &@widget.Widget,
  box? : @layout.Box = @layout.Box::new(),
) -> Node {
  Leaf(id~, widget~, box~)
}

///|
/// A column of nodes.
pub fn column(
  id : Int,
  kids : Array[Node],
  box? : @layout.Box = @layout.Box::new(extent=Frac(1)),
  gap? : Int = 0,
) -> Node {
  Stack(id~, dir=Vertical, box~, gap~, kids~)
}

///|
/// A row of nodes.
pub fn row(
  id : Int,
  kids : Array[Node],
  box? : @layout.Box = @layout.Box::new(extent=Frac(1)),
  gap? : Int = 0,
) -> Node {
  Stack(id~, dir=Horizontal, box~, gap~, kids~)
}

///|
/// The node's own id.
pub fn Node::id(self : Node) -> Int {
  match self {
    Leaf(id~, ..) => id
    Stack(id~, ..) => id
  }
}

///|
/// How the node asks to be sized.
pub fn Node::box(self : Node) -> @layout.Box {
  match self {
    Leaf(box~, ..) => box
    Stack(box~, ..) => box
  }
}

///|
/// What the node would like along `dir`, which is what an automatic extent
/// resolves to. A stack asks for the sum of its children along the stacking
/// axis and for the largest of them across it.
pub fn Node::hint(self : Node, space : @geom.Size, dir : @layout.Dir) -> Int {
  match self {
    Leaf(widget~, ..) => @layout.main_of(widget.hint(space), dir)
    Stack(dir=own_dir, gap~, kids~, ..) => {
      let mut total = 0
      let mut widest = 0
      for kid in kids {
        let want = kid.hint(space, own_dir)
        total = total + want
        if want > widest {
          widest = want
        }
      }
      if own_dir == dir {
        total + gap * at_least_zero(kids.length() - 1)
      } else {
        widest
      }
    }
  }
}

///|
/// Walk the tree, placing every node, and add the leaves to a scene.
///
/// Placements go in front-to-back order, and a child is added after its parent,
/// so a child covers the container it sits in — which is what makes a container
/// a background rather than something that paints over its contents.
pub fn Node::place(
  self : Node,
  area : @geom.Region,
  clip : @geom.Region,
  scene : @comp.Scene,
  rects : Map[Int, @geom.Region],
) -> Unit {
  let visible = area.intersection(clip)
  rects[self.id()] = visible
  match self {
    Leaf(id~, ..) => scene.place(id, area, clip)
    Stack(dir~, gap~, kids~, ..) => {
      let boxes : Array[@layout.Box] = []
      let content : Array[Int] = []
      for kid in kids {
        boxes.push(kid.box())
        content.push(kid.hint(area.size(), dir))
      }
      let slots = @layout.arrange(area, dir, boxes, content, gap~)
      for i in 0..<kids.length() {
        kids[i].place(slots[i], visible, scene, rects)
      }
    }
  }
}

///|
/// The leaf widget with this id, if the tree has one.
pub fn Node::find(self : Node, id : Int) -> &@widget.Widget? {
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
pub fn Node::focus_ring(self : Node) -> Array[Int] {
  let out : Array[Int] = []
  self.collect_focusable(out)
  out
}

///|
fn Node::collect_focusable(self : Node, out : Array[Int]) -> Unit {
  match self {
    Leaf(id~, widget~, ..) => if widget.focusable() { out.push(id) }
    Stack(kids~, ..) =>
      for kid in kids {
        kid.collect_focusable(out)
      }
  }
}

///|
fn at_least_zero(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}
