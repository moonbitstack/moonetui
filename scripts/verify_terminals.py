#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Draw this library's frames in two terminal emulators and compare the screens.

`moon test` prints one `interop` line per frame: the name, the bytes the library
wrote, and the rows the application meant to show, all in UTF-16 hex.  This
script hands the same bytes to

  * pyte 0.8.2, a terminal emulator in Python, and
  * tmux, a terminal multiplexer in C that a great many people use daily,

and fails if either draws something other than those rows.  Neither has any part
in this library, so agreement is evidence that the bytes are what ECMA-48 says
they are.

    moon test --target native -p moonbitstack/moonetui/app 2>&1 \\
        | grep '^interop' > /tmp/frames.txt
    python3 scripts/verify_terminals.py --in /tmp/frames.txt
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile


def decode(hexed):
    # The test writes each UTF-16 unit most significant nibble first.
    return bytes.fromhex(hexed).decode("utf-16-be")


def read_frames(path):
    frames = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line.startswith("interop\t"):
                continue
            parts = line.split("\t")
            name = parts[1]
            engines = parts[2].split(",")
            width = int(parts[3])
            height = int(parts[4])
            stream = decode(parts[5])
            rows = [decode(cell) for cell in parts[6:]]
            frames.append((name, engines, width, height, stream, rows))
    return frames


def draw_with_pyte(stream, width, height):
    import pyte

    screen = pyte.Screen(width, height)
    stream_reader = pyte.Stream(screen)
    stream_reader.feed(stream)
    return list(screen.display)


def draw_with_tmux(stream, width, height, directory):
    payload = os.path.join(directory, "frame.bin")
    with open(payload, "wb") as handle:
        handle.write(stream.encode("utf-8"))
    socket = "moonetui-conformance"
    subprocess.run(["tmux", "-L", socket, "kill-server"], capture_output=True)
    try:
        subprocess.run(
            ["tmux", "-L", socket, "-f", "/dev/null", "new-session", "-d",
             "-x", str(width), "-y", str(height), "-s", "frame",
             "cat %s; sleep 0.2" % payload],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["tmux", "-L", socket, "set-option", "-t", "frame", "remain-on-exit", "on"],
            check=True, capture_output=True,
        )
        # The pane holds the screen the bytes drew; wait for the writer to finish
        # rather than for a fixed time.
        for _ in range(50):
            out = subprocess.run(
                ["tmux", "-L", socket, "capture-pane", "-p", "-t", "frame"],
                capture_output=True, text=True, check=True,
            ).stdout
            if out.strip():
                break
            subprocess.run(["sleep", "0.1"], check=True)
        return out.rstrip("\n").split("\n")
    finally:
        subprocess.run(["tmux", "-L", socket, "kill-server"], capture_output=True)


def normalize(text):
    import unicodedata

    return unicodedata.normalize("NFC", text)


def compare(kind, name, got, want):
    failures = []
    for index, want_row in enumerate(want):
        got_row = got[index] if index < len(got) else ""
        # An emulator may hold a precomposed letter where the frame wrote one
        # with its mark: the same glyph, so the same frame.
        if normalize(got_row.rstrip()) != normalize(want_row.rstrip()):
            failures.append(
                "%s: %s row %d\n  want %r\n  got  %r"
                % (kind, name, index, want_row.rstrip(), got_row.rstrip())
            )
    for index in range(len(want), len(got)):
        if got[index].strip():
            failures.append("%s: %s row %d has text beyond the frame: %r"
                            % (kind, name, index, got[index].rstrip()))
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--in", dest="source", required=True,
                        help="the file holding the interop lines")
    args = parser.parse_args()

    frames = read_frames(args.source)
    if not frames:
        print("no interop lines in %s" % args.source, file=sys.stderr)
        return 2

    have_tmux = shutil.which("tmux") is not None
    failures = []
    with tempfile.TemporaryDirectory(prefix="moonetui-conformance-") as directory:
        for name, engines, width, height, stream, rows in frames:
            if "pyte" in engines:
                by_pyte = draw_with_pyte(stream, width, height)
                failures += compare("pyte", name, by_pyte, rows)
            if "tmux" in engines and have_tmux:
                by_tmux = draw_with_tmux(stream, width, height, directory)
                failures += compare("tmux", name, by_tmux, rows)
            elif "tmux" in engines:
                print("tmux not found; %s is unchecked" % name, file=sys.stderr)

    for failure in failures:
        print(failure)
    print("%d frames, %d disagreements" % (len(frames), len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
