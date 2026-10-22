// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
pub fn borders() -> Demo {
  let kinds : Array[(String, @design.EdgeKind)] = [
    ("thin", Thin),
    ("round", Round),
    ("heavy", Heavy),
    ("double", Double),
    ("ascii", Ascii),
  ]
  let boxes = kinds.mapi((i, kind) => {
    @app.leaf(
      i + 1,
      @widget.Static::new(kind.0, align=Centre),
      box=@layout.Box::new(extent=Frac(1)),
      styles=@design.Styles::new(border=kind.1),
    )
  })
  Demo::new(
    "Borders",
    @app.row(0, boxes, gap=1, box=line(3)),
    group=Style,
    note="Five kinds of frame, drawn by the design system around any node.",
    rows=3,
  )
}

///|
pub fn colours() -> Demo {
  Demo::new(
    "Colours",
    @app.column(0, [@app.leaf(1, Swatches::{ })]),
    group=Style,
    note="The sixteen named colours, the 256-colour cube, and a true-colour sweep cut down to 256 and to 16.",
    rows=5,
  )
}

///|
/// A widget of its own: each row a strip of coloured cells after a label.
priv struct Swatches {}

///|
impl @widget.Widget for Swatches with fn render_line(_self, row, size) {
  let label = ["16", "256", "24-bit", "→ 256", "→ 16"]
  if row < 0 || row >= label.length() {
    return @strip.Strip::blank(size.width, @style.default)
  }
  let lead = @strip.Strip::of(label[row], @style.Style::new(dim=true)).pad_to(
    8, @style.default,
  )
  let span = @cmp.maximum(size.width - 8, 0)
  let cells = Array::makei(span, x => {
    let colour : @style.Colour = match row {
      0 => Ansi(x * 16 / @cmp.maximum(span, 1))
      1 => Ansi256(16 + x * 216 / @cmp.maximum(span, 1))
      _ => {
        let swept = sweep(x, span)
        match row {
          3 => swept.to_ansi256()
          4 => swept.to_ansi16()
          _ => swept
        }
      }
    }
    @strip.Seg::new(" ", @style.Style::new(bg=colour))
  })
  @strip.Strip::join([lead, @strip.Strip::from_segs(cells)])
}

///|
impl @widget.Widget for Swatches with fn hint(_self, size) {
  @geom.Size::new(size.width, 5)
}

///|
impl @widget.Widget for Swatches with fn handle(_self, _ctx, _msg) {
  false
}

///|
impl @widget.Widget for Swatches with fn focusable(_self) {
  false
}

///|
/// The hue at column `x` of `span`, fully saturated.
fn sweep(x : Int32, span : Int32) -> @style.Colour {
  let h = x.to_double() * 6.0 / @cmp.maximum(span, 1).to_double()
  let f = h - h.floor()
  let up = (f * 255.0).to_int()
  let down = 255 - up
  match h.to_int() {
    0 => @style.Colour::rgb(255, up, 0)
    1 => @style.Colour::rgb(down, 255, 0)
    2 => @style.Colour::rgb(0, 255, up)
    3 => @style.Colour::rgb(0, down, 255)
    4 => @style.Colour::rgb(up, 0, 255)
    _ => @style.Colour::rgb(255, 0, down)
  }
}

///|
pub fn text_styles() -> Demo {
  let styles : Array[(String, @style.Style)] = [
    ("bold", @style.Style::new(bold=true)),
    ("dim", @style.Style::new(dim=true)),
    ("italic", @style.Style::new(italic=true)),
    ("underline", @style.Style::new(underline=true)),
    ("strike", @style.Style::new(strike=true)),
    ("reverse", @style.Style::new(reverse=true)),
  ]
  let words = styles.mapi((i, pair) => {
    @app.leaf(
      i + 1,
      @widget.label(pair.0, style=pair.1),
      box=line(pair.0.length()),
    )
  })
  Demo::new(
    "Text styles",
    @app.row(0, words, gap=3, box=line(1)),
    group=Style,
    note="The SGR attributes every terminal knows, set on any style.",
    rows=1,
  )
}

///|
pub fn docks() -> Demo {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["pane"]),
    @design.Styles::new(border=Round),
  )
  sheet.add(@design.Sel::new(name="Header"), @design.Styles::new(dock=Top))
  sheet.add(@design.Sel::new(name="Footer"), @design.Styles::new(dock=Bottom))
  let pane = (id : Int32, text : String, extent : @layout.Extent) => {
    @app.leaf(
      id,
      @widget.Static::new(text, align=Centre),
      box=@layout.Box::new(extent~),
      classes=["pane"],
    )
  }
  Demo::new(
    "Docks and fractions",
    @app.column(0, [
      @app.leaf(1, @widget.Header::new("docked to the top"), name="Header"),
      @app.row(2, [
        pane(3, "12 columns", Cells(12)),
        pane(4, "two shares", Frac(2)),
        pane(5, "one share", Frac(1)),
      ]),
      @app.leaf(6, @widget.Footer::new([("dock", "bottom")]), name="Footer"),
    ]),
    group=Style,
    note="Edge docks take their side first; the flow divides what is left in cells and shares.",
    rows=7,
    sheet~,
  )
}

///|
pub fn grid() -> Demo {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["cell"]),
    @design.Styles::new(border=Thin),
  )
  let cell = (id : Int32, text : String) => {
    @app.leaf(id, @widget.Static::new(text, align=Centre), classes=["cell"])
  }
  Demo::new(
    "Grid",
    @app.grid(
      0,
      [
        @app.leaf(
          1,
          @widget.Static::new("two columns", align=Centre),
          classes=["cell"],
          styles=@design.Styles::new(column_span=2),
        ),
        @app.leaf(
          2,
          @widget.Static::new("two rows", align=Centre),
          classes=["cell"],
          styles=@design.Styles::new(row_span=2),
        ),
        cell(3, "one"),
        cell(4, "one"),
      ],
      cols=3,
      gutter=1,
    ),
    group=Style,
    note="A grid of columns and rows, with spans and a gutter that loses no column.",
    rows=6,
    sheet~,
  )
}

///|
pub fn states() -> Demo {
  let sheet = @design.Stylesheet::new()
  sheet.add(
    @design.Sel::new(classes=["key"]),
    @design.Styles::new(border=Round),
  )
  sheet.add(
    @design.Sel::new(classes=["key"], hover=true),
    @design.Styles::new(text=@style.Style::new(fg=@style.cyan)),
  )
  sheet.add(
    @design.Sel::new(classes=["key"], focus=true),
    @design.Styles::new(border=Heavy, text=@style.Style::new(bold=true)),
  )
  sheet.add(
    @design.Sel::new(classes=["key"], disabled=true),
    @design.Styles::new(text=@style.Style::new(dim=true)),
  )
  let key = (id : Int32, text : String) => {
    @app.leaf(
      id,
      @widget.Button::new(text, focus_style=@style.default),
      box=line(14),
      classes=["key"],
    )
  }
  Demo::new(
    "States",
    @app.row(
      0,
      [key(1, "focus me"), key(2, "hover me"), key(3, "disabled")],
      gap=1,
      box=line(3),
    ),
    group=Style,
    note="Rules for :focus, :hover and :disabled stack over the plain rule by weight.",
    rows=3,
    sheet~,
    disabled=[3],
  )
}
