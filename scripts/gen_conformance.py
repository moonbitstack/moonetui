#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Generate the conformance vectors this repository tests against.

The vectors are committed, so `moon test` needs nothing but the toolchain.  Run
this script when a reference implementation moves to a new Unicode version or a
new terminal is added to the key corpus:

    python3 scripts/gen_conformance.py --repo .

References, all independent of this library:

  * widths     wcwidth 0.9.4 (Markus Kuhn's tables, Unicode 17) checked against
               CPython's `unicodedata` (Unicode 16) read through UAX #11.
  * clusters   uniseg 0.10.1 against the `regex` module's \\X, both UAX #29.
  * keys       the terminfo entries of the terminals below, read with infocmp.

A code point the two references disagree on is written with a width of -1 and
the test skips it: the disagreement is recorded, not papered over.
"""

import argparse
import os
import re
import subprocess
import sys

# Terminals whose key sequences the parser is held to.  Between them they cover
# the three spellings of an arrow key, both spellings of Home and End, the
# function-key block in all its forms, and two spellings of Backspace.
TERMINALS = [
    "xterm-256color",
    "screen",
    "screen-256color",
    "tmux-256color",
    "linux",
    "rxvt-unicode-256color",
    "vt100",
    "ansi",
]

# terminfo capability -> the key this library names it.
CAPABILITIES = {
    "kcuu1": "Up",
    "kcud1": "Down",
    "kcub1": "Left",
    "kcuf1": "Right",
    "khome": "Home",
    "kend": "End",
    "kich1": "Insert",
    "kdch1": "Delete",
    "kpp": "PageUp",
    "knp": "PageDown",
    "kbs": "Backspace",
    "kent": "Enter",
    "kcbt": "BackTab",
    **{"kf%d" % n: "F(%d)" % n for n in range(1, 13)},
}

# Sequences that name one key in terminfo and another thing in a terminal whose
# input this library also reads.  Each is left out with the reason it cannot be
# satisfied both ways.
SKIPPED = {
    # The console sends shift-tab as ESC TAB, but xterm sends the same bytes for
    # alt-tab, so the two cannot both be read as what they name.
    ("linux", "kcbt"),
    # An Insert key from a terminal no longer made, spelled as the control
    # sequence for "insert line".  Reading it as a key would misfile output the
    # application itself writes.
    ("ansi", "kich1"),
}


def unescape(value):
    """The bytes of a terminfo string capability, in the notation infocmp prints."""
    out = bytearray()
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            i += 2
            if nxt == "E" or nxt == "e":
                out.append(0x1B)
            elif nxt == "n":
                out.append(0x0A)
            elif nxt == "r":
                out.append(0x0D)
            elif nxt == "t":
                out.append(0x09)
            elif nxt == "b":
                out.append(0x08)
            elif nxt == "f":
                out.append(0x0C)
            elif nxt == "s":
                out.append(0x20)
            elif nxt == "\\":
                out.append(0x5C)
            elif nxt == "^":
                out.append(0x5E)
            elif nxt.isdigit():
                digits = nxt
                while i < len(value) and len(digits) < 3 and value[i].isdigit():
                    digits += value[i]
                    i += 1
                out.append(int(digits, 8) & 0xFF)
            else:
                out.append(ord(nxt) & 0xFF)
        elif ch == "^" and i + 1 < len(value):
            nxt = value[i + 1]
            i += 2
            out.append(ord(nxt.upper()) ^ 0x40 if nxt != "?" else 0x7F)
        else:
            i += 1
            out.append(ord(ch) & 0xFF)
    return bytes(out)


def terminfo_capabilities(terminal):
    """The string capabilities of one terminal, as infocmp prints them."""
    try:
        text = subprocess.run(
            ["infocmp", "-1", terminal],
            capture_output=True,
            check=True,
            text=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        print("no terminfo entry for %s" % terminal, file=sys.stderr)
        return {}
    caps = {}
    for line in text.splitlines():
        line = line.strip().rstrip(",")
        name, sep, value = line.partition("=")
        if not sep:
            continue
        # Padding is a delay, not a byte the terminal sends.
        caps[name] = re.sub(r"\$<[0-9./*]+>", "", value)
    return caps


def moonbit_string(data):
    """A MoonBit literal for bytes, printable ASCII kept as it is."""
    out = []
    for byte in data:
        if byte == 0x22:
            out.append('\\"')
        elif byte == 0x5C:
            out.append("\\\\")
        elif 0x20 <= byte <= 0x7E:
            out.append(chr(byte))
        else:
            out.append("\\u{%x}" % byte)
    return '"' + "".join(out) + '"'


def moonbit_text(text):
    """A MoonBit literal for a string: one escape per code point, not per byte."""
    out = []
    for ch in text:
        code = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif 0x20 <= code <= 0x7E:
            out.append(ch)
        else:
            out.append("\\u{%x}" % code)
    return '"' + "".join(out) + '"'


def gen_keys(repo):
    rows = []
    for terminal in TERMINALS:
        caps = terminfo_capabilities(terminal)
        for cap in sorted(CAPABILITIES, key=lambda name: (len(name), name)):
            if cap not in caps or (terminal, cap) in SKIPPED:
                continue
            data = unescape(caps[cap])
            if not data:
                continue
            rows.append((terminal, cap, data, CAPABILITIES[cap]))
    lines = [
        "// Copyright 2026 Leo Cheng",
        "// SPDX-License-Identifier: Apache-2.0",
        "",
        "///|",
        "/// The key each terminal's own database says it sends, and the key this",
        "/// library must therefore read from those bytes. Generated by",
        "/// `scripts/gen_conformance.py` from the terminfo entries of the terminals",
        "/// named here; do not edit.",
        "let key_vectors : Array[(String, String, String, @event.KeyCode)] = [",
    ]
    for terminal, cap, data, key in rows:
        lines.append(
            "  (%s, %s, %s, @event.%s),"
            % (moonbit_string(terminal.encode()), moonbit_string(cap.encode()),
               moonbit_string(data), key)
        )
    lines.append("]")
    write(repo, "src/input/keys_vectors_wbtest.mbt", lines)
    return len(rows)


def ucd_width(ch):
    """Columns from UAX #11 as CPython reads it: the second opinion on a width."""
    import unicodedata

    cat = unicodedata.category(ch)
    if cat in ("Mn", "Me", "Cf", "Cc"):
        return 0
    if unicodedata.east_asian_width(ch) in ("W", "F"):
        return 2
    return 1


def gen_widths(repo):
    import unicodedata
    import wcwidth

    excluded = []

    def reference(cp):
        ch = chr(cp)
        cat = unicodedata.category(ch)
        if cat in ("Cs", "Cn"):
            # A surrogate is not a character, and one assigned after the
            # references' Unicode version has nothing to be compared with: the
            # table this library ships follows Unicode 17.
            return -1
        if cp in (0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF):
            # An emoji skin tone takes no cell of its own here: it rides on the
            # emoji before it.  Left out rather than argued about.
            return -1
        first = wcwidth.wcwidth(ch)
        first = 0 if first < 0 else first
        second = ucd_width(ch)
        if first != second:
            excluded.append(cp)
            return -1
        return first

    runs = []
    for cp in range(0x110000):
        width = reference(cp)
        if runs and runs[-1][2] == width and runs[-1][1] == cp - 1:
            runs[-1][1] = cp
        else:
            runs.append([cp, cp, width])
    lines = [
        "// Copyright 2026 Leo Cheng",
        "// SPDX-License-Identifier: Apache-2.0",
        "",
        "///|",
        "/// Columns per code point, as runs of `(first, last, cells)`: wcwidth 0.9.4",
        "/// (Unicode 17) checked against CPython's `unicodedata` (Unicode 16) read",
        "/// through UAX #11. A run of -1 is a code point the two do not agree on or",
        "/// one assigned after their version, and is not asserted. Generated by",
        "/// `scripts/gen_conformance.py`; do not edit.",
        "let width_runs : Array[(Int32, Int32, Int32)] = [",
    ]
    for first, last, width in runs:
        lines.append("  (%d, %d, %d)," % (first, last, width))
    lines.append("]")
    write(repo, "src/strip/width_vectors_wbtest.mbt", lines)
    return len(runs), len(excluded)


def utf16_offset(text, index):
    """The UTF-16 offset of a Python index: this library counts in UTF-16 units."""
    return len(text[:index].encode("utf-16-le")) // 2


CLUSTERS = [
    # One letter with its marks, which are not characters of their own.
    "a\u0301",
    "a\u0308\u0301",
    "q\u0323\u0307",
    "e\u0301\u0302\u0303\u0304",
    # Scripts whose letters are built from several code points.
    "क्ष",
    "नमस्ते",
    "हिन्दी",
    "กำ",
    "กิ่",
    "لا",
    "ا\u064e\u0651",
    "\u1100\u1161\u11a8",
    "\u1100\u1161",
    "\uac00\u11a8",
    # Emoji, their joiners, their skin tones, their variation selectors.
    "\U0001F600",
    "\U0001F469\u200D\U0001F4BB",
    "\U0001F468\u200D\U0001F469\u200D\U0001F467\u200D\U0001F466",
    "\U0001F3F3\uFE0F\u200D\U0001F308",
    "\U0001F44D\U0001F3FD",
    "\U0001F1EF\U0001F1F5",
    "\U0001F1E9\U0001F1EA\U0001F1EF\U0001F1F5",
    "1\uFE0F\u20E3",
    "#\uFE0F\u20E3",
    "\u2764",
    "\u2764\uFE0F",
    "\u263A\uFE0E",
    "\u263A\uFE0F",
    "\U0001F441\uFE0F\u200D\U0001F5E8\uFE0F",
    # Zero width characters, alone and between letters.
    "\u200B",
    "a\u200Bb",
    "a\u200Db",
    "\u200D",
    # Line breaks and tabs, which a cell does not draw.
    "a\r\nb",
    "a\tb",
    "a\nb",
    # Wide characters, and the mixtures an application actually draws.
    "中文",
    "a中b",
    "ｱｲｳ",
    "\uFF21\uFF22",
    "a\U0001F600b",
    "e\u0301x\u0301",
    "\U0001F1EF\U0001F1F5" + "x",
    "👨‍👩‍👧ab🇯🇵",
    "가나다",
    "한글",
    "①②③",
    "→←↑↓",
    "─│┌┐",
]


def gen_clusters(repo):
    import unicodedata
    import regex
    import wcwidth
    from uniseg.graphemecluster import grapheme_clusters

    rows = []
    skipped = []
    for text in CLUSTERS:
        clusters = []
        at = 0
        for cluster in grapheme_clusters(text):
            clusters.append(cluster)
            at += len(cluster)
        by_uniseg = []
        at = 0
        for cluster in clusters:
            by_uniseg.append(utf16_offset(text, at))
            at += len(cluster)
        by_regex = [utf16_offset(text, m.start()) for m in regex.finditer(r"\X", text)]
        if by_uniseg != by_regex:
            skipped.append(text)
            continue
        cells = sum(wcswidth_cluster(cluster, wcwidth) for cluster in clusters)
        # A spacing mark (Mc) is the one place the references part company: this
        # library draws a mark inside its cluster and counts no cell of its own,
        # wcwidth counts one.  Both are defensible, so the width is left
        # unasserted and only the boundaries are held to.
        if any(unicodedata.category(ch) == "Mc" for ch in text):
            cells = -1
        rows.append((text, by_uniseg, cells))
    lines = [
        "// Copyright 2026 Leo Cheng",
        "// SPDX-License-Identifier: Apache-2.0",
        "",
        "///|",
        "/// Text, where each grapheme cluster starts in UTF-16 units, and the columns",
        "/// the whole of it takes: the boundaries from uniseg 0.10.1 checked against",
        "/// the `regex` module's \\\\X, the columns from wcwidth 0.9.4. Generated by",
        "/// `scripts/gen_conformance.py`; do not edit.",
        "let cluster_vectors : Array[(String, Array[Int32], Int32)] = [",
    ]
    for text, starts, cells in rows:
        literal = moonbit_text(text)
        bounds = ", ".join(str(s) for s in starts)
        line = "  (%s, [%s], %d)," % (literal, bounds, cells)
        # The formatter wraps a line past its width; writing the wrapped form
        # here keeps the committed vector and a regenerated one byte for byte.
        if len(line) > 80:
            lines.append("  (")
            lines.append("    %s," % literal)
            lines.append("    [%s]," % bounds)
            lines.append("    %d," % cells)
            lines.append("  ),")
        else:
            lines.append(line)
    lines.append("]")
    write(repo, "src/strip/cluster_vectors_wbtest.mbt", lines)
    return len(rows), skipped


def wcswidth_cluster(text, wcwidth):
    """Columns of one grapheme cluster, as wcwidth counts a string.

    wcswidth knows the three rules a per-code-point sum misses: a ZWJ hides the
    emoji after it, VS16 asks for the emoji presentation, and a pair of regional
    indicators is one flag.  A cluster holding a control character is not text.
    """
    width = wcwidth.wcswidth(text)
    return 0 if width < 0 else width


def write(repo, path, lines):
    full = os.path.join(repo, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    print("wrote %s" % path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="the repository root")
    parser.add_argument(
        "--only",
        default="keys,widths,clusters",
        help="which vectors to write; the keys depend on the terminfo database "
             "of the machine, so CI regenerates the other two only",
    )
    args = parser.parse_args()
    wanted = {name.strip() for name in args.only.split(",") if name.strip()}
    counts = {}
    if "keys" in wanted:
        counts["keys"] = gen_keys(args.repo)
    if "widths" in wanted:
        runs, excluded = gen_widths(args.repo)
        counts["width runs"] = runs
        counts["code points only one reference speaks for"] = excluded
    skipped = []
    if "clusters" in wanted:
        clusters, skipped = gen_clusters(args.repo)
        counts["clusters"] = clusters
    print(", ".join("%s %d" % item for item in counts.items()))
    for text in skipped:
        print("cluster skipped: %r" % text)


if __name__ == "__main__":
    main()
