// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn block() -> Demo {
  let framed = @widget.Block::new(
    @widget.Static::new("Any widget goes inside."),
    title="Wrapped",
    border=Some(@widget.round),
    padding=@geom.Spacing::all(1),
  )
  let padded = @widget.Block::new(
    @widget.Static::new("Padding alone.", align=Centre),
    border=None,
    padding=@geom.Spacing::all(1),
    style=@style.Style::new(bg=@style.blue),
  )
  Demo::new(
    "Block",
    @app.row(
      0,
      [
        @app.leaf(
          1,
          framed,
          box=@layout.Box::new(extent=Frac(1)),
          styles=@design.Styles::new(border=@design.Off),
        ),
        @app.leaf(2, padded, box=@layout.Box::new(extent=Frac(1))),
      ],
      gap=1,
    ),
    group=Navigation,
    note="A frame, a title and padding around any other widget, which is drawn and driven at the size left for it.",
    rows=5,
  )
}

///|
pub fn content_switcher() -> Demo {
  let first = @widget.Static::new("The first thing the space holds.")
  let second = @widget.Button::new("Take the second")
  let switcher = @widget.ContentSwitcher::new(children=[first, second])
  switcher.switch_to(0)
  Demo::new(
    "ContentSwitcher",
    @app.column(0, [
      @app.leaf(1, switcher, box=line(1)),
      @app.leaf(
        2,
        @widget.label(
          "One of several in the same place; the host calls switch_to.",
          style=@style.Style::new(dim=true),
        ),
        box=line(1),
      ),
      @app.leaf(3, @widget.Button::new("Switch"), box=line(1)),
    ]),
    group=Navigation,
    note="One of several widgets in the same place: the one showing is drawn, measured and given the input.",
    rows=3,
  )
}

///|
pub fn pretty() -> Demo {
  let pretty = @widget.Pretty::new(
    value=VObj([
      ("name", VStr("moonetui")),
      ("version", VStr("0.4.0")),
      ("widgets", VInt(48)),
      ("colours", VArr([VStr("ansi"), VStr("256"), VStr("24-bit")])),
      ("unicode", VBool(true)),
    ]),
  )
  Demo::new(
    "Pretty",
    @app.column(0, [@app.leaf(1, pretty, box=line(10))]),
    group=Text,
    note="A value printed the way it reads: laid out with an indent, coloured by what each part is, on one line when it fits.",
    rows=10,
  )
}

///|
pub fn masked_input() -> Demo {
  let phone = @widget.MaskedInput::new("(###) ###-####")
  let date = @widget.MaskedInput::new("####-##-##")
  let key = @widget.MaskedInput::new("????-????", placeholder="·")
  Demo::new(
    "MaskedInput",
    @app.column(0, [
      @app.leaf(1, phone, box=line(1)),
      @app.leaf(2, date, box=line(1)),
      @app.leaf(3, key, box=line(1)),
    ]),
    group=Entry,
    note="A field ruled by a template: # a digit, A a letter, ? either, * anything, and the rest written as it is.",
    rows=3,
  )
}

///|
pub fn link() -> Demo {
  let guide = @widget.Link::new(
    "The MoonBit guide",
    target="https://docs.moonbitlang.com",
  )
  let mooncakes = @widget.Link::new("mooncakes.io")
  Demo::new(
    "Link",
    @app.column(0, [
      @app.leaf(1, guide, box=line(1)),
      @app.leaf(2, mooncakes, box=line(1)),
    ]),
    group=Text,
    note="Words that go somewhere: underlined, taken by Enter or by a click, and dimmed once they have been.",
    rows=2,
  )
}

///|
pub fn clock() -> Demo {
  let bar = @widget.Header::new(
    "moonetui",
    note="0.4.0",
    clock=Some(@widget.Clock::new(hour=9, minute=41, second=26)),
  )
  Demo::new(
    "Clock",
    @app.column(0, [
      @app.leaf(1, bar, box=line(1)),
      @app.leaf(
        2,
        @widget.label(
          "The bar's clock counts itself forward from every frame.",
          style=@style.Style::new(dim=true),
        ),
        box=line(1),
      ),
    ]),
    group=Text,
    note="A time of day that runs off the same tick every widget sees, so a header can keep one without a clock of the host's.",
    rows=2,
  )
}

///|
pub fn anchoring() -> Demo {
  let corners : Array[@app.Node] = []
  let pinned : Array[(String, @layout.Anchor)] = [
    ("top left", @layout.Anchor::new(top=true, left=true)),
    ("top right", @layout.Anchor::new(top=true, right=true)),
    ("bottom left", @layout.Anchor::new(bottom=true, left=true)),
    ("bottom right", @layout.Anchor::new(bottom=true, right=true)),
  ]
  for i, place in pinned {
    let (word, anchor) = place
    corners.push(
      @app.leaf(
        i + 1,
        @widget.Static::new(word, align=Centre),
        styles=@design.Styles::new(
          width=Cells(16),
          height=Cells(3),
          anchor~,
          align=@design.Align::new(v=@design.Middle),
          border=@design.Round,
        ),
      ),
    )
  }
  corners.push(
    @app.leaf(
      9,
      @widget.Static::new("held to nothing, put in the middle", align=Centre),
      styles=@design.Styles::new(
        width=Cells(36),
        height=Cells(3),
        anchor=@layout.free,
        pivot=Middle,
        align=@design.Align::new(v=@design.Middle),
        border=@design.Round,
      ),
    ),
  )
  Demo::new(
    "Anchors",
    @app.column(0, corners),
    group=Style,
    note="A box held to the edges it names: an axis with both edges held stretches, one with neither keeps its size and sits where its pivot says.",
    rows=8,
  )
}

///|
pub fn theme() -> Demo {
  let sheet = @design.dark.sheet()
  let roles = @design.roles()
  let swatches : Array[@app.Node] = []
  for i, role in roles {
    swatches.push(
      @app.leaf(
        i + 1,
        @widget.Static::new(role.name(), align=Centre),
        box=line(1),
        classes=[role.name() + "-fill"],
      ),
    )
  }
  Demo::new(
    "Theme",
    @app.column(0, swatches),
    group=Style,
    note="One value holding every semantic colour: set it as a whole and everything styled by role changes with it.",
    rows=11,
    sheet~,
  )
}
