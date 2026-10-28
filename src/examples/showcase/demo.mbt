// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub(all) enum Group {
  Text
  Entry
  Choice
  Navigation
  Data
  Overlay
  Chart
  Style
} derive(Eq, Debug)

///|
pub extend Group with Debug::{to_repr}

///|
pub extend Group with Eq::{not_equal, equal}

///|
pub fn Group::title(self : Group) -> String {
  match self {
    Text => "Text and display"
    Entry => "Entry and logs"
    Choice => "Choices"
    Navigation => "Navigation and structure"
    Data => "Data and notices"
    Overlay => "Dialogs, menus and commands"
    Chart => "Charts and meters"
    Style => "Design system"
  }
}

///|
/// One demonstration: a tree to run, the rules to style it with, and the ids a
/// host disables before it starts.
pub struct Demo {
  name : String
  group : Group
  note : String
  rows : Int32
  tree : @app.Node
  sheet : @design.Stylesheet
  disabled : Array[Int32]
}

///|
pub fn Demo::new(
  name : String,
  tree : @app.Node,
  group~ : Group,
  note~ : String,
  rows~ : Int32,
  sheet~ : @design.Stylesheet = @design.Stylesheet::new(),
  disabled~ : Array[Int32] = [],
) -> Demo {
  { name, group, note, rows, tree, sheet, disabled, }
}

///|
/// Every demonstration, in the order the documentation shows them.
pub fn demos() -> Array[Demo] {
  [
    static_text(),
    header(),
    clock(),
    footer(),
    link(),
    rule(),
    digits(),
    sparkline(),
    progress(),
    loading_indicator(),
    placeholder(),
    pretty(),
    input(),
    masked_input(),
    text_area(),
    log(),
    rich_log(),
    switch(),
    checkbox(),
    radio_set(),
    option_list(),
    selection_list(),
    select(),
    button(),
    list_view(),
    tabs(),
    tabbed_content(),
    collapsible(),
    content_switcher(),
    block(),
    tree(),
    directory_tree(),
    data_table(),
    markdown(),
    tooltip(),
    toast(),
    message_box(),
    input_box(),
    file_dialog(),
    menu_bar(),
    menu(),
    command_palette(),
    chart(),
    bar_chart(),
    gauge(),
    scrollbar(),
    borders(),
    colours(),
    text_styles(),
    docks(),
    anchoring(),
    grid(),
    theme(),
    states(),
  ]
}

///|
pub fn find(name : String) -> Demo? {
  demos().iter().find_first(demo => demo.name == name)
}

///|
fn line(n : Int32) -> @layout.Box {
  @layout.Box::new(extent=Cells(n))
}
