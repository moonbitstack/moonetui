///|
/// A log captured from a repository, so the window can be shown — in a
/// screenshot, in a test — where no repository is at hand. The fields are the
/// ones the template asks `jj` for.
pub let demo_log : String = "@    aaaaaaaabbbb\u{1f}111111111111\u{1f}leo\u{1f}2026-11-17 19:41\u{1f}main\u{1f}ccccccccdddd,eeeeeeeeffff\u{1f}full\u{1f}feat: a frame redraws the rows that changed\n" +
  "├─╮  \n" +
  "│ ○  ccccccccdddd\u{1f}222222222222\u{1f}ada\u{1f}2026-11-17 19:12\u{1f}\u{1f}gggggggghhhh\u{1f}full\u{1f}fix: a pane head keeps its count\n" +
  "○ │  eeeeeeeeffff\u{1f}333333333333\u{1f}bo\u{1f}2026-11-17 18:47\u{1f}feat/diff\u{1f}gggggggghhhh\u{1f}full\u{1f}feat: a conflict in the middle\n" +
  "├─╯  \n" +
  "◆    gggggggghhhh\u{1f}444444444444\u{1f}leo\u{1f}2026-11-17 17:58\u{1f}main@\u{1f}iiiiiiiijjjj\u{1f}full\u{1f}docs: the round's account\n" +
  "○    iiiiiiiijjjj\u{1f}555555555555\u{1f}kai\u{1f}2026-11-16 20:31\u{1f}docs/guide\u{1f}kkkkkkkkllll\u{1f}full\u{1f}docs: a guide that runs the library twice\n" +
  "○    kkkkkkkkllll\u{1f}666666666666\u{1f}leo\u{1f}2026-11-16 19:04\u{1f}\u{1f}\u{1f}empty\u{1f}(no description set)\n" +
  "○    mmmmmmmmnnnn\u{1f}000000000000\u{1f}\u{1f}1970-01-01 09:00\u{1f}\u{1f}\u{1f}empty\u{1f}root()\n"

///|
/// A diff in the shape `jj diff --color=never` writes it.
pub let demo_diff : String = "Modified regular file src/ui/view.mbt:\n" +
  "   12:    12: fn head(name) {\n" +
  "   13:     -   let room = width\n" +
  "   13:     +   let room = width - cells(label)\n" +
  "   14:    14: }\n" +
  "Added regular file src/ui/keys.mbt:\n" +
  "        1: fn keys(pairs) {\n" +
  "        2: }\n"

///|
/// An operations log in the shape `jj op log` writes it.
pub let demo_ops : String = "@  cf10c8a9ebaa leo@host now, lasted 15 milliseconds\n" +
  "│  new empty commit\n" +
  "│  args: jj new vxwoyvtqonuo wunosqqnzwrm -m 'merge: both lines'\n" +
  "○  f17e98d20ee1 leo@host now, lasted 9 milliseconds\n" +
  "│  create bookmark main pointing to commit 0ac67ad3\n" +
  "│  args: jj bookmark create main -r @\n" +
  "○  2b1f7c0d4e11 leo@host 19:12, lasted 40 milliseconds\n" +
  "│  describe commit rlvkpnrz\n" +
  "│  args: jj describe -m 'feat: a frame redraws the rows that changed'\n"
