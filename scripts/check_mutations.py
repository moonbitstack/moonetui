#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Break one check at a time and record which test notices.

Each mutation is written into the sources, the tests of the package that holds the check run on
the native backend, and the file is put back exactly as it was. A mutation names the test that
has to go red, so a suite that goes red for the wrong reason is caught too.

    python3 scripts/check_mutations.py
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DBMUX = ROOT / "examples" / "dbmux" / "src"

# (package, file, what it says, what it is changed to, what the change is, a test that must go red)
MUTATIONS: list[tuple[str, Path, str, str, str, str]] = [
    (
        "moonbitstack/moonetui/design",
        ROOT / "src" / "design" / "theme.mbt",
        "  muted=@style.Colour::rgb(0x8B, 0x96, 0xAB),",
        "  muted=@style.Colour::rgb(0x8B, 0x96, 0xAC),",
        "a role of the house look is mapped to a colour one step off",
        "the house look is these twelve colours and no others",
    ),
    (
        "moonbitstack/dbmux/db",
        DBMUX / "db" / "redis.mbt",
        "  let pattern = filter.trim().to_owned()",
        '  let pattern = "*"',
        "the key list ignores the pattern the reader typed",
        "the keys are asked for by the pattern the reader typed",
    ),
    (
        "moonbitstack/dbmux/table",
        DBMUX / "table" / "plan.mbt",
        "@sqlkit.equal_sql(dialect, column, self.original(row, column).value()),",
        "@sqlkit.equal_sql(dialect, column, self.cell(row, column).value()),",
        "a save matches a keyless row by its edited values instead of the ones it read",
        "a table with no key matches the whole row it read",
    ),
    (
        "moonbitstack/dbmux/shell",
        DBMUX / "shell" / "state.mbt",
        "if self.read_only && @sqlkit.writes(sql, self.dialect) {",
        "if false && @sqlkit.writes(sql, self.dialect) {",
        "a read-only connection lets a write through",
        "a read-only connection refuses a write and allows a read",
    ),
]


def run(package: str) -> tuple[int, list[str]]:
    out = subprocess.run(
        ["moon", "test", "--target", "native", "-p", package],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    text = out.stdout + out.stderr
    if "Total tests:" not in text:
        return -1, ["the mutated sources did not build"]
    failed = [
        line.split('("')[1].split('")')[0]
        for line in text.splitlines()
        if '") failed' in line
    ]
    return len(failed), sorted(set(failed))


def main() -> int:
    rows = []
    for package in sorted({m[0] for m in MUTATIONS}):
        count, failed = run(package)
        if count != 0:
            print(f"{package} is not green before the mutations: {failed}")
            return 1
    for package, path, old, new, what, expected in MUTATIONS:
        original = path.read_text(encoding="utf-8")
        if old not in original:
            print(f"!! {path}: the line to break is not there")
            return 1
        path.write_text(original.replace(old, new, 1), encoding="utf-8", newline="\n")
        try:
            count, failed = run(package)
        finally:
            path.write_text(original, encoding="utf-8", newline="\n")
        rows.append((what, count, failed, expected))
        print(
            f"{path.name}: {what}\n  -> {count} failed: {', '.join(failed) or 'NOTHING'}\n",
            flush=True,
        )
    bad = [what for what, count, failed, expected in rows if count <= 0 or expected not in failed]
    for what in bad:
        print(f"not caught by the test named for it: {what}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
