// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn trim_end(line : String) -> String {
  let mut last = -1
  for i in 0..<line.length() {
    if line[i] != 32 {
      last = i
    }
  }
  if last < 0 {
    ""
  } else {
    line[:last + 1].to_owned()
  }
}

///|
fn show(
  title : String,
  w : &@widget.Widget,
  width : Int32,
  height : Int32,
) -> Unit {
  println("── " + title)
  let at = @geom.Size::new(width, height)
  for y in 0..<height {
    println(trim_end(w.render_line(y, at).text()))
  }
  println("")
}

///|
fn focus(
  w : &@widget.Widget,
  id : Int32,
  at : @geom.Size,
  msg : @widget.Msg,
) -> Unit {
  let ctx = @widget.Ctx::new(id, at, focused=true)
  ignore(w.handle(ctx, @widget.Msg::Focus(true)))
  ignore(w.handle(ctx, msg))
}

///|
fn main {
  show(
    "Static",
    @widget.Static::new("Hello, moonetui", align=@widget.Align::Centre),
    30,
    1,
  )
  show(
    "Header · Footer",
    @widget.Header::new("moonetui", note="ctrl-c to quit"),
    60,
    1,
  )
  show(
    "Footer",
    @widget.Footer::new([("tab", "next"), ("enter", "choose"), ("q", "quit")]),
    60,
    1,
  )
  show(
    "Rule (heavy)",
    @widget.Rule::horizontal(kind=@widget.RuleKind::Heavy),
    30,
    1,
  )
  show("Digits", @widget.Digits::new(value="12:34"), 15, 3)
  show(
    "Sparkline",
    @widget.Sparkline::new(data=[3.0, 5.0, 2.0, 8.0, 6.0, 4.0, 7.0]),
    30,
    1,
  )
  let bar = @widget.Progress::new(total=100)
  bar.set(62)
  show("Progress", bar, 30, 1)
  show("LoadingIndicator", @widget.LoadingIndicator::new(), 12, 1)
  show("Placeholder", @widget.Placeholder::new(label="Widget slot"), 26, 4)
  let field = @widget.Input::new(placeholder="type here")
  field.set("hello")
  show("Input", field, 24, 1)
  let area = @widget.TextArea::new(show_line_numbers=true)
  area.load_text("line one\nline two\nline three")
  show("TextArea", area, 28, 4)
  let log = @widget.Log::new()
  log.write_lines(["boot ok", "loading modules", "ready"])
  show("Log", log, 24, 4)
  let rich = @widget.RichLog::new()
  rich.write("deploy passed", style=@style.Style::new(fg=@style.green))
  rich.write("2 warnings", style=@style.Style::new(fg=@style.yellow))
  rich.write("done")
  show("RichLog", rich, 24, 4)
  show("Switch (on)", @widget.Switch::new(value=true), 8, 1)
  show("Checkbox", @widget.Checkbox::new("Enable extras", value=true), 22, 1)
  show(
    "RadioSet",
    @widget.RadioSet::new([
      @widget.RadioButton::new("Fast"),
      @widget.RadioButton::new("Balanced", value=true),
      @widget.RadioButton::new("Quiet"),
    ]),
    22,
    3,
  )
  let options = @widget.OptionList::new(options=[
    @widget.Choice::new("Alpha"),
    @widget.Choice::new("Beta"),
    @widget.Choice::new("Retired", disabled=true),
  ])
  options.add_separator()
  options.add_option(@widget.Choice::new("Omega"))
  show("OptionList", options, 24, 5)
  show(
    "SelectionList",
    @widget.SelectionList::new(options=[
      @widget.Selection::new("Clean build", "clean", initial_state=true),
      @widget.Selection::new("All targets", "targets", initial_state=true),
      @widget.Selection::new("Sign the tag", "sign"),
    ]),
    26,
    4,
  )
  let pick = @widget.Select::new(
    options=[("alpha", "Alpha"), ("beta", "Beta"), ("gamma", "Gamma")],
    prompt="Pick",
  )
  let pick_size = @geom.Size::new(20, 4)
  focus(pick, 1, pick_size, @widget.Msg::Key(@event.Key::of(Enter)))
  show("Select (expanded)", pick, 20, 4)
  let button = @widget.Button::new(" Press me ")
  let button_size = @geom.Size::new(14, 1)
  focus(button, 2, button_size, @widget.Msg::Focus(true))
  show("Button", button, 14, 1)
  let list = @widget.ListView::new([
    "alpha", "beta", "gamma", "delta", "epsilon",
  ])
  list.select(1)
  show("ListView", list, 20, 4)
  show(
    "Tabs",
    @widget.Tabs::new(labels=["Inbox", "Reports", "Settings"]),
    30,
    2,
  )
  let panes : Array[&@widget.Widget] = [
    @widget.Static::new("3 unread, 1 flagged"),
    @widget.Static::new("last run: 42 seconds"),
  ]
  show(
    "TabbedContent",
    @widget.TabbedContent::new(labels=["Overview", "Logs"], panes~),
    34,
    4,
  )
  let body : &@widget.Widget = @widget.Static::new("All checks passed.")
  let fold = @widget.Collapsible::new(title="Details", contents=body)
  fold.set_collapsed(false)
  show("Collapsible (open)", fold, 30, 5)
  let tree = @widget.Tree::new(root_label="Dune")
  tree.expand(tree.root_id())
  let arrakis = tree.add(tree.root_id(), "Arrakis", expand=true)
  ignore(tree.add(tree.root_id(), "Caladan"))
  ignore(tree.add_leaf(arrakis, "Arrakeen"))
  ignore(tree.add_leaf(arrakis, "Carthag"))
  show("Tree", tree, 26, 6)
  let disk = @widget.DirectoryTree::new(path=".", loader=(path : String) => {
    if path == "." {
      [
        @widget.DirEntry::new("src", is_dir=true),
        @widget.DirEntry::new("tests", is_dir=true),
        @widget.DirEntry::new("moon.pkg", is_dir=false),
        @widget.DirEntry::new("README.md", is_dir=false),
      ]
    } else {
      [@widget.DirEntry::new("main.mbt", is_dir=false)]
    }
  })
  show("DirectoryTree", disk, 28, 6)
  let table = @widget.DataTable::new(zebra=true)
  ignore(table.add_column("Name", width=12))
  ignore(table.add_column("Size", width=6, align=@widget.Align::Right))
  ignore(table.add_column("Kind"))
  ignore(table.add_row(["moon.pkg", "184", "package"]))
  ignore(table.add_row(["main.mbt", "4096", "source"]))
  ignore(table.add_row(["README.md", "2211", "text"]))
  show("DataTable", table, 44, 5)
  show(
    "Markdown",
    @widget.Markdown::new(
      "# Deploy report\n\nAll four backends pass.\n\n- wasm ok\n- native ok\n\n| target | tests |\n|:-|:-:|\n| wasm | 273 |\n",
    ),
    44,
    10,
  )
  show(
    "Tooltip",
    @widget.Tooltip::new("The build passed on all four backends."),
    36,
    2,
  )
  show(
    "Toast",
    @widget.Toast::new(
      "Everything is nominal.",
      title="Deployed",
      level=@widget.ToastLevel::Information,
      duration=6,
    ),
    34,
    3,
  )
}
