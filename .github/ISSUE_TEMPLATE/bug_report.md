---
name: Bug report
about: Something does not work as documented.
title: "bug: "
labels: bug
---

<!-- Sections marked (required) must be filled in. -->

**Version** (required)

<!-- For example: moonbitstack/moonetui 0.1.0 -->

**Toolchain** (required)

<!-- Output of `moon version --all` -->

**Driver** (required)

- [ ] node
- [ ] posix (termios)
- [ ] win32 (console)
- [ ] web (canvas grid)
- [ ] headless

**Terminal**

<!-- Emulator and version, the TERM variable, and the size in columns by rows.
     Skip for the web and headless drivers. -->

**Steps to reproduce** (required)

**Expected and actual behavior** (required)

<!-- For a rendering bug, the headless driver writes the escape sequences to a
     buffer; pasting that output pins down what was actually emitted. -->

- [ ] Logs and code in this issue contain no credentials or private data.
