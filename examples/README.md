# examples

Two programs built with the library, each a module of its own. They are
examples in the sense that matters — nothing in them reaches past what
`moonbitstack/moonetui` publishes, so any part of them can be copied into a
program of your own — and both do the real thing rather than pretend to.

| Program | What it is | Run it |
|:--|:--|:--|
| [`mbtjj`](mbtjj/) | a client for [Jujutsu](https://github.com/jj-vcs/jj): the log with its graph, the change under the cursor, its diff and the operations the repository has seen. It runs `jj` for its answers, so it opens any repository and writes nothing. | `moon run --target native examples/mbtjj/src/main` |
| [`dbmux`](dbmux/) | a database client: a table list, an editable grid, a modal SQL editor, a command palette, and one connection per engine (SQLite, PostgreSQL, MySQL, SQL Server, Redis). | `moon run --target native examples/dbmux/src/main -- --demo` |

Each directory has its own README with the keys, the options and what it does
not do.

The library's own demos — one screen each, a package of the library rather than
a program — live in `../src/examples/`; `moon run --target native
src/examples/git/main` is one of them.
