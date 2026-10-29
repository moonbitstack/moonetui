"""Fill the API page of docs/index.html from the package interfaces.

Every public type, value and function is read from the interface `moon info`
writes, with the `///` comment above its definition. A driver package built for
one target only has no `pkg.generated.mbti`; its interface comes from the
`moon check` output for that target.

Usage: moon check --target all && python scripts/gen_api.py
"""

import html
import pathlib
import re

from gen_docs import PAGE, ROOT, fill, find, highlight

SRC = ROOT / "src"

# Reading order: the cell up to the widgets, then the loop that drives them.
PACKAGES = [
    "geom", "style", "strip", "layout", "event", "input", "vt", "comp",
    "design", "widget", "app", "driver", "driver/native", "driver/node",
    "driver/web",
]

# Methods `derive` adds. A reader looks for them in the derive clause.
DERIVED = {"equal", "not_equal", "to_repr", "output", "hash", "hash_combine", "to_json"}

KIND = {
    "struct": "type", "enum": "type", "trait": "trait", "error": "error",
    "value": "let", "fn": "fn",
}

DECL = re.compile(
    r"pub(?:\([a-z]+\))?\s+(?:"
    r"fn(?:\[[^\]]*\])?\s+(?P<fn>[A-Za-z0-9_:]+)"
    r"|let\s+(?P<value>\w+)"
    r"|suberror\s+(?P<error>\w+)"
    r"|struct\s+(?P<struct>\w+)"
    r"|enum\s+(?P<enum>\w+)"
    r"|trait\s+(?P<trait>\w+)"
    r"|impl(?:\[[^\]]*\])?\s+(?P<impl>.+)"
    r")"
)


def named(m: re.Match) -> tuple:
    kind = m.lastgroup or ""
    return kind, m.group(kind).strip()


def interface(path: str) -> pathlib.Path:
    pkg = SRC / path
    generated = pkg / "pkg.generated.mbti"
    if generated.exists():
        return generated
    target = find(r'supported_targets\s*=\s*"(\w+)"', (pkg / "moon.pkg").read_text(encoding="utf-8")).group(1)
    built = ROOT / "_build" / target / "debug" / "check" / path / f"{path.split('/')[-1]}.mbti"
    if not built.exists():
        raise SystemExit(f"{built} is missing: run moon check --target {target} first")
    return built


def declarations(mbti: pathlib.Path) -> list:
    lines = mbti.read_text(encoding="utf-8").splitlines()
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        if not line.startswith("pub"):
            i += 1
            continue
        block, depth = [], 0
        while i < len(lines):
            block.append(lines[i])
            depth += lines[i].count("{") - lines[i].count("}")
            i += 1
            if depth <= 0:
                break
        text = "\n".join(block)
        m = DECL.match(text)
        if m:
            kind, name = named(m)
            out.append({"kind": kind, "name": name, "sig": text})
    return out


def doc_comments(path: str) -> dict:
    """Paragraphs of the `///` comment above each definition, by name."""
    docs = {}
    for file in sorted((SRC / path).glob("*.mbt")):
        if file.name.endswith("_test.mbt"):
            continue
        lines = file.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            if line != "///|":
                continue
            j = i + 1
            body = []
            while j < len(lines) and lines[j].startswith("///"):
                body.append(lines[j][3:].strip())
                j += 1
            if not body or j >= len(lines):
                continue
            m = DECL.match(lines[j])
            if not m or m.lastgroup == "impl":
                continue
            name = named(m)[1]
            paragraphs = [" ".join(p.split("\n")) for p in "\n".join(body).split("\n\n") if p.strip()]
            docs.setdefault(name, paragraphs)
    return docs


def summary(path: str) -> str:
    head = []
    for line in (SRC / path / "moon.pkg").read_text(encoding="utf-8").splitlines():
        if not line.startswith("//"):
            break
        head.append(line[2:].strip())
    return " ".join(head)


def prose(text: str) -> str:
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(text, quote=False))


def words(*names: str) -> str:
    return html.escape(" ".join(n.lower() for n in names))


def item(path: str, decl: dict, methods: list, impls: list, docs: dict) -> str:
    kind = KIND[decl["kind"]]
    sig = decl["sig"]
    out = [
        f'    <div class="api-item" data-q="{words(path, decl["name"])}">\n',
        f'      <h4><span class="api-kind {kind}">{kind}</span><code>{html.escape(decl["name"])}</code></h4>\n',
        f'      <pre class="block">{highlight(sig)}</pre>\n',
    ]
    out += [f"      <p>{prose(p)}</p>\n" for p in docs.get(decl["name"], [])]
    if impls:
        names = ", ".join(f"<code>{html.escape(t)}</code>" for t in impls)
        out.append(f'      <div class="api-impls">implements {names}</div>\n')
    if methods:
        out.append('      <div class="api-methods">\n')
        for m in methods:
            short = m["name"].split("::")[-1]
            out.append(f'        <div class="api-method" data-q="{words(short)}"><pre class="block">{highlight(m["sig"])}</pre>')
            out += [f"<p>{prose(p)}</p>" for p in docs.get(m["name"], [])]
            out.append("</div>\n")
        out.append("      </div>\n")
    out.append("    </div>\n")
    return "".join(out)


def package(path: str) -> tuple:
    decls = declarations(interface(path))
    docs = doc_comments(path)
    types = {d["name"]: d for d in decls if d["kind"] in {"struct", "enum", "trait", "error"}}
    methods = {name: [] for name in types}
    impls = {name: [] for name in types}
    free, values = [], []
    for d in decls:
        if d["kind"] == "impl":
            m = re.match(r"(.+?)\s+for\s+(\w+)", d["name"])
            if m and m.group(2) in impls:
                impls[m.group(2)].append(m.group(1))
        elif d["kind"] == "fn" and "::" in d["name"]:
            owner, short = d["name"].split("::", 1)
            if short in DERIVED and d["name"] not in docs:
                continue
            methods.setdefault(owner, []).append(d)
        elif d["kind"] == "fn":
            free.append(d)
        elif d["kind"] == "value":
            values.append(d)

    rank = {"trait": 0, "struct": 1, "enum": 1, "error": 2}
    body = [item(path, t, methods.get(n, []), impls[n], docs)
            for n, t in sorted(types.items(), key=lambda kv: (rank[kv[1]["kind"]], kv[0]))]
    body += [item(path, v, [], [], docs) for v in sorted(values, key=lambda d: d["name"])]
    body += [item(path, f, [], [], docs) for f in sorted(free, key=lambda d: d["name"])]
    count = len(types) + len(values) + len(free) + sum(len(v) for v in methods.values())

    slug = "api-" + path.replace("/", "-")
    section = (
        f'  <div class="api-pkg" id="{slug}">\n'
        f'    <h3>{html.escape(path)}<small>moonbitstack/moonetui/{html.escape(path)}</small></h3>\n'
        f"    <p>{prose(summary(path))}</p>\n"
        + "".join(body)
        + "  </div>\n"
    )
    chip = f'    <button type="button" data-pkg="{slug}">{html.escape(path)}<span>{count}</span></button>\n'
    return section, chip, count


def main():
    sections, chips, total = [], [], 0
    for path in PACKAGES:
        section, chip, count = package(path)
        sections.append(section)
        chips.append(chip)
        total += count
    body = (
        '  <div class="api-tools">\n'
        '    <input class="api-filter" type="search" placeholder="Filter by name, e.g. Button or render" aria-label="Filter the API">\n'
        f'    <span class="api-count" data-total="{total}">{total} entries</span>\n'
        "  </div>\n"
        '  <div class="api-index">\n' + "".join(chips) + "  </div>\n"
        + "".join(sections)
        + '  <p class="api-empty" hidden>Nothing public matches that name.</p>\n'
    )
    page = PAGE.read_text(encoding="utf-8")
    PAGE.write_text(fill(page, "api", body), encoding="utf-8", newline="\n")
    print(f"{len(PACKAGES)} packages, {total} entries written")


if __name__ == "__main__":
    main()
