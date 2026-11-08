// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
let patch : String =
  #|--- a/readme.md
  #|+++ b/readme.md
  #|@@ -1,3 +1,3 @@
  #| # moonetui
  #|-fifty widgets
  #|+sixty widgets
  #| and more

///|
test "a diff reads the headings, the marks and the lines between them" {
  let diff = @widget.Diff::of_unified(patch)
  assert_eq(diff.lines().length(), 7)
  assert_eq(
    diff.lines()[0],
    @widget.DiffLine::new(kind=Header, text="a/readme.md"),
  )
  assert_eq(diff.lines()[1].text(), "b/readme.md")
  assert_eq(diff.lines()[2].kind(), Hunk)
  assert_eq(diff.lines()[3].kind(), Context)
  assert_eq(diff.lines()[3].text(), "# moonetui")
  assert_eq(diff.lines()[4].text(), "fifty widgets")
  assert_eq(diff.lines()[5].kind(), Added)
  assert_eq(diff.stats(), (1, 1))
}

///|
test "a diff draws a mark before each line and the text after it" {
  let diff = @widget.Diff::of_unified(patch)
  let lines = rows(diff, size(30, 7))
  assert_eq(lines[0], "a/readme.md                   ")
  assert_eq(lines[1], "b/readme.md                   ")
  assert_eq(lines[2], "@@ -1,3 +1,3 @@               ")
  assert_eq(lines[3], "  # moonetui                  ")
  assert_eq(lines[4], "- fifty widgets               ")
  assert_eq(lines[5], "+ sixty widgets               ")
  assert_eq(lines[6], "  and more                    ")
  assert_eq(diff.hint(size(30, 2)), size(30, 2))
}

///|
test "a diff of its own lines reads the same as one parsed" {
  let lines = [
    @widget.DiffLine::new(kind=Meta, text="diff --git a/x b/x"),
    @widget.DiffLine::new(kind=Added, text="one"),
  ]
  let diff = @widget.Diff::new(lines~)
  assert_eq(diff.stats(), (1, 0))
  assert_eq(rows(diff, size(30, 2))[0], "diff --git a/x b/x            ")
  assert_eq(rows(diff, size(30, 2))[1], "+ one                         ")
  diff.set_lines([])
  assert_eq(diff.offset(), 0)
}

///|
test "a diff walks a line, a screen and its ends" {
  let diff = @widget.Diff::of_unified(patch)
  assert_eq(press(diff, 4, size(30, 3), key(Down))[0], Scrolled(id=4, x=0, y=1))
  assert_eq(diff.offset(), 1)
  assert_eq(
    press(diff, 4, size(30, 3), key(PageDown))[0],
    Scrolled(id=4, x=0, y=3),
  )
  assert_eq(press(diff, 4, size(30, 3), key(End))[0], Scrolled(id=4, x=0, y=6))
  assert_eq(press(diff, 4, size(30, 3), key(Home))[0], Scrolled(id=4, x=0, y=0))
  assert_eq(press(diff, 4, size(30, 3), key(Up)), [])
}

///|
test "the wheel moves a diff by a line" {
  let diff = @widget.Diff::of_unified(patch)
  assert_eq(
    press(diff, 1, size(30, 3), mouse(ScrollDown, 0, 0))[0],
    Scrolled(id=1, x=0, y=1),
  )
  assert_eq(
    press(diff, 1, size(30, 3), mouse(ScrollUp, 0, 0))[0],
    Scrolled(id=1, x=0, y=0),
  )
}

///|
test "a diff paints nothing past its last line and takes focus" {
  let diff = @widget.Diff::new(lines=[@widget.DiffLine::new(text="one")])
  assert_eq(rows(diff, size(10, 2))[1], "          ")
  assert_eq(diff.focusable(), true)
  assert_eq(press(diff, 1, size(10, 2), Focus(true)), [Repaint(id=1)])
  assert_eq(press(diff, 1, size(10, 2), mouse(Down, 1, 1)), [TakeFocus(id=1)])
  assert_eq(@widget.Diff::of_unified("").lines().length(), 0)
}
