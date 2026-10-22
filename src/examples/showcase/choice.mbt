// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn switch() -> Demo {
  Demo::new(
    "Switch",
    @app.row(0, [
      @app.leaf(1, @widget.Switch::new(), box=line(6)),
      @app.leaf(2, @widget.Switch::new(value=true), box=line(6)),
    ]),
    group=Choice,
    note="An on-off thumb that slides to the side of its value.",
    rows=1,
  )
}

///|
pub fn checkbox() -> Demo {
  Demo::new(
    "Checkbox",
    @app.column(0, [
      @app.leaf(
        1,
        @widget.Checkbox::new("Enable extras", value=true),
        box=line(1),
      ),
      @app.leaf(2, @widget.Checkbox::new("Send reports"), box=line(1)),
    ]),
    group=Choice,
    note="A labelled box that Space, Enter or a click turns on and off.",
    rows=2,
  )
}

///|
pub fn radio_set() -> Demo {
  let set = @widget.RadioSet::new([
    @widget.RadioButton::new("Fast"),
    @widget.RadioButton::new("Balanced", value=true),
    @widget.RadioButton::new("Quiet"),
  ])
  Demo::new(
    "RadioSet",
    @app.column(0, [@app.leaf(1, set)]),
    group=Choice,
    note="Radio buttons where pressing one releases the rest.",
    rows=3,
  )
}

///|
pub fn option_list() -> Demo {
  let list = @widget.OptionList::new(options=[
    @widget.Choice::new("Alpha"),
    @widget.Choice::new("Beta"),
    @widget.Choice::new("Retired", disabled=true),
  ])
  list.add_separator()
  list.add_option(@widget.Choice::new("Omega"))
  Demo::new(
    "OptionList",
    @app.column(0, [@app.leaf(1, list)]),
    group=Choice,
    note="Prompts with separators; the highlight never rests on a disabled one.",
    rows=5,
  )
}

///|
pub fn selection_list() -> Demo {
  let list = @widget.SelectionList::new(options=[
    @widget.Selection::new("Clean build", "clean", initial_state=true),
    @widget.Selection::new("All targets", "targets", initial_state=true),
    @widget.Selection::new("Sign the tag", "sign"),
  ])
  Demo::new(
    "SelectionList",
    @app.column(0, [@app.leaf(1, list)]),
    group=Choice,
    note="A list where every entry is a checkbox of its own.",
    rows=3,
  )
}

///|
pub fn select() -> Demo {
  let pick = @widget.Select::new(
    options=[("Alpha", "a"), ("Beta", "b"), ("Gamma", "g"), ("Delta", "d")],
    prompt="Pick a letter",
  )
  Demo::new(
    "Select",
    @app.column(0, [@app.leaf(1, pick)]),
    group=Choice,
    note="A prompt that opens in place; typing narrows it, Escape folds it away.",
    rows=5,
  )
}
