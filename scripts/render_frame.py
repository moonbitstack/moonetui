#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Render an interop frame, or a grid of them, to a PNG.

The frame tests announce each frame as

    interop<TAB>name<TAB>terminals<TAB>w<TAB>h<TAB>hex16 stream<TAB>hex16 row...

where the stream is the escape sequence a terminal would have been given, and
every row is the text of that row. This script replays the stream through a
small SGR machine to recover the colour of every cell, then draws the grid with
Pillow. One frame makes one image; several make a labelled collage.

    MOONETUI_INTEROP=1 moon test --target native -p moonbitstack/moonetui/examples/cards \\
      | grep '^interop' | python scripts/render_frame.py --pick cards/01 --out cards.png

    python scripts/render_frame.py --in frames.txt --examples cards,board,logs \\
      --out docs/assets/examples.png --cols 2
"""

from __future__ import annotations

import argparse
import binascii
import sys
import unicodedata

from PIL import Image, ImageDraw, ImageFont

# The sixteen names, the six-by-six cube, and the greys: what a terminal gives
# SGR 30–37, 90–97 and 38;5;n.
BASIC = [
    (0x1A, 0x1B, 0x26),
    (0xF7, 0x76, 0x8E),
    (0x9E, 0xCE, 0x6A),
    (0xE0, 0xAF, 0x68),
    (0x7A, 0xA2, 0xF7),
    (0xBB, 0x9A, 0xF7),
    (0x7D, 0xCF, 0xFF),
    (0xC0, 0xCA, 0xF5),
]
BRIGHT = [
    (0x56, 0x5F, 0x89),
    (0xFF, 0x8A, 0x9C),
    (0xB6, 0xE3, 0x84),
    (0xF5, 0xC8, 0x86),
    (0x9A, 0xBC, 0xFF),
    (0xD3, 0xBC, 0xFF),
    (0xA4, 0xE4, 0xFF),
    (0xF2, 0xF5, 0xFF),
]


def cube256(n: int) -> tuple[int, int, int]:
    if n < 16:
        return (BASIC + BRIGHT)[n]
    if n < 232:
        n -= 16
        steps = [0, 95, 135, 175, 215, 255]
        return (steps[n // 36], steps[n // 6 % 6], steps[n % 6])
    level = 8 + (n - 232) * 10
    return (level, level, level)


class Cell:
    __slots__ = ("ch", "fg", "bg", "bold")

    def __init__(self) -> None:
        self.ch = " "
        self.fg = None
        self.bg = None
        self.bold = False


def replay(stream: str, width: int, height: int) -> list[list[Cell]]:
    grid = [[Cell() for _ in range(width)] for _ in range(height)]
    fg = None
    bg = None
    bold = False
    row = 0
    col = 0
    i = 0
    n = len(stream)
    while i < n:
        ch = stream[i]
        if ch == "\x1b" and i + 1 < n and stream[i + 1] == "[":
            j = i + 2
            while j < n and not ("@" <= stream[j] <= "~"):
                j += 1
            if j >= n:
                break
            body = stream[i + 2 : j]
            final = stream[j]
            private = body.startswith("?")
            if private:
                body = body[1:]
            params = [int(p) if p else 0 for p in body.split(";")] if body else []
            if final == "H" or final == "f":
                row = (params[0] if params else 1) - 1
                col = (params[1] if len(params) > 1 else 1) - 1
            elif final == "m":
                k = 0
                while k < len(params):
                    p = params[k]
                    if p == 0:
                        fg = bg = None
                        bold = False
                    elif p == 1:
                        bold = True
                    elif p == 22:
                        bold = False
                    elif 30 <= p <= 37:
                        fg = BASIC[p - 30]
                    elif 90 <= p <= 97:
                        fg = BRIGHT[p - 90]
                    elif 40 <= p <= 47:
                        bg = BASIC[p - 40]
                    elif 100 <= p <= 107:
                        bg = BRIGHT[p - 100]
                    elif p == 39:
                        fg = None
                    elif p == 49:
                        bg = None
                    elif p in (38, 48) and k + 1 < len(params):
                        if params[k + 1] == 2 and k + 4 < len(params):
                            value = (
                                params[k + 2] & 0xFF,
                                params[k + 3] & 0xFF,
                                params[k + 4] & 0xFF,
                            )
                            k += 4
                        elif params[k + 1] == 5 and k + 2 < len(params):
                            value = cube256(params[k + 2])
                            k += 2
                        else:
                            value = None
                        if value is not None:
                            if p == 38:
                                fg = value
                            else:
                                bg = value
                    k += 1
            i = j + 1
            continue
        if ch == "\n":
            row += 1
            col = 0
        elif ch == "\r":
            col = 0
        elif ch >= " ":
            # A wide character takes two cells, as a terminal gives it; the second
            # keeps the colours and draws nothing of its own.
            span = 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
            for k in range(span):
                if 0 <= row < height and 0 <= col + k < width:
                    cell = grid[row][col + k]
                    cell.ch = ch if k == 0 else ""
                    cell.fg = fg
                    cell.bg = bg
                    cell.bold = bold
            col += span
        i += 1
    return grid


def frame_rows(parts: list[str]) -> list[str]:
    return [binascii.unhexlify(p).decode("utf-16-be") for p in parts]


def parse_frames(text: str) -> list[dict]:
    frames = []
    for line in text.splitlines():
        if not line.startswith("interop\t"):
            continue
        parts = line.split("\t")
        stream = binascii.unhexlify(parts[5]).decode("utf-16-be")
        frames.append(
            {
                "name": parts[1],
                "width": int(parts[3]),
                "height": int(parts[4]),
                "stream": stream,
                "rows": frame_rows(parts[6:]),
            }
        )
    return frames


# DejaVu first: it is the only common monospace that has the lower blocks
# (`▁▂`), the rings (`◉`) and the sparkles (`✦`) as well as the box drawing.
# Its bold face has no box drawing, blocks or rings, so a bold cell is drawn in
# the bold face when the glyph is a letter or a digit and in the plain face when
# it is a rule, a bar or a mark: stroking the plain face fattens every glyph by
# a pixel, which runs a heading into the rule drawn in the cell beside it.
FONTS = [
    "C:/Windows/Fonts/DejaVuSansMono_0.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "C:/Windows/Fonts/CascadiaMono.ttf",
    "C:/Windows/Fonts/consola.ttf",
    "/System/Library/Fonts/Menlo.ttc",
]

# Wide characters, which the monospace faces above do not carry.
WIDE_FONTS = [
    "C:/Windows/Fonts/msyh.ttc",
    "C:/Windows/Fonts/simhei.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    "/System/Library/Fonts/PingFang.ttc",
]

BOLD_FONTS = [
    "C:/Windows/Fonts/DejaVuSansMono-Bold_0.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
    "C:/Windows/Fonts/CascadiaMono-Bold.ttf",
    "C:/Windows/Fonts/consolab.ttf",
    "/System/Library/Fonts/Menlo.ttc",
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for path in BOLD_FONTS if bold else FONTS:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    if bold:
        return load_font(size)
    raise SystemExit("no monospace font found")


def load_wide(size: int) -> ImageFont.FreeTypeFont | None:
    for path in WIDE_FONTS:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return None


def block(ch: str, px: int, py: int, w: int, h: int) -> list[int] | None:
    """The rectangle a block element covers: a terminal fills the whole cell
    with these, where a font's glyph stops short of the line height."""
    code = ord(ch[0])
    if 0x2581 <= code <= 0x2588:
        top = py + h - round(h * (code - 0x2580) / 8)
        return [px, top, px + w - 1, py + h - 1]
    if code == 0x2580:
        return [px, py, px + w - 1, py + h // 2 - 1]
    if 0x2589 <= code <= 0x258F:
        right = px + round(w * (0x2590 - code) / 8)
        return [px, py, right - 1, py + h - 1]
    if code == 0x2590:
        return [px + w // 2, py, px + w - 1, py + h - 1]
    return None


def in_bold_face(ch: str) -> bool:
    """Whether the bold face draws this glyph: letters and digits, not rules."""
    code = ord(ch[0])
    return code < 0x2000 and not 0x2190 <= code <= 0x21FF


def draw_frame(frame: dict, size: int = 17, pad: int = 10, label: str = "") -> Image.Image:
    font = load_font(size)
    heavy = load_font(size, bold=True)
    wide = load_wide(size)
    cell_w = round(font.getlength("M"))
    cell_h = round(size * 1.34)
    width, height = frame["width"], frame["height"]
    grid = replay(frame["stream"], width, height)
    label_h = 22 if label else 0
    image = Image.new(
        "RGB",
        (width * cell_w + pad * 2, height * cell_h + pad * 2 + label_h),
        (0x0B, 0x0E, 0x14),
    )
    draw = ImageDraw.Draw(image)
    if label:
        draw.text((pad, 4), label, font=load_font(14), fill=(0x7C, 0x88, 0xA8))
    top = pad + label_h
    for y in range(height):
        for x in range(width):
            cell = grid[y][x]
            px = pad + x * cell_w
            py = top + y * cell_h
            if cell.bg:
                draw.rectangle(
                    [px, py, px + cell_w - 1, py + cell_h - 1], fill=cell.bg
                )
            if cell.ch in (" ", ""):
                continue
            fill = cell.fg or (0xC0, 0xCA, 0xF5)
            face = heavy if cell.bold and in_bold_face(cell.ch) else font
            if wide is not None and unicodedata.east_asian_width(cell.ch) in ("W", "F"):
                face = wide
            box = block(cell.ch, px, py, cell_w, cell_h)
            if box is not None:
                draw.rectangle(box, fill=fill)
                continue
            draw.text((px, py), cell.ch, font=face, fill=fill)
    return image


def collage(images: list[Image.Image], cols: int, gap: int = 10) -> Image.Image:
    rows = (len(images) + cols - 1) // cols
    cell_w = max(i.width for i in images)
    cell_h = max(i.height for i in images)
    out = Image.new(
        "RGB",
        (cols * cell_w + (cols - 1) * gap, rows * cell_h + (rows - 1) * gap),
        (0x05, 0x07, 0x0A),
    )
    for index, image in enumerate(images):
        x = (index % cols) * (cell_w + gap)
        y = (index // cols) * (cell_h + gap)
        out.paste(image, (x, y))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--in", dest="source", help="file of interop lines (default: stdin)")
    parser.add_argument("--pick", help="the frame whose name holds this")
    parser.add_argument(
        "--examples",
        help="comma separated package names; the first frame of each is taken",
    )
    parser.add_argument("--cols", type=int, default=2, help="columns in a collage")
    parser.add_argument("--size", type=int, default=17, help="font size")
    parser.add_argument("--out", required=True, help="the PNG to write")
    args = parser.parse_args()

    text = open(args.source, encoding="utf-8").read() if args.source else sys.stdin.read()
    frames = parse_frames(text)
    if not frames:
        raise SystemExit("no interop frames in the input")

    picked = []
    if args.examples:
        for name in args.examples.split(","):
            name = name.strip()
            for frame in frames:
                if frame["name"].split("/")[0] == name:
                    picked.append(frame)
                    break
            else:
                raise SystemExit(f"no frame for {name}")
    elif args.pick:
        picked = [f for f in frames if args.pick in f["name"]]
        if not picked:
            raise SystemExit(f"no frame named {args.pick}")
    else:
        picked = [frames[0]]

    images = [
        draw_frame(frame, size=args.size, label=frame["name"] if len(picked) > 1 else "")
        for frame in picked
    ]
    image = images[0] if len(images) == 1 else collage(images, args.cols)
    image.save(args.out)
    print(f"{args.out}: {image.width}x{image.height}, {len(images)} frame(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
