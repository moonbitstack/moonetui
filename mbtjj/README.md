# mbtjj

Jujutsu in a terminal: the log with its graph, the change under the cursor, what
it does, and the operations the repository has seen — in one window, on the
`jj` you already have.

It is a program, not a demo: it reads a real repository by running `jj`, and it
writes nothing to the repository itself. What it shows is what `jj` printed.

```
src/
  chrome.mbt   the palette and the strips a screen is framed with
  model.mbt    the rows of a log, the cursor, the revset, what to ask for next
  jj.mbt       the one place that talks to jj: template, arguments, parsing
  run.mbt      a request answered, and what came back put where the screen reads it
  view.mbt     the window, its keys and its help
  main/        the command line
```

## Build and run

From the workspace that holds this directory:

```
moon run --target native mbtjj/src/main                  # the repository here
moon run --target native mbtjj/src/main -- ~/code/app    # the repository there
```

From inside `mbtjj/`:

```
moon run --target native src/main
```

Building a binary is the same command with `moon build --release`; the
executable lands in `target/native/release/build/mbtjj/src/main/main.exe`.

## What it asks jj for

| Pane | Command |
|:--|:--|
| the log | `jj --repository <path> log --color=never -T '<template>'` |
| what the change does | `jj --repository <path> diff -r <change_id> --color=never` |
| the operations | `jj --repository <path> op log --color=never -n 30` |

The log's template separates its fields with `0x1F` — change id, commit id,
author, date, bookmarks, parents, whether the change is empty, the first line of
the description — so reading a row is splitting it, not guessing at column
widths. The graph comes before those fields on the same line, and a line that
carries only lanes is a merge being drawn; both are kept as `jj` drew them.

The repository is named with `--repository`, not reached by a working directory,
so a path with a space in it, or one written with forward slashes on Windows,
needs no quoting of its own.

`jj` is looked for on `PATH`. A reader whose `jj` is somewhere else names it
once:

```
MBTJJ_JJ=/opt/jj/bin/jj moon run --target native src/main
```

## Keys

| Key | Does |
|:--|:--|
| `↑` `↓` | the revision above, below |
| `pgup` `pgdn` | a screen at a time |
| `g` `G` | the first, the last |
| `/` | a revset: type it, `enter` applies it, `esc` drops it |
| `d` | what the change does |
| `o` | the operations, newest first |
| `r` | read the log again |
| `?` | the keys, in place of the change |
| `q` | leave |

A revset is passed to `jj log -r` as it was typed, so everything `jj` accepts —
`@-`, `main..@`, `author(ada)`, `description(fix)` — is accepted here. A revset
`jj` refuses puts jj's own message on the line above the keys and leaves the log
as it was.

## Options

| Flag | Means |
|:--|:--|
| `<path>` | the repository to open; the current directory by default |
| `--revset <expr>` | open on that revset |
| `--demo` | a log captured from a repository, for a screenshot or a test |
| `--headless` | draw a few frames and print them, for a check |
| `--frames <n>` | how many frames `--headless` draws |

## What it does not do

- **It does not write.** No describe, no new, no abandon. A client that can
  rewrite history is a different program with a different set of questions; this
  one reads.
- **The details pane shows the first line of the description**, because the
  template asks for `description.first_line()`. The whole message is one
  `jj describe` away, and the diff pane is where the substance is.
- **No diff colouring beyond the file header**: `jj diff --color=never` prints
  numbered lines, and the client colours `Added`, `Removed`, `Modified` and
  `+`/`-` lines, not words.
