// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a block frames its widget with a title on the top edge" {
  let block : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("hi"),
    title="Box",
    padding=@geom.Spacing::all(1),
  )
  assert_eq(rows(block, size(12, 5)), [
    "┌ Box ─────┐", "│          │", "│ hi       │", "│          │",
    "└──────────┘",
  ])
}

///|
test "a block asks for its widget's size plus the frame and padding" {
  let block : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("hi"),
    title="Box",
    padding=@geom.Spacing::all(1),
  )
  assert_eq(block.hint(size(40, 20)), size(6, 5))
  let bare : &@widget.Widget = @widget.Block::new(@widget.Static::new("hi"))
  assert_eq(bare.hint(size(40, 20)), size(4, 3))
  let none : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("hi"),
    border=None,
    padding=@geom.Spacing::horizontal(2),
  )
  assert_eq(none.hint(size(40, 20)), size(6, 1))
}

///|
test "a block without a border is padding alone" {
  let block : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("hi"),
    border=None,
    padding=@geom.Spacing::all(1),
  )
  assert_eq(rows(block, size(6, 3)), ["      ", " hi   ", "      "])
}

///|
test "a block's title sits to the left, the centre or the right" {
  let at = (align : @widget.Align) => {
    let block : &@widget.Widget = @widget.Block::new(
      @widget.Static::new("hi"),
      title="Box",
      title_align=align,
    )
    block.render_line(0, size(12, 3)).text()
  }
  assert_eq(at(Left), "┌ Box ─────┐")
  assert_eq(at(Centre), "┌── Box ───┐")
  assert_eq(at(Right), "┌───── Box ┐")
}

///|
test "a block too narrow for its title clips it" {
  let block : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("hi"),
    title="Long title",
  )
  assert_eq(block.render_line(0, size(8, 3)).text(), "┌Long t┐")
  let tight : &@widget.Widget = @widget.Block::new(
    @widget.Static::new("hi"),
    title="Long title",
  )
  assert_eq(tight.render_line(0, size(1, 3)).text(), "┌")
}

///|
test "a block hands keys to the widget inside under the block's id" {
  let button = @widget.Button::new("Go")
  let block : &@widget.Widget = @widget.Block::new(
    button,
    padding=@geom.Spacing::all(1),
  )
  let out = press(block, 7, size(12, 3), key(Enter))
  assert_eq(out, [@widget.Pressed(id=7)])
  assert_eq(block.focusable(), true)
}

///|
test "a block moves a click into the frame before the widget sees it" {
  let tabs = @widget.Tabs::new(labels=["one", "two"])
  let block : &@widget.Widget = @widget.Block::new(tabs)
  // The frame takes a column and a row, so a click on `two` lands one in.
  let out = press(
    block,
    4,
    size(14, 4),
    Mouse({ kind: Down, button: 0, x: 7, y: 1, mods: @event.none, }),
  )
  assert_eq(out, [
    @widget.TakeFocus(id=4),
    @widget.Selected(id=4, index=1),
    @widget.Repaint(id=4),
  ])
}

///|
test "a block around a widget that takes no focus is not focusable" {
  let block : &@widget.Widget = @widget.Block::new(@widget.Static::new("hi"))
  assert_eq(block.focusable(), false)
  assert_eq(press(block, 1, size(6, 3), key(Enter)), [])
}

///|
test "a block reports the padding it takes and a new title" {
  let block = @widget.Block::new(
    @widget.Static::new("hi"),
    title="Box",
    padding=@geom.Spacing::vertical(1),
  )
  assert_eq(
    block.padding_of(),
    @geom.Spacing::all(1).add(@geom.Spacing::vertical(1)),
  )
  assert_eq(block.title(), "Box")
  block.set_title("Pane")
  assert_eq(block.title(), "Pane")
}
