// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn button() -> Demo {
  let save = @widget.Button::new(" Save ")
  let cancel = @widget.Button::new(" Cancel ")
  let later = @widget.Button::new(" Later ")
  later.disable(true)
  Demo::new(
    "Button",
    @app.row(
      0,
      [
        @app.leaf(1, save, box=line(10)),
        @app.leaf(2, cancel, box=line(12)),
        @app.leaf(3, later, box=line(11)),
      ],
      gap=2,
    ),
    group=Navigation,
    note="Enter, Space or a click presses it; a disabled one takes neither focus nor input.",
    rows=1,
  )
}

///|
pub fn list_view() -> Demo {
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon", "中文也对齐",
  ])
  Demo::new(
    "ListView",
    @app.column(0, [@app.leaf(1, list)]),
    group=Navigation,
    note="A vertical list with a moving highlight; wide characters keep their columns.",
    rows=4,
  )
}

///|
pub fn stateful_list() -> Demo {
  let state = @widget.ListState::new(selected=1)
  let list = @widget.StatefulList::new(
    items=["alpha", "beta", "gamma", "delta", "epsilon", "中文也对齐"],
    state~,
  )
  Demo::new(
    "StatefulList",
    @app.column(0, [@app.leaf(1, list)]),
    group=Navigation,
    note="Selection and scroll live in a ListState the caller keeps, so another widget can share them or the caller can set them between frames.",
    rows=4,
  )
}

///|
pub fn tabs() -> Demo {
  Demo::new(
    "Tabs",
    @app.column(0, [
      @app.leaf(1, @widget.Tabs::new(labels=["Inbox", "Reports", "Settings"])),
    ]),
    group=Navigation,
    note="A row of tabs with an underline under the active one; the arrows move it.",
    rows=2,
  )
}

///|
pub fn tabbed_content() -> Demo {
  let jobs = @widget.ListView::new(["build", "test", "deploy"])
  let notes = @widget.Static::new("last run: 42 seconds ago\nall green")
  let panes : Array[&@widget.Widget] = [jobs, notes]
  Demo::new(
    "TabbedContent",
    @app.column(0, [
      @app.leaf(1, @widget.TabbedContent::new(labels=["Jobs", "Notes"], panes~)),
    ]),
    group=Navigation,
    note="Tabs over panes: keys go to the pane first and switch tabs when it passes.",
    rows=5,
  )
}

///|
pub fn collapsible() -> Demo {
  let body : &@widget.Widget = @widget.Static::new(
    "Four backends, all passing.\nNo warnings.",
  )
  Demo::new(
    "Collapsible",
    @app.column(0, [
      @app.leaf(
        1,
        @widget.Collapsible::new(
          title="Details",
          contents=body,
          collapsed=false,
        ),
      ),
    ]),
    group=Navigation,
    note="A titled section that Enter or a click folds and unfolds.",
    rows=6,
  )
}

///|
pub fn tree() -> Demo {
  let tree = @widget.Tree::new(root_label="Dune")
  let root = tree.root_id()
  let arrakis = tree.add(root, "Arrakis", expand=true)
  ignore(tree.add_leaf(arrakis, "Arrakeen"))
  ignore(tree.add_leaf(arrakis, "Carthag"))
  let caladan = tree.add(root, "Caladan")
  ignore(tree.add_leaf(caladan, "Castle Caladan"))
  tree.expand(root)
  Demo::new(
    "Tree",
    @app.column(0, [@app.leaf(1, tree)]),
    group=Navigation,
    note="Nodes with guides; Enter selects, Space folds, Shift and an arrow walk the family.",
    rows=6,
  )
}

///|
pub fn directory_tree() -> Demo {
  let disk = @widget.DirectoryTree::new(path=".", loader=path => {
    if path == "." {
      [
        @widget.DirEntry::new("src", is_dir=true),
        @widget.DirEntry::new("docs", is_dir=true),
        @widget.DirEntry::new("moon.mod", is_dir=false),
        @widget.DirEntry::new("README.md", is_dir=false),
      ]
    } else {
      [
        @widget.DirEntry::new("main.mbt", is_dir=false),
        @widget.DirEntry::new("moon.pkg", is_dir=false),
      ]
    }
  })
  Demo::new(
    "DirectoryTree",
    @app.column(0, [@app.leaf(1, disk)]),
    group=Navigation,
    note="A tree over a file system that reads each folder when it opens.",
    rows=6,
  )
}
