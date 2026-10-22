// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub struct DirEntry {
  name : String
  is_dir : Bool
} derive(Eq, Debug)

///|
pub fn DirEntry::new(name : String, is_dir~ : Bool) -> DirEntry {
  { name, is_dir, }
}

///|
pub struct DirectoryTree {
  tree : Tree
  loader : (String) -> Array[DirEntry]
}

///|
pub fn DirectoryTree::new(
  path~ : String,
  loader~ : (String) -> Array[DirEntry],
  style~ : @style.Style = @style.Style::new(),
  guide_style~ : @style.Style = @style.Style::new(dim=true),
  cursor_style~ : @style.Style = @style.Style::new(reverse=true),
  hover_style~ : @style.Style = @style.Style::new(bold=true),
) -> DirectoryTree {
  let tree = Tree::new(
    root_label=path,
    root_data=path,
    icon_collapsed="📁 ",
    icon_open="📂 ",
    icon_leaf="📄 ",
    dim_hidden=true,
    style~,
    guide_style~,
    cursor_style~,
    hover_style~,
  )
  let dirs : DirectoryTree = { tree, loader, }
  dirs.populate(0)
  dirs.tree.nodes[0].expanded = true
  dirs
}

///|
pub fn DirectoryTree::tree(self : DirectoryTree) -> Tree {
  self.tree
}

///|
pub fn DirectoryTree::path(self : DirectoryTree) -> String {
  self.tree.nodes[0].data
}

///|
pub fn DirectoryTree::reload(self : DirectoryTree) -> Unit {
  self.tree.nodes[0].loaded = false
  self.tree.remove_children(0)
  self.populate(0)
  self.tree.nodes[0].expanded = true
}

///|
pub fn DirectoryTree::set_path(self : DirectoryTree, path : String) -> Unit {
  self.tree.nodes[0].label = path
  self.tree.nodes[0].data = path
  self.reload()
}

///|
fn DirectoryTree::populate(self : DirectoryTree, id : Int32) -> Unit {
  let node = self.tree.nodes[id]
  if node.loaded {
    return
  }
  node.loaded = true
  node.children.clear()
  let entries = (self.loader)(node.data)
  dir_sort(entries)
  for entry in entries {
    ignore(
      self.tree.add(
        id,
        entry.name,
        data=dir_join(node.data, entry.name),
        allow_expand=entry.is_dir,
      ),
    )
  }
}

///|
fn DirectoryTree::load_expanded(self : DirectoryTree) -> Unit {
  self.load_expanded_from(0)
}

///|
fn DirectoryTree::load_expanded_from(self : DirectoryTree, id : Int32) -> Unit {
  let node = self.tree.nodes[id]
  if node.allow_expand && node.expanded && !node.loaded {
    self.populate(id)
  }
  for child in self.tree.nodes[id].children {
    self.load_expanded_from(child)
  }
}

///|
fn dir_sort(entries : Array[DirEntry]) -> Unit {
  let count = entries.length()
  for i in 1..<count {
    let held = entries[i]
    let mut at = i
    while at > 0 && dir_before(held, entries[at - 1]) {
      entries[at] = entries[at - 1]
      at = at - 1
    }
    entries[at] = held
  }
}

///|
fn dir_before(a : DirEntry, b : DirEntry) -> Bool {
  if a.is_dir != b.is_dir {
    return a.is_dir
  }
  text_before(a.name.to_lower(), b.name.to_lower())
}

///|
fn dir_join(parent : String, name : String) -> String {
  if parent.length() > 0 && parent[parent.length() - 1] == 47 {
    "\{parent}\{name}"
  } else {
    "\{parent}/\{name}"
  }
}

///|
pub impl Widget for DirectoryTree with fn render_line(self, row, size) {
  self.tree.render_line(row, size)
}

///|
pub impl Widget for DirectoryTree with fn hint(self, size) {
  self.tree.hint(size)
}

///|
pub impl Widget for DirectoryTree with fn handle(self, ctx, msg) {
  let outs = ctx.asked()
  let before = outs.length()
  let held = self.tree.handle(ctx, msg)
  self.load_expanded()
  let stop = outs.length()
  let mut at = before
  while at < stop {
    match outs[at] {
      Selected(index~, ..) =>
        if index >= 0 && index < self.tree.nodes.length() {
          let node = self.tree.nodes[index]
          if node.allow_expand {
            ctx.emit(Changed(id=ctx.id, value=node.data))
          } else {
            ctx.emit(Submitted(id=ctx.id, value=node.data))
          }
        }
      _ => ()
    }
    at = at + 1
  }
  held
}

///|
pub impl Widget for DirectoryTree with fn focusable(_self) {
  true
}

///|
pub extend DirEntry with Debug::{to_repr}

///|
pub extend DirEntry with Eq::{not_equal, equal}

///|
pub extend DirectoryTree with Widget::{focusable, handle, hint, render_line}
