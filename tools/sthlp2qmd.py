#!/usr/bin/env python3
"""
sthlp2qmd.py -- render a Stata help file (.sthlp, SMCL) as a Quarto page.

build.do runs this for each package so that the "Help file" page is made from
the help file installed on the adopath and always matches the installed
version. By hand:

    python tools/sthlp2qmd.py path/to/mecompare.sthlp mecompare/help.qmd --cmd mecompare

The conversion covers the SMCL directives these help files use: {title} and
{dlgtab} become headings, {cmd}/{opt}/{it}/{bf} become inline formatting,
{help ...} references to commands documented on this site become links,
{stata ...} example lines and ". command" lines become code blocks,
{synopthdr}/{syntab}/{synopt} become tables, {p2col} entries become
term-and-description paragraphs, {marker} becomes an anchor, and the
tab-indented "Table of contents" lines become a list. Anything unrecognised
passes through as its text.
"""
import argparse
import os
import re

# Commands documented on this site: {help name} -> link to that help page.
SITE_PAGES = {
    "mecompare": "mecompare/help.html",
    "metest": "metest/help.html",
    "suest2": "suest2/help.html",
    "meinequality": "meinequality/help.html",
    "totalme": "totalme/help.html",
    "balanceplot": "balanceplot/help.html",
    "cleanplots": "cleanplots/help.html",
    "desctable": "desctable/help.html",
    "irt_coef": "irt_coef/help.html",
    "irt_me": "irt_me/help.html",
    "lca_entropy": "lca_entropy/help.html",
    "sgmediation2": "sgmediation2/help.html",
    "usetdm": "usetdm/help.html",
}

# Syntax placeholders written as bare directives, e.g. {varlist} {ifin} {weight}
PLACEHOLDERS = {"varlist", "ifin", "weight", "varname", "depvar", "indepvars", "newvar",
                "options", "if", "in", "exp", "numlist", "namelist", "filename", "varlist2",
                "it", "vars", "newvarlist", "indepvar"}

DIRECTIVE = re.compile(r'\{([A-Za-z_][A-Za-z0-9_]*|\*|\.\.\.)(?:\s+((?:"[^"]*"|[^{}:"])*))?(:)?')


# ---------------------------------------------------------------- parsing --

def parse(text):
    """SMCL -> list of nodes; a node is a str or (name, arg, children|None)."""
    pos, n = 0, len(text)
    root, stack, buf = [], [], []
    stack.append(root)

    def flush():
        if buf:
            stack[-1].append("".join(buf))
            buf.clear()

    while pos < n:
        ch = text[pos]
        if ch == "{":
            m = DIRECTIVE.match(text, pos)
            if not m:
                buf.append(ch); pos += 1; continue
            flush()
            name, arg, colon = m.group(1), m.group(2), m.group(3)
            pos = m.end()
            if name in ("*", "..."):
                depth = 1
                while pos < n and depth:
                    if text[pos] == "{": depth += 1
                    elif text[pos] == "}": depth -= 1
                    pos += 1
                continue
            if colon:
                node = (name, arg, [])
                stack[-1].append(node)
                stack.append(node[2])
            else:
                end = text.find("}", pos)
                end = n if end == -1 else end
                extra = text[pos:end].strip()
                pos = end + 1
                a = ((arg or "") + (" " + extra if extra else "")).strip()
                stack[-1].append((name, a or None, None))
        elif ch == "}":
            flush()
            if len(stack) > 1:
                stack.pop()
            pos += 1
        else:
            buf.append(ch); pos += 1
    flush()
    return root


# --------------------------------------------------------------- inline ----

def strip_abbrev(s):
    return re.sub(r"([A-Za-z_]+):([A-Za-z_(]+)", r"\1\2", s, count=1)


def code_span(t):
    t = t.strip()
    return "`" + t + "`" if t else ""


def help_link(arg, inner, this_page):
    a = (arg or "").strip()
    text = inner.strip() if inner else ""
    if "##" in a:
        target, anchor = a.split("##", 1)
    else:
        target, anchor = a, None
    target = target.strip()
    if target in SITE_PAGES:
        url = SITE_PAGES[target]
        here = this_page.split("/")[0]
        url = url[len(here) + 1:] if url.startswith(here + "/") else "../" + url
        if anchor:
            url += "#" + anchor.strip()
        return f"[{text or target}]({url})"
    return text if text else code_span(target)


def inline(nodes, this_page):
    out = []
    for nd in nodes:
        if isinstance(nd, str):
            out.append(nd)
            continue
        name, arg, ch = nd
        inner = inline(ch, this_page) if ch is not None else ""
        if name in ("cmd", "cmdab", "opt"):
            if name == "cmd":
                t = (arg + ":" + inner) if arg else inner
            else:
                t = (arg or "") + inner            # colon = abbreviation marker
            out.append(code_span(strip_abbrev(t)))
        elif name == "it":
            t = inner.strip()
            out.append("*" + t + "*" if t else "")
        elif name in ("bf", "ul"):
            t = inner.strip().replace("**", "")
            out.append("**" + t + "**" if t else "")
        elif name == "stata":
            a = (arg or "").strip()
            if a.startswith('"') and a.endswith('"'):
                a = a[1:-1]
            out.append(code_span(a if a else inner))
        elif name in ("help", "helpb", "manhelp", "manhelpi"):
            out.append(help_link(arg, inner, this_page))
        elif name == "browse":
            a = (arg or "").strip()
            if a.startswith('"') and a.endswith('"'):
                a = a[1:-1]
            label = inner.strip() if inner else a
            out.append(f"[{label}]({a})" if a else label)
        elif name == "hline":
            out.append("--" if arg else "---")
        elif name == "space":
            out.append(" " * int(arg or 1))
        elif name == "tab":
            out.append("    ")
        elif name == "term":
            out.append("**" + inner.strip().replace("**", "") + "** ")
        elif name in ("c", "char"):
            out.append({"S|": "|", "-": "-", "|": "|", "'": "'"}.get((arg or "").strip(), ""))
        elif name in ("res", "txt", "sf", "err", "inp", "input", "result", "text",
                      "p_end", "bind", "com", "cmd_end"):
            out.append("")
        elif name in PLACEHOLDERS and ch is None:
            out.append("*" + name + "*")
        else:
            out.append(inner)
    s = "".join(out)
    return s.replace("****", "")


# --------------------------------------------------------------- blocks ----

PARA = {"p", "pstd", "phang", "phang2", "phang3", "pmore", "pmore2", "pmore3",
        "pin", "pin2", "pin3", "psee"}
NOOP = {"smcl", "p2colset", "p2colreset", "synoptset", "vieweralsosee", "p2line",
        "synoptline", "hline", "bind", "com"}


class Renderer:
    def __init__(self, this_page):
        self.page = this_page
        self.out = []
        self.para = []
        self.code = []
        self.table = None      # rows: [kind, a, b]
        self.row = None        # open synopt row collecting description nodes
        self.bullet = False
        self.section = ""      # current {title:...}, lower-cased

    def flush_code(self):
        if self.code:
            self.out.append("```stata\n" + "\n".join(self.code) + "\n```")
            self.code = []

    def flush_para(self):
        if self.para:
            t = inline(self.para, self.page).strip()
            t = re.sub(r"[ \t]*\n[ \t]*", " ", t)
            t = re.sub(r"  +", " ", t)
            if t:
                if t.startswith("`. ") and t.endswith("`") and t.count("`") == 2:
                    self.code.append(t[3:-1])
                elif t.startswith("`") and t.endswith("`") and t.count("`") == 2 and len(t) > 4:
                    self.code.append(t[1:-1])
                elif self.section.startswith("example") and re.match(r"^\*\*[^*]+\*$", t):
                    # an {it:*comment} line in an Examples section: a code comment
                    self.code.append("* " + t.strip("*").strip())
                elif self.section.startswith("example") and not re.search(r"[`*\[]", t) \
                        and not t.rstrip().endswith(":"):
                    # a plain command line in an Examples section (no markup)
                    self.code.append(t)
                else:
                    self.flush_code()
                    self.out.append(("- " if self.bullet else "") + t)
            self.para = []
        self.bullet = False

    def close_row(self):
        if self.row is not None:
            kind, a, nodes = self.row
            self.row = None
            if kind == "skip":
                return
            b = inline(nodes, self.page).strip()
            b = re.sub(r"\s*\n\s*", " ", b)
            if kind == "hdr?":
                cells = [c.strip() for c in re.split(r"  +", b) if c.strip()]
                if len(cells) >= 2 and all(c.startswith("**") for c in cells):
                    self.table = [["hdrN", a] + [c.strip("*") for c in cells]]
                else:                       # an ordinary bold definition term
                    self.para = [("term", None, ["**" + a + "**"]), b]
                return
            if kind == "rowN":
                cells = [c.strip() for c in re.split(r"  +", b)]
                self.table.append(["rowN", a] + cells)
                return
            self.table.append([kind, a, b])

    def flush_table(self):
        self.close_row()
        if self.table:
            self.flush_code()
            if self.table[0][0] == "hdrN":          # multi-column table
                hdr = self.table[0][1:]
                n = len(hdr)
                lines = ["| " + " | ".join(hdr) + " |", "|" + ":--|" * n]
                for row in self.table[1:]:
                    cells = (row[1:] + [""] * n)[:n]
                    lines.append("| " + " | ".join(cells) + " |")
                self.out.append("\n".join(lines))
                self.table = None
                return
            hdr = self.table[0] if self.table[0][0] == "hdr" else ["hdr", "", ""]
            lines = [f"| {hdr[1]} | {hdr[2]} |", "|:--|:--|"]
            for kind, a, b in self.table:
                if kind == "hdr":
                    continue
                lines.append(f"| *{a}* | |" if kind == "tab" else f"| {a} | {b} |")
            self.out.append("\n".join(lines))
        self.table = None

    def flush_all(self):
        self.flush_para(); self.flush_code(); self.flush_table()

    def run(self, nodes):
        for nd in nodes:
            if isinstance(nd, str):
                self.text(nd)
            else:
                self.directive(nd)
        self.flush_all()
        return self.out

    def text(self, s):
        if self.row is not None:
            self.row[2].append(s)
            return
        # a tab-indented continuation of a {p2col} term's description (as in
        # a Title block) belongs to that description, not to a bullet
        if self.para and isinstance(self.para[0], tuple) and self.para[0][0] == "term" \
                and s.strip() != "" and ("\n\t" in s or s.startswith("\t")):
            self.para.append(s.replace("\t", " "))
            return
        if s.strip() == "":
            if "\n\t" in s or s.startswith("\t"):
                self.flush_para(); self.bullet = True
            elif s.count("\n") >= 2:
                self.flush_para()
            else:
                self.para.append(s)
            return
        if "\n\t" in s or s.startswith("\t"):
            self.flush_para(); self.bullet = True
            s = s.strip()
        stripped = s.strip()
        if not self.para and stripped.startswith("*"):
            self.flush_para(); self.flush_code()
            self.out.append("**" + stripped.strip("* ").strip() + "**")
            return
        self.para.append(s)

    def directive(self, nd):
        name, arg, ch = nd
        if self.row is not None and name not in ("p_end", "synopt", "syntab", "synoptline",
                                                 "synopthdr", "title", "dlgtab", "marker",
                                                 "p2col", "p2line"):
            self.row[2].append(nd)
            return
        if name == "title":
            self.flush_all()
            ttl = inline(ch, self.page).strip()
            self.section = ttl.lower()
            self.out.append("## " + ttl)
        elif name == "dlgtab":
            self.flush_all()
            self.out.append("### " + inline(ch, self.page).strip())
        elif name == "marker":
            self.flush_para(); self.flush_code()
            self.out.append(f'<span id="{(arg or "").strip()}"></span>')
        elif name == "p2col":
            self.flush_para(); self.close_row()
            term = inline(ch or [], self.page).strip()
            if term.lower() == "name" and self.table is None:
                # a {p2col :Name}Description{p_end} header opens a small table
                self.table = [["hdr", "Name", "Description"]]
                self.row = ["skip", "", []]
            elif self.table is not None and self.table[0][1] == "Name":
                self.row = ["row", term, []]
            elif term.startswith("**") and term.endswith("**") and self.table is None:
                # a bold term may head a multi-column table: decided in close_row
                # once the rest of the line (the other column headers) is seen
                self.row = ["hdr?", term.strip("*"), []]
            elif self.table is not None and self.table[0][0] == "hdrN":
                self.row = ["rowN", term, []]
            elif term:
                self.para = [("term", None, [term])]
        elif name in PARA:
            self.flush_para()
        elif name == "p_end":
            if self.row is not None:
                self.close_row()
            else:
                self.flush_para()
        elif name == "synopthdr":
            self.flush_para(); self.flush_table()
            label = inline(ch, self.page).strip() if ch else (arg or "Option")
            self.table = [["hdr", label, "Description"]]
        elif name == "syntab":
            self.flush_para(); self.close_row()
            if self.table is None:
                self.table = [["hdr", "", "Description"]]
            self.table.append(["tab", inline(ch or [], self.page).strip(), ""])
        elif name == "synopt":
            self.flush_para(); self.close_row()
            if self.table is None:
                self.table = [["hdr", "Option", "Description"]]
            self.row = ["row", inline(ch or [], self.page).strip(), []]
        elif name in NOOP:
            if name == "p2colreset" and self.table is not None and self.table[0][0] == "hdrN":
                self.flush_table()        # a multi-column table ends with its p2colreset
            if name in ("p2line", "synoptline"):
                self.flush_para(); self.close_row()
                if self.table is not None and len(self.table) > 1:
                    self.flush_table()
        else:
            self.para.append(nd)


def join_continuations(blocks):
    """Paragraph blocks that end with /// are a command split over lines
    (as in an Examples section); gather them into one code block."""
    out = []
    i = 0
    while i < len(blocks):
        b = blocks[i]
        if b.rstrip().endswith("///") and not b.startswith("```"):
            lines = []
            while i < len(blocks):
                t = blocks[i].strip()
                if t.startswith("- "):
                    t = "    " + t[2:]
                lines.append(t)
                i += 1
                if not t.endswith("///"):
                    break
            out.append("```stata\n" + "\n".join(lines) + "\n```")
        else:
            out.append(b)
            i += 1
    return out


def convert(text, this_page):
    blocks = Renderer(this_page).run(parse(text))
    blocks = join_continuations([b for b in blocks if b.strip()])
    return "\n\n".join(blocks)


# --------------------------------------------------------------- driver ----

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sthlp", help="the .sthlp (or .hlp) file")
    ap.add_argument("out")
    ap.add_argument("--cmd", required=True, help="site section the page lives in (mecompare, suest2, ...)")
    ap.add_argument("--title", default=None)
    ap.add_argument("--subtitle", default=None)
    args = ap.parse_args()

    with open(args.sthlp, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    fname = os.path.basename(args.sthlp)
    name = os.path.splitext(fname)[0]
    md = convert(text, f"{args.cmd}/help.html")
    title = args.title or f"help {name}"
    sub = args.subtitle or "The installed help file, rendered for the web"
    page = f'''---
title: "{title}"
subtitle: "{sub}"
toc-depth: 3
---

::: {{.callout-note appearance="simple"}}
This page is generated from `{fname}` by `build.do`, so it matches the
installed version. In Stata, type `help {name}`.
:::

{md}
'''
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
