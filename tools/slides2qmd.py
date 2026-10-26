#!/usr/bin/env python3
"""
slides2qmd.py -- draft the web pages for one course section from its Word slides.

    python tools/slides2qmd.py cda 02 "path/to/CDA-02 slides.docx"
    python tools/slides2qmd.py cda 02 "path/to/slides.docx" --with-r

Writes one draft page per numbered part of the slides (2.1, 2.2, ...,
Appendix 2A, ...) to  teaching/<course>/<section>/_draft/, with the slide
images in _draft/media/.  The drafts are a starting point: copy them into
_src/, replace each ```{.slide-output} block with the do-file code that
produces it (inside <<dd_do>> tags), and run build_teaching.do.  The tool
never touches _src/, so it is safe to rerun.

What it does to the slides: text, links, equations, and images are kept;
numbered lists become bullets; a continuation slide that repeats the previous
title is merged into it; side-note text boxes become boxes after the content
they sat beside; Stata output becomes a {.slide-output} placeholder; R code is
left out unless --with-r (then {.slide-r}).  Arrows and shapes drawn over a
slide are not kept.

Needs Quarto (for its pandoc) and lxml (python -m pip install lxml).
"""
import argparse
import copy
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from lxml import etree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILTER = os.path.join(ROOT, "tools", "slides2qmd.lua")

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
MC = "http://schemas.openxmlformats.org/markup-compatibility/2006"
NS = {"w": W, "mc": MC}
CODE_IDS = {"Output125point", "Rcode", "do-file12pt"}
MONO = {"Courier New", "Lucida Console", "Consolas", "Courier"}
NBSP = " "


def q(tag):
    p, t = tag.split(":")
    return "{%s}%s" % (NS[p], t)


def pstyle(p):
    s = p.find("w:pPr/w:pStyle", NS)
    return s.get(q("w:val")) if s is not None else None


def set_pstyle(p, sid):
    ppr = p.find("w:pPr", NS)
    if ppr is None:
        ppr = etree.Element(q("w:pPr"))
        p.insert(0, ppr)
    for child in list(ppr):
        if child.tag in (q("w:pStyle"), q("w:numPr")):
            ppr.remove(child)
    s = etree.Element(q("w:pStyle"))
    s.set(q("w:val"), sid)
    ppr.insert(0, s)


def in_textbox(p):
    return any(a.tag == q("w:txbxContent") for a in p.iterancestors())


def prepare(src, dst):
    """Pre-pass on the .docx so pandoc keeps what matters."""
    zin = zipfile.ZipFile(src)
    doc = etree.fromstring(zin.read("word/document.xml"))
    styles = etree.fromstring(zin.read("word/styles.xml"))
    body = doc.find("w:body", NS)

    # Stata output pasted in a monospace font without the output style
    def mono(p):
        runs = [r for r in p.findall("w:r", NS)
                if "".join(t.text or "" for t in r.findall("w:t", NS)).strip()]
        if not runs:
            return None
        for r in runs:
            f = r.find("w:rPr/w:rFonts", NS)
            if f is None or f.get(q("w:ascii")) not in MONO:
                return False
        return True
    plist = [p for p in body.iter(q("w:p")) if pstyle(p) not in CODE_IDS and not in_textbox(p)]
    flags = [mono(p) for p in plist]
    for i, p in enumerate(plist):
        f = flags[i]
        if f is None:  # an empty line counts when it sits between monospace lines
            prev = next((flags[j] for j in range(i - 1, -1, -1) if flags[j] is not None), False)
            nxt = next((flags[j] for j in range(i + 1, len(flags)) if flags[j] is not None), False)
            f = prev and nxt
        if f and pstyle(p) in (None, "Normal"):
            set_pstyle(p, "Output125point")

    # text boxes (side notes) -> paragraphs after the content they sat beside
    boxes = [ac for ac in body.iter(q("mc:AlternateContent"))
             if ac.find(".//w:txbxContent", NS) is not None
             and not any(a.tag == q("mc:AlternateContent") for a in ac.iterancestors())]
    for ac in boxes:
        box = ac.find("mc:Choice//w:txbxContent", NS)
        if box is None:
            box = ac.find(".//w:txbxContent", NS)
        paras = [copy.deepcopy(p) for p in box.findall("w:p", NS) if "".join(p.itertext()).strip()]
        anchor = next(ac.iterancestors(q("w:p")))
        ac.getparent().remove(ac)
        for i, p in enumerate(paras):
            set_pstyle(p, "TBNoteFirst" if i == 0 else "TBNote")
        pos = anchor
        if pstyle(anchor) in CODE_IDS:
            while pos.getnext() is not None and pos.getnext().tag == q("w:p") and pstyle(pos.getnext()) in CODE_IDS:
                pos = pos.getnext()
        for p in paras:
            pos.addnext(p)
            pos = p

    # code and output: keep column spacing and blank lines
    for p in body.iter(q("w:p")):
        if pstyle(p) not in CODE_IDS:
            continue
        ts = p.findall(".//w:t", NS)
        if not "".join(t.text or "" for t in ts):
            r = etree.SubElement(p, q("w:r"))
            etree.SubElement(r, q("w:t")).text = NBSP
        for t in ts:
            if t.text:
                t.text = t.text.replace(" ", NBSP)

    for sid, name in (("TBNoteFirst", "TB Note First"), ("TBNote", "TB Note")):
        st = etree.SubElement(styles, q("w:style"))
        st.set(q("w:type"), "paragraph")
        st.set(q("w:styleId"), sid)
        etree.SubElement(st, q("w:name")).set(q("w:val"), name)

    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename == "word/document.xml":
                zout.writestr(item, etree.tostring(doc, xml_declaration=True, encoding="UTF-8", standalone=True))
            elif item.filename == "word/styles.xml":
                zout.writestr(item, etree.tostring(styles, xml_declaration=True, encoding="UTF-8", standalone=True))
            else:
                zout.writestr(item, zin.read(item.filename))


def pandoc(args, inp=None):
    r = subprocess.run(["quarto", "pandoc"] + args, input=inp, capture_output=True,
                       text=True, encoding="utf-8")
    if r.returncode:
        sys.exit(r.stderr)
    return r.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("course")
    ap.add_argument("section")
    ap.add_argument("docx")
    ap.add_argument("--with-r", action="store_true", help="keep R code as {.slide-r} blocks")
    a = ap.parse_args()

    out = os.path.join(ROOT, "teaching", a.course, a.section, "_draft")
    media = os.path.join(out, "media")
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(media)

    tmp = tempfile.mkdtemp()
    prepped = os.path.join(tmp, "slides.docx")
    prepare(a.docx, prepped)
    js = json.loads(pandoc([prepped, "-f", "docx+styles", "--lua-filter", FILTER,
                            "-M", "keep-r=" + ("true" if a.with_r else "false"),
                            "--extract-media", tmp, "-t", "json"]))

    for f in glob.glob(os.path.join(tmp, "media", "*")):
        shutil.copy(f, media)
        if f.lower().endswith((".emf", ".wmf")):
            print("  browsers can't show " + os.path.basename(f) + ": save a PNG version of it in _draft/media")

    def fix_images(o):
        if isinstance(o, dict):
            if o.get("t") == "Image":
                tgt = o["c"][2]
                tgt[0] = "media/" + os.path.basename(tgt[0])
            for v in o.values():
                fix_images(v)
        elif isinstance(o, list):
            for v in o:
                fix_images(v)
    fix_images(js["blocks"])

    # one draft per level-1 heading
    api = js["pandoc-api-version"]
    parts, cur = [], None
    for b in js["blocks"]:
        if b["t"] == "Header" and b["c"][0] == 1:
            cur = {"title": b["c"][2], "blocks": []}
            parts.append(cur)
        elif cur is not None:
            cur["blocks"].append(b)

    def as_text(blocks, fmt):
        doc = {"pandoc-api-version": api, "meta": {}, "blocks": blocks}
        return pandoc(["-f", "json", "-t", fmt, "--wrap=none"], json.dumps(doc))

    md = "markdown-simple_tables-multiline_tables-grid_tables+pipe_tables"
    used = set()
    for i, p in enumerate(parts, 1):
        title = as_text([{"t": "Plain", "c": p["title"]}], "plain").strip()
        m = re.match(r"(Appendix\s+)?([A-Z]?\d+[A-Z]?(?:\.\d+)?)\b", title)
        if m:
            name = ("appendix-" if m.group(1) else "") + m.group(2).replace(".", "-").lower()
        else:  # unnumbered part: its position and title
            name = "%02d-" % i + re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:40]
        while name in used:
            name += "-b"
        used.add(name)
        with open(os.path.join(out, name + ".qmd"), "w", encoding="utf-8") as fh:
            fh.write('---\ntitle: "%s"\n---\n\n' % title.replace('"', '\\"'))
            fh.write(as_text(p["blocks"], md))
        print(f"  {name}.qmd  {title}")
    print(f"drafts in {os.path.relpath(out, ROOT)}")


if __name__ == "__main__":
    main()
