# dbmux

A terminal database client built on [moonetui](../README.md): one window over
PostgreSQL, MySQL, SQLite, SQL Server and Redis, with editable tables, a SQL
editor, and a command palette.

This module sits beside the library, not inside it: `moonetui`'s own
`moon.mod` does not depend on a database driver, and this directory can be
moved out of the repository without changing the library.

## What is here

| Package | What it does |
|:--|:--|
| `config` | `connections.toml`: one `[[connection]]` per database, with a name, a group, an engine, a DSN, `read_only` and `production` |
| `sqlkit` | Identifier quoting per dialect, statement splitting, `danger()`, and the SELECT/UPDATE/INSERT/DELETE that a table page and a save run |
| `table` | A page of rows, what the reader changed, and the statements a save runs — updated rows carry their old values in the WHERE |
| `export` | CSV (RFC 4180) and JSON of a page |
| `keymap` | Every action, its default key, and a TOML file that rebinds them |
| `db` | One live connection per engine, DSN parsing, and the catalog queries each engine answers its own way |
| `shell` | The state machine: what a key does, what it refuses, and the commands the host has to run |
| `db` also holds `Redis` | keys by `SCAN`, one key as a table by its type, and a console that flattens any reply into rows |
| `ui` | The window: a table list, one or two panes with a tab strip each, the modal editor, and the dialogs drawn over it |
| `main` | The entry point: arguments, a connection, a catalog, and the frame loop |

The split is deliberate: everything above `db` is a pure function of data, so
the behaviour that matters — a read-only connection refusing a write, a save
that names the row it read, a filter that quotes its value — is tested without
a database.

## Run it

```
moon run --target native src/main -- --demo
moon run --target native src/main -- ./app.db
moon run --target native src/main -- parts        # a name from connections.toml
moon run --target native src/main -- "redis://127.0.0.1:6379/0"   # Redis keys
moon run --target native src/main -- "postgres://me@127.0.0.1/app?sslmode=disable"
```

A Redis key is a table too, shaped by the type it holds, and a save writes it:
a changed hash field is one `HSET`, a marked one `HDEL`, a string is `SET`, and a
list, a set or a sorted set has no cell to set — the client says so and leaves
those to the console.

Redis opens on the keys: `keys` is a table of every key and its type, `enter`
opens the one under the cursor as a table of its own — a string is one row, a
hash two columns, a list its indexes, a set its members, a sorted set its
scores — and `C-r` in the editor sends any command the way `redis-cli` would.
Redis values are read-only here; the console is how you change one.

The connection file is `./connections.toml`, or the file `DBMUX_CONFIG` names,
or `--config <path>`. A target that is neither a URL nor a file is looked up
by name in it.

`--demo` builds a SQLite database in memory with three tables, so there is
something to page through with no server and no file. Add `--table orders` to
open one table first, `--where "total > 10"` to start filtered, and
`--headless --frames 3` to draw into a buffer instead of a terminal — that is
how CI checks the screen without a tty.

## Configuration

```toml
[[connection]]
name = "local"
engine = "sqlite"
dsn = "./app.db"

[[connection]]
name = "app"
group = "staging"
engine = "postgresql"
dsn = "postgres://app@127.0.0.1:5432/app?sslmode=disable"
password_env = "APP_PASSWORD"
read_only = true
```

A password is taken from `password_env` when it is set, and from the DSN when it
is not: `postgres://app:secret@127.0.0.1:5432/app` connects with `secret`, which is
what makes a URL copied from another client work.

A production connection is read-only unless the file says `read_only = false`,
and every write on it is confirmed.

## Keys

| Key | Does |
|:--|:--|
| `j` / `k` | down / up |
| `enter` | open the table under the cursor |
| `s` | sort by the column under the cursor, through ascending, descending and off |
| `f` | type a WHERE |
| `F` | filter by the cell under the cursor |
| `e` | edit the cell; on a Redis hash, the field's value, and on a string, the key's |
| `a` / `d` | add a row / mark one for deletion (on a Redis hash, `d` marks the field for `HDEL`) |
| `C-s` | save: the statements are shown, then run in one transaction |
| `r` | take the changes back |
| `t` / `c` | transpose / hide the column under the cursor |
| `C` | pick the columns shown, by name, on the prompt line |
| `L` | rows per page, 1 to 10000 |
| `x` / `X` | export CSV / JSON |
| `C-p` | the command palette |
| `?` | the keys that work here |
| `gt` / `gT` | next / previous tab in this pane |
| `C-v` / `C-x` | split right / split down (the same table on both sides) |
| `C-o` | hand the keyboard to the other pane |
| `C-q` | close the split |
| `C-r` | run the editor's SQL |
| `C-n` | in the editor, complete the word at the cursor: tables, columns, and SQL's own words |
| `C-up` / `C-down` | in the editor, the queries run before, newest first |
| `q` | quit |

A completion is offered for the word the cursor is at the end of — the tables the
connection lists, the columns of the table that is open, and the words a query is
written with. `C-n` and `C-p` walk the list, `enter` or `tab` takes the one that is
chosen, and any other key closes the list and does its own work.

The queries the editor runs are kept in `.dbmux_history` in the home directory, the file
`DBMUX_HISTORY` names, or `--history <path>`: the newest 500, one block each.

The keys can be rebound in `./keymaps.toml`, the file `DBMUX_KEYMAP` names, or `--keymap
<path>`. Each line under `[keys]` binds an action, by the name the help panel shows, to one key;
the key it had before is let go, and a name no action has stops dbmux with a message:

```toml
[keys]
save = "C-w"
columns = "h"
```

A keymap file rebinds any of them by action name:

```toml
[keys]
save = "C-w"
filter = "/"
```

## Safety

- A read-only connection refuses any script that writes, before it is sent.
- `DELETE` and `UPDATE` with no WHERE of their own, `TRUNCATE`, `DROP`, a
  dropped column and SQL Server's `EXEC` ask first.
- A save is one transaction. Each UPDATE carries the values the row had when it
  was read, so a row someone else changed matches nothing, and the whole save
  rolls back and names it.
- The save preview lists the statements with their values inlined, and the
  counts of changed, added and deleted rows.

## Status

What runs today: a SQLite file or an in-memory demo, opened in a terminal, with
the table list, one or two panes split side by side or one above the other,
a tab strip per pane, the grid, cell edits and the save preview, the modal SQL
editor, the palette, the key panel, and CSV and JSON export. PostgreSQL, MySQL
and SQL Server are wired to their drivers through the same `Session`; their
integration tests need servers, so they run in CI rather than on a laptop.

Not built yet: editing Redis values (the console writes), completion and query
history, and a connection form. The delivery note in the repository's
last commit lists them in the order they come next.
