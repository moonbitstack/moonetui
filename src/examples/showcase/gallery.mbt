// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every demo behind a menu; the one highlighted runs beside it. The widgets of
/// each demo are made once, so a demo keeps its state while the menu moves on.
pub struct Gallery {
  menu : @widget.OptionList
  demos : Array[Demo]
  mut at : Int32
}

///|
/// The menu's node id. Demos number their nodes from zero, so the frame takes
/// ids far above theirs.
pub let menu_id : Int32 = 10_003

///|
pub fn Gallery::new() -> Gallery {
  let demos = demos()
  let menu = @widget.OptionList::new()
  for i, demo in demos {
    menu.add_option(@widget.Choice::new(demo.name))
    if i + 1 < demos.length() && demos[i + 1].group != demo.group {
      menu.add_separator()
    }
  }
  { menu, demos, at: 0, }
}

///|
/// The frame around the demo now chosen.
pub fn Gallery::tree(self : Gallery) -> @app.Node {
  let demo = self.demos[self.at]
  @app.column(10_000, [
    @app.leaf(
      10_001,
      @widget.Header::new("moonetui gallery", note=demo.group.title() + " "),
      box=line(1),
    ),
    @app.row(10_002, [
      @app.leaf(menu_id, self.menu, box=@layout.Box::new(extent=Cells(26)), classes=[
        "menu",
      ]),
      @app.column(
        10_004,
        [
          @app.leaf(
            10_005,
            @widget.label(demo.note, style=@style.Style::new(dim=true)),
            box=line(2),
          ),
          demo.tree,
        ],
        classes=["stage"],
      ),
    ]),
    @app.leaf(
      10_006,
      @widget.Footer::new([
        ("tab", "move focus"),
        ("up down", "choose a demo"),
        ("ctrl-c", "quit"),
      ]),
      box=line(1),
    ),
  ])
}

///|
/// The frame's rules, then the chosen demo's.
pub fn Gallery::sheet(self : Gallery) -> @design.Stylesheet {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["menu"]),
    @design.Styles::new(border=Round),
  )
  sheet.add(
    @design.Sel::new(classes=["menu"], focus=true),
    @design.Styles::new(border=Heavy),
  )
  sheet.add(
    @design.Sel::new(classes=["stage"]),
    @design.Styles::new(border=Round, padding=@geom.Spacing::horizontal(1)),
  )
  for rule in self.demos[self.at].sheet.list() {
    sheet.add(rule.sel, rule.styles)
  }
  sheet
}

///|
/// Disable what the chosen demo asks to have disabled. Call once before the
/// application starts.
pub fn[D] Gallery::attach(self : Gallery, ui : @app.App[D]) -> Unit {
  for id in self.demos[self.at].disabled {
    ui.disable(id)
  }
}

///|
/// Answer what the application reports: a new highlight in the menu puts that
/// demo on the stage.
pub fn[D] Gallery::react(
  self : Gallery,
  ui : @app.App[D],
  out : @widget.Out,
) -> Unit {
  guard out is Highlighted(id~, index~) &&
    id == menu_id &&
    index != self.at &&
    index >= 0 &&
    index < self.demos.length() else {
    return
  }
  for gone in self.demos[self.at].disabled {
    ui.enable(gone)
  }
  self.at = index
  self.attach(ui)
  ui.set_sheet(self.sheet())
  ui.swap_root(self.tree())
}
