"""Regenerate the widgets page of docs/index.html from the gallery output.

Run `moon run --target native examples/gallery` first and save the output
(to gallery.txt next to this script). Each widget card pairs a usage
snippet with the widget's real rendered rows, hand-tinted to match the
default styles (reverse for cursors, dim for inactive, and so on).
"""

import html
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "docs", "index.html")
GALLERY = io.open(os.path.join(HERE, "gallery.txt"), encoding="utf-8").read()

# ---- split the gallery output into titled sections --------------------
sections = {}
title = None
buf = []
for line in GALLERY.splitlines():
    if line.startswith("── "):
        if title is not None:
            sections[title] = [l for l in buf]
        title = line[3:].strip()
        buf = []
    else:
        buf.append(line)
if title is not None:
    sections[title] = [l for l in buf]

def out(*titles):
    """Join one or more gallery sections, dropping blank padding rows."""
    rows = []
    for t in titles:
        rows.extend(sections[t])
    while rows and rows[-1] == "":
        rows.pop()
    while rows and rows[0] == "":
        rows.pop(0)
    return rows

def esc(s):
    return html.escape(s)

def plain(titles):
    return esc("\n".join(out(titles)))

# ---- hand-tinted outputs, faithful to the default styles --------------
def tint_header():
    return f'<span class="rev">{esc(out("Header · Footer")[0])}</span>'

def tint_footer():
    rows = out("Footer")
    line = rows[0]
    keys = ["tab", "enter", "q"]
    i = 0
    parts = []
    while i < len(line):
        for k in keys:
            if line.startswith(k + " ", i):
                parts.append(f'<span class="b">{esc(k)}</span>')
                i += len(k)
                break
        else:
            parts.append(esc(line[i]))
            i += 1
    return "".join(parts)

def tint_sparkline():
    line = out("Sparkline")[0]
    green = "▁▂"
    gold = "▃▄▅"
    hot = "▆▇█"
    parts = []
    run = ""
    cls = None
    for ch in line:
        c = "green" if ch in green else "gold" if ch in gold else "pink" if ch in hot else None
        if c == cls:
            run += ch
        else:
            if run:
                parts.append(f'<span class="{cls}">{esc(run)}</span>')
            run = ch
            cls = c
    if run:
        parts.append(f'<span class="{cls}">{esc(run)}</span>')
    return "".join(parts)

def tint_progress():
    line = out("Progress")[0]
    bar = len(line) - len(line.lstrip("█"))
    return esc(line[:bar]) + f'<span class="dim">{esc(line[bar:])}</span>'

def tint_richlog():
    rows = out("RichLog")
    return (
        f'<span class="green">{esc(rows[0])}</span>\n'
        f'<span class="gold">{esc(rows[1])}</span>\n'
        f'{esc(rows[2])}'
    )

def tint_switch():
    return '<span class="rev-d">  </span><span class="rev-g">  </span>'

def tint_checkbox():
    rows = out("Checkbox")
    return f'<span class="green">▐X▌</span>{esc(rows[0][3:])}'

def tint_radioset():
    rows = out("RadioSet")
    styled = []
    for r in rows:
        if r.endswith("Balanced"):
            styled.append(f'<span class="green">▐●▌</span>{esc(r[3:])}')
        else:
            styled.append(f'<span class="dim">▐●▌</span>{esc(r[3:])}')
    return "\n".join(styled)

def tint_optionlist():
    rows = out("OptionList")
    styled = []
    for r in rows:
        if set(r) == {"─"}:
            styled.append(f'<span class="dim">{esc(r)}</span>')
        elif r.strip() == "Retired":
            styled.append(f'<span class="dim">{esc(r)}</span>')
        else:
            styled.append(esc(r))
    return "\n".join(styled)

def tint_selectionlist():
    rows = out("SelectionList")
    styled = []
    for r in rows:
        if r.strip().startswith(("Clean build", "All targets")):
            styled.append(f'<span class="green">▐X▌</span>{esc(r[3:])}')
        else:
            styled.append(f'<span class="dim">▐X▌</span>{esc(r[3:])}')
    return "\n".join(styled)

def tint_select():
    rows = out("Select (expanded)")
    styled = [esc(rows[0])]
    for r in rows[1:]:
        styled.append(esc(r))
    return "\n".join(styled)

def tint_button():
    line = out("Button")[0]
    start = line.index(" Press me")
    return (
        esc(line[:start])
        + f'<span class="rev">{esc(line[start:])}</span>'
    )

def tint_listview():
    rows = out("ListView")
    styled = []
    width = 20
    for r in rows:
        if r.strip() == "beta":
            styled.append(f'<span class="rev">{esc(r.ljust(width))}</span>')
        else:
            styled.append(esc(r))
    return "\n".join(styled)

def tint_tabs(title):
    rows = out(title)
    labels = rows[0].split("  ")
    active = labels[0].strip()
    head = []
    for i, lab in enumerate(labels):
        if i == 0:
            head.append(esc(lab))
        else:
            head.append(f'<span class="dim">{esc(lab)}</span>')
    bar = rows[1]
    n = len(active) + 2
    body = (
        f'<span class="rev">{esc(bar[:n])}</span>'
        f'<span class="dim">{esc(bar[n:])}</span>'
    )
    rest = [esc(r) for r in rows[2:] if r != ""]
    return "\n".join(["  ".join(head), body] + rest)

def tint_tree():
    rows = out("Tree")
    styled = []
    for r in rows:
        m = re.match(r"^([\s│├└─]*)(.*)$", r)
        styled.append(f'<span class="dim">{esc(m.group(1))}</span>{esc(m.group(2))}')
    return "\n".join(styled)

def tint_table():
    rows = out("DataTable")
    styled = [f'<span class="b">{esc(rows[0])}</span>']
    body = []
    for r in rows[1:]:
        m = re.match(r"^(  \S+)(.*)$", r)
        if m:
            body.append(f'<span class="rev">{esc(m.group(1))}</span>{esc(m.group(2))}')
        else:
            body.append(esc(r))
    return "\n".join(styled + body)

def tint_markdown():
    rows = out("Markdown")
    styled = [f'<span class="b">{esc(rows[0])}</span>']
    rest = rows[1:]
    while rest and rest[-1] == "":
        rest.pop()
    return "\n".join(styled + [esc(r) for r in rest])

def tint_toast():
    rows = out("Toast")
    top, msg = rows[0], rows[1]
    bar = '<span class="green">▌</span>'
    title = top[2:]
    return f'{bar} <span class="b">{esc(title)}</span>\n{bar}{esc(msg[1:])}'

# ---- the cards ---------------------------------------------------------
CARDS = [
 ("h3", "Text and display"),
 ("Static",
  "Text clipped at a character boundary — left, centre or right; <code class=\"inline\">label()</code> gives it a style in one call.",
  '@widget.Static::new("Hello, moonetui", align=@widget.Align::Centre)',
  plain("Static")),
 ("Header",
  "The title bar: the title in the centre, a note at the right edge — reverse video by default.",
  '@widget.Header::new("moonetui", note="ctrl-c to quit")',
  tint_header()),
 ("Footer",
  "The bound key hints along the bottom edge, from the pairs you pass in.",
  '@widget.Footer::new([("tab", "next"), ("enter", "choose"), ("q", "quit")])',
  tint_footer()),
 ("Rule",
  "A horizontal or vertical rule in nine styles — ascii, blank, dashed, double, heavy, hidden, solid, thick.",
  '@widget.Rule::horizontal(kind=@widget.RuleKind::Heavy)',
  plain("Rule (heavy)")),
 ("Digits",
  "Big 3-row digit glyphs, plain or bold, for clocks and counters — any character passes through.",
  '@widget.Digits::new(value="12:34")',
  plain("Digits")),
 ("Sparkline",
  "An eight-level block bar chart with bucketing and five summary functions — maximum, minimum, mean, median, latest. Low readings lean green, high ones red.",
  '@widget.Sparkline::new(data=[3.0, 5.0, 2.0, 8.0, 6.0, 4.0, 7.0])',
  tint_sparkline()),
 ("Progress",
  "A determinate bar against a total — or an indeterminate one that drifts on its own.",
  'let bar = @widget.Progress::new(total=100)\nbar.set(62)',
  tint_progress()),
 ("LoadingIndicator",
  "The five-dot pulse that says \"working\"; the dots breathe on the tick.",
  '@widget.LoadingIndicator::new()',
  plain("LoadingIndicator")),
 ("Placeholder",
  "Three lorem variants in a twelve-colour palette — click to cycle, for mockups.",
  '@widget.Placeholder::new(label="Widget slot")',
  plain("Placeholder")),
 ("h3", "Text entry and logs"),
 ("Input",
  "Single-line entry: cursor by grapheme, history, word operations, selection, bracketed paste.",
  'let field = @widget.Input::new(placeholder="type here")\nfield.set("hello")',
  plain("Input")),
 ("TextArea",
  "Multi-line editing — smart home, word movement, undo runs, a line-number gutter, selection and clipboard operations.",
  'let area = @widget.TextArea::new(show_line_numbers=true)\narea.load_text("line one\\nline two\\nline three")',
  plain("TextArea")),
 ("Log",
  "A plain capture log: line tail-following, tab expansion, pruning, and scrolling that stays glued to the end.",
  'let log = @widget.Log::new()\nlog.write_lines(["boot ok", "loading modules", "ready"])',
  plain("Log")),
 ("RichLog",
  "Styled strips with min-width, at-width and greedy word wrap.",
  'let rich = @widget.RichLog::new()\nrich.write("deploy passed", style=@style.Style::new(fg=@style.green))\nrich.write("2 warnings", style=@style.Style::new(fg=@style.yellow))\nrich.write("done")',
  tint_richlog()),
 ("h3", "Choices"),
 ("Switch",
  "A four-wide strip: half thumb, half track — the thumb sits left when off, right when on. State is colour, so the plain wire carries it for free… as nothing at all.",
  '@widget.Switch::new(value=true)',
  tint_switch()),
 ("Checkbox",
  "The three-glyph toggle — side, mark, side — with the label beside it in either order; the mark's colour is the state.",
  '@widget.Checkbox::new("Enable extras", value=true)',
  tint_checkbox()),
 ("RadioSet",
  "Radio buttons as a set: turning one on turns the others off; the cursor and the pressed button are separate, and a click moves both.",
  '@widget.RadioSet::new([\n  @widget.RadioButton::new("Fast"),\n  @widget.RadioButton::new("Balanced", value=true),\n  @widget.RadioButton::new("Quiet"),\n])',
  tint_radioset()),
 ("OptionList",
  "Prompts with separators and disabled entries; the highlight never rests on a disabled one.",
  'let list = @widget.OptionList::new(options=[\n  @widget.Choice::new("Alpha"),\n  @widget.Choice::new("Beta"),\n  @widget.Choice::new("Retired", disabled=true),\n])\nlist.add_separator()\nlist.add_option(@widget.Choice::new("Omega"))',
  tint_optionlist()),
 ("SelectionList",
  "Checkbox-style multi-select with the three-glyph mark and the <code class=\"inline\">ToggledAt</code> message.",
  '@widget.SelectionList::new(options=[\n  @widget.Selection::new("Clean build", "clean", initial_state=true),\n  @widget.Selection::new("All targets", "targets", initial_state=true),\n  @widget.Selection::new("Sign the tag", "sign"),\n])',
  tint_selectionlist()),
 ("Select",
  "A collapsed prompt that expands in flow — substring search narrows the options, Escape folds it away.",
  'let pick = @widget.Select::new(\n  options=[("alpha", "Alpha"), ("beta", "Beta"), ("gamma", "Gamma")],\n  prompt="Pick",\n)',
  tint_select()),
 ("h3", "Navigation and structure"),
 ("Button",
  "Enter or space presses; a disabled button takes neither focus nor input. Focused, the label turns reverse video.",
  '@widget.Button::new(" Press me ")\n// focused: Enter answers Pressed(id=...)',
  tint_button()),
 ("ListView",
  "A vertical list with a moving highlight and mouse picking.",
  'let list = @widget.ListView::new(["alpha", "beta", "gamma", "delta", "epsilon"])\nlist.select(1)',
  tint_listview()),
 ("Tabs",
  "Labels with a highlighted underline that skips disabled tabs.",
  '@widget.Tabs::new(labels=["Inbox", "Reports", "Settings"])',
  tint_tabs("Tabs")),
 ("TabbedContent",
  "Tabs and their panes together: the bar above, the active pane beneath.",
  '@widget.TabbedContent::new(\n  labels=["Overview", "Logs"],\n  panes=[@widget.Static::new("3 unread, 1 flagged"),\n         @widget.Static::new("last run: 42 seconds")],\n)',
  tint_tabs("TabbedContent")),
 ("Collapsible",
  "A fold with the triangle marker; keys and clicks pass through to the contents when open.",
  'let fold = @widget.Collapsible::new(\n  title="Details",\n  contents=@widget.Static::new("All checks passed."),\n)\nfold.set_collapsed(false)',
  plain("Collapsible (open)")),
 ("Tree",
  "Guides, icons, the full shift-arrow family walk, and shift-space batch toggling.",
  'let tree = @widget.Tree::new(root_label="Dune")\ntree.expand(tree.root_id())\nlet arrakis = tree.add(tree.root_id(), "Arrakis", expand=true)\nignore(tree.add(tree.root_id(), "Caladan"))\nignore(tree.add_leaf(arrakis, "Arrakeen"))\nignore(tree.add_leaf(arrakis, "Carthag"))',
  tint_tree()),
 ("DirectoryTree",
  "A tree over a directory listing — folders first, expanded lazily through a loader you inject, so any platform can feed it.",
  '@widget.DirectoryTree::new(path=".", loader=read_dir)',
  plain("DirectoryTree")),
 ("h3", "Data and notices"),
 ("DataTable",
  "Tabular data: auto or fixed column widths, three cursor shapes, zebra rows, hover, clicks that pick headers, labels and cells, and sorts that keep rows whole.",
  'let table = @widget.DataTable::new(zebra=true)\nignore(table.add_column("Name", width=12))\nignore(table.add_column("Size", width=6, align=@widget.Align::Right))\nignore(table.add_column("Kind"))\nignore(table.add_row(["moon.pkg", "184", "package"]))\nignore(table.add_row(["main.mbt", "4096", "source"]))\nignore(table.add_row(["README.md", "2211", "text"]))',
  tint_table()),
 ("Markdown",
  "Documents from source: headings, paragraphs, lists, quotes, code fences, rules and pipe tables — bold, italic, code and link styling inline.",
  '@widget.Markdown::new(\n  "# Deploy report\\n\\nAll four backends pass.\\n\\n- wasm ok\\n- native ok\\n\\n| target | tests |\\n|:-|:-:|\\n| wasm | 273 |\\n",\n)',
  tint_markdown()),
 ("Tooltip",
  "A padded hint that wraps within a maximum width, for status strips and hover help; it swallows keys and clicks.",
  '@widget.Tooltip::new("The build passed on all four backends.")',
  plain("Tooltip")),
 ("Toast",
  "A transient notice with a severity bar — information, warning or error — that expires on its own timer or retires on a click.",
  '@widget.Toast::new(\n  "Everything is nominal.",\n  title="Deployed",\n  level=@widget.ToastLevel::Information,\n  duration=6,\n)',
  tint_toast()),
]

parts = []
parts.append('  <h2>Widgets</h2>\n')
parts.append(
  '  <p class="lead">Thirty-two widgets, each with its own keyboard contract, message shape and rendering. '
  'Every snippet below is a live excerpt from <code class="inline">examples/gallery</code>, and every output block is what that example really renders.</p>\n')
parts.append('  <pre class="block">moon run --target native examples/gallery</pre>\n')
for entry in CARDS:
    if entry[0] == "h3":
        parts.append(f'  <h3>{entry[1]}</h3>\n')
        continue
    title, desc, code, out_html = entry
    parts.append(
        '  <div class="wcard">\n'
        f'    <h4><code class="inline">{esc(title)}</code></h4>\n'
        f'    <p class="wdesc">{desc}</p>\n'
        '    <div class="wcols">\n'
        f'      <pre class="block wcode">{esc(code)}</pre>\n'
        f'      <div class="term-body wout">{out_html}</div>\n'
        '    </div>\n'
        '  </div>\n'
    )

page = (
  '<!-- ============================= WIDGETS ============================= -->\n'
  '<section class="page" id="page-widgets">\n'
  '  <div class="topbar">\n'
  '    <div class="crumbs">docs / <b class="crumb-here">widgets</b></div>\n'
  '    <div class="acts"><button class="ghost-btn" class="theme-toggle">◐ theme</button></div>\n'
  '  </div>\n\n'
  + "".join(parts) +
  '</section>\n\n'
)

src = io.open(SRC, encoding="utf-8").read()
start = src.index("<!-- ============================= WIDGETS ============================= -->")
end = src.index("<!-- ============================= DESIGN ============================= -->")
new = src[:start] + page + src[end:]
io.open(SRC, "w", encoding="utf-8", newline="\n").write(new)
print("widgets page rebuilt:", len(new), "bytes")
