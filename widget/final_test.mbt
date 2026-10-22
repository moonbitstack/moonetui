// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn crew() -> @widget.DataTable {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Name"))
  ignore(table.add_column("Qty", align=Right))
  ignore(table.add_row(["Paul", "3"], label="1"))
  ignore(table.add_row(["Jessica", "12"], label="2"))
  table
}

///|
test "data table renders a header and padded rows" {
  let table = crew()
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(16, 4)), [
    "    Name     Qty", " 1  Paul       3", " 2  Jessica   12", "                ",
  ])
  assert_eq(w.hint(size(16, 24)), size(17, 3))
}

///|
test "data table hides the header when asked" {
  let bare = @widget.DataTable::new(show_header=false)
  ignore(bare.add_column("Name"))
  ignore(bare.add_row(["Paul"], label="1"))
  let w : &@widget.Widget = bare
  assert_eq(rows(w, size(10, 2)), [" 1  Paul  ", "          "])
  assert_eq(w.hint(size(10, 24)), size(9, 1))
}

///|
test "data table walks a cell cursor and reports it" {
  let table = crew()
  let w : &@widget.Widget = table
  let at = size(16, 4)
  assert_eq(press(w, 7, at, key(Down)), [
    @widget.CellHighlighted(id=7, row=1, col=0),
    @widget.Repaint(id=7),
  ])
  assert_eq(press(w, 7, at, key(Right)), [
    @widget.CellHighlighted(id=7, row=1, col=1),
    @widget.Repaint(id=7),
  ])
  assert_eq(press(w, 7, at, key(Enter)), [
    @widget.CellSelected(id=7, row=1, col=1),
  ])
}

///|
test "data table row cursor reports rows and column cursor reports columns" {
  let by_row = @widget.DataTable::new(cursor_type=Row)
  ignore(by_row.add_column("Name"))
  ignore(by_row.add_column("Qty"))
  ignore(by_row.add_row(["Paul", "3"]))
  ignore(by_row.add_row(["Jessica", "12"]))
  let w : &@widget.Widget = by_row
  let at = size(16, 4)
  assert_eq(press(w, 2, at, key(Down)), [
    @widget.Highlighted(id=2, index=1),
    @widget.Repaint(id=2),
  ])
  assert_eq(press(w, 2, at, key(Right)), [])
  assert_eq(press(w, 2, at, key(Enter)), [@widget.Selected(id=2, index=1)])
  let by_col = @widget.DataTable::new(cursor_type=Column)
  ignore(by_col.add_column("Name"))
  ignore(by_col.add_column("Qty"))
  ignore(by_col.add_row(["Paul", "3"]))
  let wc : &@widget.Widget = by_col
  assert_eq(press(wc, 3, at, key(Right)), [
    @widget.Highlighted(id=3, index=1),
    @widget.Repaint(id=3),
  ])
  assert_eq(press(wc, 3, at, key(Enter)), [@widget.Selected(id=3, index=1)])
}

///|
test "data table clicks select headers labels and cells" {
  let table = crew()
  let w : &@widget.Widget = table
  let at = size(16, 4)
  let click = fn(x : Int32, y : Int32) -> @widget.Msg {
    Mouse({ kind: Down, button: 0, x, y, mods: @event.none, })
  }
  assert_eq(press(w, 4, at, click(13, 0)), [@widget.HeaderSelected(id=4, col=1)])
  assert_eq(press(w, 4, at, click(0, 2)), [@widget.Selected(id=4, index=1)])
  assert_eq(press(w, 4, at, click(7, 2)), [
    @widget.CellHighlighted(id=4, row=1, col=0),
    @widget.Repaint(id=4),
  ])
  assert_eq(press(w, 4, at, click(7, 2)), [
    @widget.CellSelected(id=4, row=1, col=0),
  ])
}

///|
test "data table sorts rows by a column" {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Name"))
  ignore(table.add_column("Qty"))
  ignore(table.add_row(["Chani"], label="3"))
  ignore(table.add_row(["Alia"], label="1"))
  ignore(table.add_row(["Paul"], label="2"))
  table.sort(0)
  let w : &@widget.Widget = table
  assert_eq(rows(w, size(14, 4)), [
    "    Name   Qty", " 1  Alia      ", " 3  Chani     ", " 2  Paul      ",
  ])
  table.sort(0, reverse=true)
  assert_eq(rows(w, size(14, 4)), [
    "    Name   Qty", " 2  Paul      ", " 3  Chani     ", " 1  Alia      ",
  ])
}

///|
test "data table scrolls to keep the cursor in view" {
  let table = @widget.DataTable::new()
  ignore(table.add_column("Name"))
  let total = 8
  for i in 0..<total {
    ignore(table.add_row(["row \{i}"]))
  }
  let w : &@widget.Widget = table
  let at = size(10, 4)
  let mut steps = 0
  while steps < 5 {
    ignore(press(w, 9, at, key(Down)))
    steps = steps + 1
  }
  assert_eq(table.cursor_row(), 5)
  assert_eq(rows(w, at), [
    " Name     ", " row 3    ", " row 4    ", " row 5    ",
  ])
}

///|
test "tooltip wraps its content inside its padding" {
  let tip : &@widget.Widget = @widget.Tooltip::new("hello world")
  assert_eq(rows(tip, size(12, 6)), [
    "            ", "  hello     ", "  world     ", "            ", "            ",
    "            ",
  ])
  assert_eq(tip.hint(size(80, 24)), size(15, 3))
  assert_eq(tip.focusable(), false)
  assert_eq(press(tip, 1, size(12, 4), key(Down)), [])
}

///|
test "toast renders a bar a title and a message" {
  let toast : &@widget.Widget = @widget.Toast::new(
    "saved to disk",
    title="Done",
    level=Warning,
  )
  assert_eq(rows(toast, size(18, 2)), [
    "▌ Done            ", "▌ saved to disk   ",
  ])
  assert_eq(toast.hint(size(80, 24)), size(17, 2))
  assert_eq(toast.focusable(), false)
}

///|
test "toast expires after its duration and retires on a click" {
  let toast : &@widget.Widget = @widget.Toast::new("gone soon", duration=100)
  let at = size(14, 2)
  assert_eq(press(toast, 5, at, Tick(50)), [])
  assert_eq(press(toast, 5, at, Tick(60)), [@widget.Dismissed(id=5)])
  let steady : &@widget.Widget = @widget.Toast::new("stays", duration=0)
  assert_eq(press(steady, 6, at, Tick(5000)), [])
  assert_eq(
    press(
      steady,
      6,
      at,
      Mouse({ kind: Down, button: 0, x: 2, y: 0, mods: @event.none, }),
    ),
    [@widget.Dismissed(id=6)],
  )
}

///|
test "markdown lays out headings lists quotes code rules and tables" {
  let doc = "# Title\nword one two\n\n- first\n- second\n\n> quoted line\n\n```\nlet x = 1\n```\n\n---\n\n| A | B |\n|---|:-:|\n| 1 | 22 |\n"
  let md : &@widget.Widget = @widget.Markdown::new(doc)
  assert_eq(rows(md, size(20, 16)), [
    "Title               ", "                    ", "word one two        ", "                    ",
    "• first             ", "• second            ", "                    ", "▌ quoted line       ",
    "                    ", "let x = 1           ", "                    ", "────────────────────",
    "                    ", " A │ B              ", "───┼────            ",
    " 1 │ 22             ",
  ])
}

///|
test "markdown styles inline bold italic code and links" {
  let doc = "plain **bold** and *lean* plus `code` with [MoonBit](https://moonbitlang.com) here"
  let md = @widget.Markdown::new(doc)
  let w : &@widget.Widget = md
  let line = w.render_line(0, size(60, 1))
  let plain_at = line.segs[0].style.attrs.bold
  let bold_at = line.segs[1].style.attrs.bold
  let italic_at = line.segs[3].style.attrs.italic
  let code_at = line.segs[5].style.fg
  let link_at = line.segs[7].style.attrs.underline
  assert_eq((plain_at, bold_at, italic_at, link_at), (false, true, true, true))
  assert_eq(code_at == @style.cyan, true)
}

///|
test "markdown scrolls through long documents" {
  let parts : Array[String] = []
  for i in 0..<12 {
    parts.push("line \{i}")
  }
  ignore(parts)
  let mut doc = ""
  for i in 0..<12 {
    if i > 0 {
      doc = doc + "\n\n"
    }
    doc = doc + "para \{i}"
  }
  let md : &@widget.Widget = @widget.Markdown::new(doc)
  let at = size(10, 3)
  assert_eq(press(md, 8, at, key(Down)), [
    @widget.Scrolled(id=8, x=0, y=1),
    @widget.Repaint(id=8),
  ])
  assert_eq(press(md, 8, at, key(PageDown)), [
    @widget.Scrolled(id=8, x=0, y=3),
    @widget.Repaint(id=8),
  ])
  assert_eq(rows(md, at), ["          ", "para 2    ", "          "])
  assert_eq(md.hint(size(10, 24)).height, 23)
}
