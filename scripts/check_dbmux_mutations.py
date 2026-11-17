#!/usr/bin/env python3
"""Break dbmux's two safety checks one at a time and record which tests notice.

Each mutation is applied to dbmux's sources, the tests of the packages that hold the checks run
on the native backend, and the sources are put back. A mutation names the test that has to go
red, so a suite that goes red for the wrong reason is caught too.

    python3 scripts/check_dbmux_mutations.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "examples" / "dbmux" / "src"
PACKAGES = ["moonbitstack/dbmux/table", "moonbitstack/dbmux/shell"]

# (file, what it says, what it is changed to, what the change is, a test that must go red)
MUTATIONS: list[tuple[str, str, str, str, str]] = [
    (
        "table/plan.mbt",
        "@sqlkit.equal_sql(dialect, column, self.original(row, column).value()),",
        "@sqlkit.equal_sql(dialect, column, self.cell(row, column).value()),",
        "a save matches a keyless row by its edited values instead of the ones it read",
        "a table with no key matches the whole row it read",
    ),
    (
        "shell/state.mbt",
        "if self.read_only && @sqlkit.writes(sql, self.dialect) {",
        "if false && @sqlkit.writes(sql, self.dialect) {",
        "a read-only connection lets a write through",
        "a read-only connection refuses a write and allows a read",
    ),
]


def run() -> tuple[int, list[str]]:
    failed: list[str] = []
    for package in PACKAGES:
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
        failed += [line.split('("')[1].split('")')[0] for line in text.splitlines() if '") failed' in line]
    return len(failed), sorted(set(failed))


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        backup = Path(tmp) / "src"
        shutil.copytree(SRC, backup)
        rows = []
        try:
            clean_count, clean_failed = run()
            if clean_count != 0:
                print("the tree is not green before the mutations:", clean_failed)
                return 1
            for name, old, new, what, expected in MUTATIONS:
                path = SRC / name
                text = path.read_text(encoding="utf-8")
                if old not in text:
                    print(f"!! {name}: the line to break is not there")
                    return 1
                path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")
                count, failed = run()
                shutil.copy2(backup / name, path)
                rows.append((name, what, count, failed, expected))
                print(f"{name}: {what}\n  -> {count} failed: {', '.join(failed) or 'NOTHING'}\n", flush=True)
        finally:
            for name, *_ in MUTATIONS:
                shutil.copy2(backup / name, SRC / name)
    bad = [what for _, what, count, failed, expected in rows if count <= 0 or expected not in failed]
    for what in bad:
        print(f"not caught by the test named for it: {what}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
