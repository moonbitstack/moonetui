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
| `app` | The state machine: what a key does, what it refuses, and the commands the host has to run |

The split is deliberate: everything above `db` is a pure function of data, so
the behaviour that matters — a read-only connection refusing a write, a save
that names the row it read, a filter that quotes its value — is tested without
a database.

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
| `e` | edit the cell |
| `a` / `d` | add a row / mark one for deletion |
| `C-s` | save: the statements are shown, then run in one transaction |
| `r` | take the changes back |
| `t` / `c` | transpose / hide the column under the cursor |
| `x` / `X` | export CSV / JSON |
| `C-p` | the command palette |
| `?` | the keys that work here |
| `gt` / `gT` | next / previous tab |

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

The logic packages and the connection layer are complete and tested
(`moon test --target native` in this directory). The terminal shell that binds
them to moonetui's widget tree, the Redis key browser, and the split panes are
the remaining work; the delivery note in the repository's last commit lists
them.
