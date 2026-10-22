// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct TreeNode {
  mut label : String
  mut data : String
  mut expanded : Bool
  mut allow_expand : Bool
  mut loaded : Bool
  children : Array[Int32]
  parent : Int32
} derive(Eq, Debug)

///|
pub fn TreeNode::new(
  label~ : String,
  data~ : String = "",
  expand~ : Bool = false,
  allow_expand~ : Bool = true,
  parent~ : Int32 = -1,
) -> TreeNode {
  {
    label,
    data,
    expanded: expand,
    allow_expand,
    loaded: false,
    children: [],
    parent,
  }
}

///|
pub fn TreeNode::label(self : TreeNode) -> String {
  self.label
}

///|
pub fn TreeNode::is_expanded(self : TreeNode) -> Bool {
  self.expanded
}

///|
priv struct TreeLine {
  id : Int32
  parent : Int32
  at : Int32
  grandparent : Int32
  parent_at : Int32
  depth : Int32
  last : Bool
  flags : Array[Bool]
}

///|
pub struct Tree {
  nodes : Array[TreeNode]
  mut show_root : Bool
  mut show_guides : Bool
  mut guide_depth : Int32
  mut auto_expand : Bool
  mut cursor : Int32
  mut hover : Int32
  mut offset : Int32
  mut seen : Int32
  mut focused : Bool
  icon_collapsed : String
  icon_open : String
  icon_leaf : String
  dim_hidden : Bool
  style : @style.Style
  guide_style : @style.Style
  cursor_style : @style.Style
  hover_style : @style.Style
} derive(Eq, Debug)

///|
pub fn Tree::new(
  root_label~ : String,
  root_data~ : String = "",
  show_root~ : Bool = true,
  icon_collapsed~ : String = "▶ ",
  icon_open~ : String = "▼ ",
  icon_leaf~ : String = "",
  dim_hidden~ : Bool = false,
  style~ : @style.Style = @style.Style::new(),
  guide_style~ : @style.Style = @style.Style::new(dim=true),
  cursor_style~ : @style.Style = @style.Style::new(reverse=true),
  hover_style~ : @style.Style = @style.Style::new(bold=true),
) -> Tree {
  {
    nodes: [TreeNode::new(label=root_label, data=root_data)],
    show_root,
    show_guides: true,
    guide_depth: 4,
    auto_expand: true,
    cursor: -1,
    hover: -1,
    offset: 0,
    seen: 0,
    focused: false,
    icon_collapsed,
    icon_open,
    icon_leaf,
    dim_hidden,
    style,
    guide_style,
    cursor_style,
    hover_style,
  }
}

///|
pub fn Tree::root_id(_self : Tree) -> Int32 {
  0
}

///|
pub fn Tree::add(
  self : Tree,
  parent : Int32,
  label : String,
  data~ : String = "",
  expand~ : Bool = false,
  allow_expand~ : Bool = true,
) -> Int32 {
  let id = self.nodes.length()
  self.nodes.push(TreeNode::new(label~, data~, expand~, allow_expand~, parent~))
  self.nodes[parent].children.push(id)
  id
}

///|
pub fn Tree::add_leaf(
  self : Tree,
  parent : Int32,
  label : String,
  data~ : String = "",
) -> Int32 {
  self.add(parent, label, data~, expand=false, allow_expand=false)
}

///|
pub fn Tree::node(self : Tree, id : Int32) -> TreeNode {
  self.nodes[id]
}

///|
pub fn Tree::label(self : Tree, id : Int32) -> String {
  self.nodes[id].label
}

///|
pub fn Tree::set_label(self : Tree, id : Int32, label : String) -> Unit {
  self.nodes[id].label = label
}

///|
pub fn Tree::data(self : Tree, id : Int32) -> String {
  self.nodes[id].data
}

///|
pub fn Tree::set_data(self : Tree, id : Int32, data : String) -> Unit {
  self.nodes[id].data = data
}

///|
pub fn Tree::children(self : Tree, id : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for child in self.nodes[id].children {
    out.push(child)
  }
  out
}

///|
pub fn Tree::is_expanded(self : Tree, id : Int32) -> Bool {
  self.nodes[id].expanded
}

///|
pub fn Tree::expand(self : Tree, id : Int32) -> Unit {
  self.nodes[id].expanded = true
}

///|
pub fn Tree::collapse(self : Tree, id : Int32) -> Unit {
  self.nodes[id].expanded = false
}

///|
pub fn Tree::expand_all(self : Tree, id : Int32) -> Unit {
  self.nodes[id].expanded = true
  for child in self.nodes[id].children {
    self.expand_all(child)
  }
}

///|
pub fn Tree::collapse_all(self : Tree, id : Int32) -> Unit {
  self.nodes[id].expanded = false
  for child in self.nodes[id].children {
    self.collapse_all(child)
  }
}

///|
pub fn Tree::allow_expand(self : Tree, id : Int32) -> Bool {
  self.nodes[id].allow_expand
}

///|
pub fn Tree::set_allow_expand(self : Tree, id : Int32, allow : Bool) -> Unit {
  self.nodes[id].allow_expand = allow
}

///|
pub fn Tree::remove_children(self : Tree, id : Int32) -> Unit {
  for child in self.nodes[id].children {
    self.remove_children(child)
    self.nodes[child].children.clear()
  }
  self.nodes[id].children.clear()
  self.nodes[id].loaded = false
}

///|
pub fn Tree::cursor_line(self : Tree) -> Int32 {
  self.cursor
}

///|
pub fn Tree::cursor_node(self : Tree) -> Int32 {
  match self.line_at(self.cursor) {
    Some(line) => line.id
    None => -1
  }
}

///|
pub fn Tree::show_root(self : Tree, show : Bool) -> Unit {
  self.show_root = show
  self.cursor = -1
}

///|
pub fn Tree::show_guides(self : Tree, show : Bool) -> Unit {
  self.show_guides = show
}

///|
pub fn Tree::set_guide_depth(self : Tree, depth : Int32) -> Unit {
  self.guide_depth = clamp(depth, 2, 10)
}

///|
pub fn Tree::set_auto_expand(self : Tree, auto : Bool) -> Unit {
  self.auto_expand = auto
}

///|
pub fn Tree::clear(self : Tree) -> Unit {
  let root = self.nodes[0]
  root.children.clear()
  root.loaded = false
  self.cursor = -1
  self.offset = 0
}

///|
pub fn Tree::reset(self : Tree, label : String, data~ : String = "") -> Unit {
  self.clear()
  self.nodes[0].label = label
  self.nodes[0].data = data
}

///|
pub fn Tree::line_count(self : Tree) -> Int32 {
  if self.show_root {
    tree_count(self, 0)
  } else {
    let mut total = 0
    for child in self.nodes[0].children {
      total = total + tree_count(self, child)
    }
    total
  }
}

///|
fn tree_count(tree : Tree, id : Int32) -> Int32 {
  let node = tree.nodes[id]
  let mut total = 1
  if node.expanded {
    for child in node.children {
      total = total + tree_count(tree, child)
    }
  }
  total
}

///|
fn Tree::depth_cells(self : Tree) -> Int32 {
  clamp(self.guide_depth, 2, 10)
}

///|
fn Tree::line_at(self : Tree, y : Int32) -> TreeLine? {
  if y < 0 {
    return None
  }
  let flags : Array[Bool] = []
  if self.show_root {
    let (_, found) = tree_find(self, 0, -1, 0, -1, 0, 0, true, flags, y)
    return found
  }
  let count = self.nodes[0].children.length()
  let mut skip = y
  for i in 0..<count {
    let child = self.nodes[0].children[i]
    let (used, found) = tree_find(
      self,
      child,
      0,
      i,
      -1,
      0,
      0,
      i == count - 1,
      flags,
      skip,
    )
    skip = skip - used
    if found is Some(_) {
      return found
    }
    if skip < 0 {
      return None
    }
  }
  None
}

///|
fn tree_find(
  tree : Tree,
  id : Int32,
  parent : Int32,
  at : Int32,
  grandparent : Int32,
  parent_at : Int32,
  depth : Int32,
  last : Bool,
  flags : Array[Bool],
  skip : Int32,
) -> (Int32, TreeLine?) {
  if skip == 0 {
    let own : Array[Bool] = []
    for flag in flags {
      own.push(flag)
    }
    return (
      1,
      Some({ id, parent, at, grandparent, parent_at, depth, last, flags: own, }),
    )
  }
  let node = tree.nodes[id]
  let mut used = 1
  if node.expanded {
    let count = node.children.length()
    for i in 0..<count {
      if used > skip {
        break
      }
      // Guides cover the ancestors strictly between the path top and
      // the node, so the top's own flag is never pushed.
      if depth > 0 {
        flags.push(last)
      }
      let (sub, found) = tree_find(
        tree,
        node.children[i],
        id,
        i,
        parent,
        at,
        depth + 1,
        i == count - 1,
        flags,
        skip - used,
      )
      if depth > 0 {
        ignore(flags.pop())
      }
      used = used + sub
      if found is Some(_) {
        return (used, found)
      }
    }
  }
  (used, None)
}

///|
fn Tree::line_of(self : Tree, id : Int32) -> Int32 {
  if self.show_root {
    return tree_index(self, 0, 0, id)
  }
  let mut index = 0
  for child in self.nodes[0].children {
    let at = tree_index(self, child, index, id)
    if at >= 0 {
      return at
    }
    index = index + tree_count(self, child)
  }
  -1
}

///|
fn tree_index(tree : Tree, id : Int32, index : Int32, want : Int32) -> Int32 {
  if id == want {
    return index
  }
  let node = tree.nodes[id]
  if node.expanded {
    let mut at = index + 1
    for child in node.children {
      let found = tree_index(tree, child, at, want)
      if found >= 0 {
        return found
      }
      at = at + tree_count(tree, child)
    }
  }
  -1
}

///|
pub impl Widget for Tree with fn render_line(self, row, size) {
  self.scroll_to_fit(size.height)
  let y = self.offset + row
  let line = self.line_at(y)
  match line {
    None => @strip.Strip::blank(size.width, self.style)
    Some(line) => {
      let gd = self.depth_cells()
      let segs : Array[@strip.Seg] = []
      for flag in line.flags {
        let kind = if flag || !self.show_guides { "space" } else { "vertical" }
        segs.push(@strip.Seg::new(tree_guide(kind, gd), self.guide_style))
      }
      if line.depth > 0 {
        let kind = if !self.show_guides {
          "space"
        } else if line.last {
          "terminator"
        } else {
          "cross"
        }
        segs.push(@strip.Seg::new(tree_guide(kind, gd), self.guide_style))
      }
      let node = self.nodes[line.id]
      let style = if self.cursor == y && self.focused {
        self.cursor_style
      } else if self.hover == y {
        self.hover_style
      } else if self.dim_hidden && prefix_dot(node.label) {
        @style.Style::new(dim=true)
      } else {
        self.style
      }
      let icon = if node.allow_expand {
        if node.expanded {
          self.icon_open
        } else {
          self.icon_collapsed
        }
      } else {
        self.icon_leaf
      }
      let used = line.depth * gd + @strip.str_cells(icon)
      let mut remaining = size.width - used
      if remaining < 0 {
        remaining = 0
      }
      if @strip.str_cells(icon) > 0 {
        segs.push(@strip.Seg::new(icon, style))
      }
      segs.push(@strip.Seg::new(clip_to(node.label, remaining), style))
      @strip.Strip::from_segs(segs).pad_to(size.width, self.style)
    }
  }
}

///|
fn tree_guide(kind : String, gd : Int32) -> String {
  let out = StringBuilder()
  if kind == "space" {
    for _ in 0..<gd {
      out.write_string(" ")
    }
    return out.to_string()
  }
  if kind == "vertical" {
    out.write_string("│")
    let spaces = gd - 1
    for _ in 0..<spaces {
      out.write_string(" ")
    }
    return out.to_string()
  }
  if kind == "terminator" {
    out.write_string("└")
  } else {
    out.write_string("├")
  }
  let dashes = gd - 2
  for _ in 0..<dashes {
    out.write_string("─")
  }
  out.write_string(" ")
  out.to_string()
}

///|
fn prefix_dot(label : String) -> Bool {
  label.length() > 0 && label[0] == 46
}

///|
pub impl Widget for Tree with fn hint(self, _size) {
  let gd = self.depth_cells()
  let leaf_cells = @strip.str_cells(self.icon_leaf)
  let mut widest = 0
  if self.show_root {
    widest = tree_width(self, 0, 0, gd, leaf_cells, widest)
  } else {
    for child in self.nodes[0].children {
      widest = tree_width(self, child, 0, gd, leaf_cells, widest)
    }
  }
  @geom.Size::new(widest, self.line_count())
}

///|
fn tree_width(
  tree : Tree,
  id : Int32,
  depth : Int32,
  gd : Int32,
  leaf_cells : Int32,
  widest : Int32,
) -> Int32 {
  let node = tree.nodes[id]
  let icon = if node.allow_expand { 2 } else { leaf_cells }
  let mut width = depth * gd + icon + @strip.str_cells(node.label)
  if width < widest {
    width = widest
  }
  if node.expanded {
    for child in node.children {
      width = tree_width(tree, child, depth + 1, gd, leaf_cells, width)
    }
  }
  width
}

///|
pub impl Widget for Tree with fn handle(self, ctx, msg) {
  match msg {
    Focus(gained) => {
      self.focused = gained
      ctx.repaint()
      true
    }
    Key(key) => {
      if key.mods.ctrl || key.mods.alt {
        return false
      }
      let shift = key.mods.shift
      match key.code {
        Up => {
          if shift {
            self.cursor_sibling(ctx, -1)
          } else {
            let target = if self.cursor == -1 {
              self.last_line()
            } else {
              self.cursor - 1
            }
            self.move_cursor(target, ctx)
          }
          true
        }
        Down => {
          if shift {
            self.cursor_sibling(ctx, 1)
          } else {
            let target = if self.cursor == -1 { 0 } else { self.cursor + 1 }
            self.move_cursor(target, ctx)
          }
          true
        }
        Left => {
          if shift {
            self.cursor_parent(ctx)
          }
          shift
        }
        Right => {
          if shift {
            self.cursor_parent_next(ctx)
          }
          shift
        }
        PageUp => {
          if shift {
            return false
          }
          let target = if self.cursor == -1 {
            self.last_line()
          } else {
            self.cursor - self.page_step()
          }
          self.move_cursor(target, ctx)
          true
        }
        PageDown => {
          if shift {
            return false
          }
          let target = if self.cursor == -1 {
            0
          } else {
            self.cursor + self.page_step()
          }
          self.move_cursor(target, ctx)
          true
        }
        Home => {
          if shift {
            return false
          }
          self.move_cursor(0, ctx)
          true
        }
        End => {
          if shift {
            return false
          }
          self.move_cursor(self.last_line(), ctx)
          true
        }
        Enter => {
          if shift {
            return false
          }
          self.select_cursor(ctx)
          true
        }
        Char(32) => {
          if shift {
            self.toggle_siblings(ctx)
          } else if key.mods.is_none() {
            self.toggle_cursor(ctx)
          } else {
            return false
          }
          true
        }
        _ => false
      }
    }
    Mouse(mouse) =>
      match mouse.kind {
        Down => {
          ctx.emit(TakeFocus(id=ctx.id))
          let y = self.offset + mouse.y
          match self.line_at(y) {
            Some(line) => {
              let gd = self.depth_cells()
              let icon_at = line.depth * gd
              let icon_cells = if self.nodes[line.id].allow_expand {
                @strip.str_cells(self.icon_collapsed)
              } else {
                @strip.str_cells(self.icon_leaf)
              }
              if self.nodes[line.id].allow_expand &&
                mouse.x >= icon_at &&
                mouse.x < icon_at + icon_cells {
                self.toggle_node(line.id, ctx)
              } else {
                self.move_cursor(y, ctx)
                self.select_cursor(ctx)
              }
            }
            None => ()
          }
          true
        }
        Move => {
          let y = self.offset + mouse.y
          let hover = if y >= 0 && y < self.line_count() { y } else { -1 }
          if hover != self.hover {
            self.hover = hover
            ctx.repaint()
          }
          true
        }
        ScrollUp => {
          self.offset = self.offset - 1
          self.clamp_offset()
          ctx.repaint()
          true
        }
        ScrollDown => {
          self.offset = self.offset + 1
          self.clamp_offset()
          ctx.repaint()
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
pub impl Widget for Tree with fn focusable(_self) {
  true
}

///|
fn Tree::last_line(self : Tree) -> Int32 {
  self.line_count() - 1
}

///|
fn Tree::page_step(self : Tree) -> Int32 {
  if self.seen > 1 {
    self.seen - 1
  } else {
    1
  }
}

///|
fn Tree::move_cursor(self : Tree, line : Int32, ctx : Ctx) -> Unit {
  let total = self.line_count()
  if total == 0 {
    return
  }
  let at = clamp(line, 0, total - 1)
  if at == self.cursor {
    return
  }
  self.cursor = at
  match self.line_at(at) {
    Some(found) => ctx.emit(Highlighted(id=ctx.id, index=found.id))
    None => ()
  }
  ctx.repaint()
}

///|
fn Tree::node_at(self : Tree, line : Int32) -> Int32 {
  match self.line_at(line) {
    Some(found) => found.id
    None => -1
  }
}

///|
fn Tree::select_cursor(self : Tree, ctx : Ctx) -> Unit {
  if self.cursor < 0 {
    return
  }
  let id = self.node_at(self.cursor)
  if id < 0 {
    return
  }
  ctx.emit(Selected(id=ctx.id, index=id))
  if self.auto_expand {
    self.toggle_node(id, ctx)
  }
}

///|
fn Tree::toggle_cursor(self : Tree, ctx : Ctx) -> Unit {
  if self.cursor < 0 {
    return
  }
  let id = self.node_at(self.cursor)
  if id >= 0 {
    self.toggle_node(id, ctx)
  }
}

///|
fn Tree::toggle_node(self : Tree, id : Int32, ctx : Ctx) -> Unit {
  if !self.nodes[id].allow_expand {
    return
  }
  let on = !self.nodes[id].expanded
  self.nodes[id].expanded = on
  ctx.emit(ToggledAt(id=ctx.id, index=id, on~))
  ctx.repaint()
}

///|
fn Tree::toggle_siblings(self : Tree, ctx : Ctx) -> Unit {
  if self.cursor < 0 {
    return
  }
  let line = self.line_at(self.cursor)
  let parent = match line {
    Some(found) => found.parent
    None => -1
  }
  if parent < 0 {
    return
  }
  let siblings = self.nodes[parent].children
  let mut all_collapsed = true
  for child in siblings {
    if self.nodes[child].allow_expand && self.nodes[child].expanded {
      all_collapsed = false
    }
  }
  for child in siblings {
    if !self.nodes[child].allow_expand {
      continue
    }
    let target = all_collapsed
    if self.nodes[child].expanded != target {
      self.nodes[child].expanded = target
      ctx.emit(ToggledAt(id=ctx.id, index=child, on=target))
    }
  }
  ctx.repaint()
}

///|
fn Tree::cursor_parent(self : Tree, ctx : Ctx) -> Unit {
  if self.cursor < 0 {
    return
  }
  let parent = match self.line_at(self.cursor) {
    Some(found) => found.parent
    None => -1
  }
  if parent < 0 {
    return
  }
  self.move_cursor(self.line_of(parent), ctx)
}

///|
/// Move to the next sibling of the cursor node's parent; a missing target
/// falls to the top.
fn Tree::cursor_parent_next(self : Tree, ctx : Ctx) -> Unit {
  if self.cursor < 0 {
    return
  }
  let line = match self.line_at(self.cursor) {
    Some(found) => found
    None => return
  }
  if line.parent < 0 {
    return
  }
  match self.after_sibling(line) {
    Some(target) => self.move_cursor(target, ctx)
    None => self.cursor_reset(ctx)
  }
}

///|
/// The next sibling of the cursor node's parent; a missing target resets
/// the cursor.
fn Tree::after_sibling(self : Tree, line : TreeLine) -> Int32? {
  if line.grandparent < 0 {
    return None
  }
  let parent_siblings = self.nodes[line.grandparent].children
  if line.parent_at + 1 < parent_siblings.length() {
    return Some(self.line_of(parent_siblings[line.parent_at + 1]))
  }
  None
}

///|
fn Tree::cursor_reset(self : Tree, ctx : Ctx) -> Unit {
  if self.cursor == -1 {
    return
  }
  self.cursor = -1
  ctx.repaint()
}

///|
fn Tree::cursor_sibling(self : Tree, ctx : Ctx, direction : Int32) -> Unit {
  if self.cursor < 0 {
    return
  }
  let line = match self.line_at(self.cursor) {
    Some(found) => found
    None => return
  }
  if line.parent < 0 {
    return
  }
  let siblings = self.nodes[line.parent].children
  let at = line.at + direction
  if at >= 0 && at < siblings.length() {
    self.move_cursor(self.line_of(siblings[at]), ctx)
    return
  }
  if direction < 0 {
    self.cursor_parent(ctx)
    return
  }
  match self.after_sibling(line) {
    Some(target) => self.move_cursor(target, ctx)
    None => self.cursor_reset(ctx)
  }
}

///|
fn Tree::scroll_to_fit(self : Tree, height : Int32) -> Unit {
  self.seen = height
  let total = self.line_count()
  if self.cursor >= total {
    self.cursor = -1
  }
  if self.cursor >= 0 {
    if self.cursor < self.offset {
      self.offset = self.cursor
    } else if height > 0 && self.cursor >= self.offset + height {
      self.offset = self.cursor - height + 1
    }
  }
  self.clamp_offset()
}

///|
fn Tree::clamp_offset(self : Tree) -> Unit {
  let total = self.line_count()
  let max = total - self.seen
  self.offset = clamp(self.offset, 0, if max < 0 { 0 } else { max })
}

///|
pub extend Tree with Debug::{to_repr}

///|
pub extend Tree with Eq::{not_equal, equal}

///|
pub extend Tree with Widget::{focusable, handle, hint, render_line}

///|
pub extend TreeNode with Debug::{to_repr}

///|
pub extend TreeNode with Eq::{not_equal, equal}
