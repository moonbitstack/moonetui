"""Fill the demo cards of docs/index.html from src/examples/showcase.

Every card is a canvas the page runs the demo on, the line its widgets report
on, and the demo's whole source. The source is read from the showcase files, so
the code beside a demo is always the code that runs.

Usage: python scripts/gen_docs.py
"""

import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOWCASE = ROOT / "src" / "examples" / "showcase"
PAGE = ROOT / "docs" / "index.html"

# Cell height in CSS pixels at the 14px font the cards use: 14 × 1.25, rounded.
CELL = 18

KEYWORDS = {
    "let", "mut", "fn", "pub", "if", "else", "match", "for", "in", "while",
    "return", "guard", "is", "true", "false", "struct", "enum", "impl", "with",
}
TOKEN = re.compile(
    r'(?P<cm>//[^\n]*)|(?P<st>"(?:\\.|[^"\\])*")|(?P<pk>@[a-z_/]+\.)'
    r"|(?P<id>[A-Za-z_][A-Za-z0-9_]*)|(?P<other>.)",
    re.S,
)

TITLES = {
    "Text": "Text and display",
    "Entry": "Entry and logs",
    "Choice": "Choices",
    "Navigation": "Navigation and structure",
    "Data": "Data and notices",
    "Style": "Seen live",
}


def find(pattern: str, text: str, flags: int = 0) -> re.Match:
    m = re.search(pattern, text, flags)
    if m is None:
        raise SystemExit(f"no match for {pattern!r} in: {text[:120]!r}")
    return m


def highlight(code: str) -> str:
    out = []
    for m in TOKEN.finditer(code):
        kind, text = m.lastgroup, m.group()
        esc = html.escape(text)
        if kind in ("cm", "st"):
            out.append(f'<span class="{kind}">{esc}</span>')
        elif kind == "pk":
            out.append(f'<span class="fn">{esc}</span>')
        elif kind == "id" and text in KEYWORDS:
            out.append(f'<span class="kw">{esc}</span>')
        else:
            out.append(esc)
    return "".join(out)


def helpers(texts: list) -> dict:
    """Every private item in the showcase, keyed by how a use of it reads: a
    type by its name, a function by its name and an opening parenthesis."""
    items = {}
    for text in texts:
        for chunk in text.split("///|\n"):
            lines = [l for l in chunk.splitlines() if not l.startswith("//")]
            if not lines or lines[0].startswith("pub "):
                continue
            m = re.match(r"(?:priv )?(struct|fn|impl [@\w.]+ for) (\w+)", lines[0])
            if m:
                use = m.group(2) + ("(" if m.group(1) == "fn" else "")
                items.setdefault(use, []).append(chunk.strip("\n"))
    return items


def with_helpers(body: str, items: dict) -> str:
    """The demo's source followed by every private item it reaches."""
    shown, todo, out = set(), [body], [body]
    while todo:
        code = todo.pop()
        for use, chunks in items.items():
            if use not in shown and re.search(r"\b" + re.escape(use), code):
                shown.add(use)
                out.extend(chunks)
                todo.extend(chunks)
    return "\n\n".join(c.strip("\n") for c in out)


def functions() -> dict:
    """Each `pub fn name() -> Demo` in the showcase, keyed by function name."""
    paths = [p for p in sorted(SHOWCASE.glob("*.mbt")) if not p.name.endswith("_test.mbt")]
    texts = [p.read_text(encoding="utf-8") for p in paths]
    items = helpers(texts)
    found = {}
    for text in texts:
        for m in re.finditer(r"^pub fn (\w+)\(\) -> Demo \{\n(.*?)^\}\n", text, re.M | re.S):
            body = m.group(0)
            demo = body[find(r"Demo::new\(", body).start():]
            found[m.group(1)] = {
                "name": find(r'Demo::new\(\s*"([^"]+)"', demo).group(1),
                "note": find(r'note="((?:\\.|[^"\\])*)"', demo).group(1),
                "group": find(r"group=(\w+)", demo).group(1),
                "rows": int(find(r"rows=(\d+)", demo).group(1)),
                "code": with_helpers(body, items),
            }
    return found


def order() -> list:
    text = (SHOWCASE / "demo.mbt").read_text(encoding="utf-8")
    block = find(r"pub fn demos\(\) -> Array\[Demo\] \{\n  \[\n(.*?)\n  \]", text, re.S)
    return re.findall(r"(\w+)\(\)", block.group(1))


def card(demo: dict) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", demo["name"].lower()).strip("-")
    height = demo["rows"] * CELL
    name = html.escape(demo["name"])
    return (
        f'  <div class="wcard" id="demo-{slug}">\n'
        f'    <h4><code class="inline">{name}</code></h4>\n'
        f'    <p class="wdesc">{html.escape(demo["note"])}</p>\n'
        f'    <div class="wlive"><canvas id="live-{slug}" data-demo="{name}"'
        f' tabindex="0" style="height: {height}px"></canvas></div>\n'
        f'    <div class="wmsg" data-for="live-{slug}"></div>\n'
        f'    <pre class="block wcode">{highlight(demo["code"])}</pre>\n'
        f"  </div>\n"
    )


def section(demos: list, groups: list) -> str:
    out = []
    for group in groups:
        members = [d for d in demos if d["group"] == group]
        if members:
            out.append(f"  <h3>{TITLES[group]}</h3>\n")
            out.extend(card(d) for d in members)
    return "".join(out)


def fill(page: str, region: str, body: str) -> str:
    start, end = f"<!-- generated:{region} -->", f"<!-- /generated:{region} -->"
    a, b = page.index(start) + len(start), page.index(end)
    return page[:a] + "\n" + body + page[b:]


def main():
    by_fn = functions()
    demos = [by_fn[name] for name in order()]
    page = PAGE.read_text(encoding="utf-8")
    page = fill(page, "widgets", section(demos, ["Text", "Entry", "Choice", "Navigation", "Data"]))
    page = fill(page, "style", section(demos, ["Style"]))
    PAGE.write_text(page, encoding="utf-8", newline="\n")
    print(f"{len(demos)} demos written")


if __name__ == "__main__":
    main()
