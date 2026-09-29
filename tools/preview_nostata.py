#!/usr/bin/env python3
"""
preview_nostata.py -- render the site WITHOUT running Stata, for checking
layout, navigation, and prose.

build.do is the real build: it runs the Stata code in the <<dd_do>> blocks and
fills in the output. This script stands in for that step when Stata is not
available (for example when editing pages on another machine). It copies the
repository to a temporary folder, replaces every <<dd_do>> block with the echoed
commands plus a placeholder line, and runs `quarto render` there. Nothing in the
repository itself is touched, so the generated pages committed from the last
real build are left alone.

Usage (from anywhere):
    python tools/preview_nostata.py            # render, print the output folder
    python tools/preview_nostata.py --serve    # ...and serve it on localhost:8765
    python tools/preview_nostata.py --out DIR  # render into DIR instead of a temp folder
"""
import argparse
import http.server
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLACEHOLDER = "(output appears here after build.do runs the code in Stata)"

RE_VERSION = re.compile(r"^[ \t]*<<dd_version:[^>]*>>[ \t]*\r?\n?", re.M)
RE_DO = re.compile(r"<<dd_do(?::[^>]*)?>>\r?\n(.*?)<</dd_do>>", re.S)
RE_GRAPH = re.compile(r"<<dd_graph:[^>]*>>")
RE_DISPLAY = re.compile(r"<<dd_display:[^>]*>>")
RE_OTHER = re.compile(r"<<dd_[a-z_]+(?::[^>]*)?>>")


def fake_dyntext(text: str) -> str:
    """Approximate what dyntext writes, without running Stata."""

    def do_block(m):
        code = m.group(1).rstrip("\n")
        out = []
        for line in code.split("\n"):
            if line.strip() == "":
                continue
            # a continued command: Stata echoes "> " for the continuation
            if out and out[-1].rstrip().endswith("///"):
                out.append("> " + line.strip())
            else:
                out.append(". " + line)
        out.append(PLACEHOLDER)
        out.append("")
        return "\n".join(out)

    text = RE_VERSION.sub("", text)
    text = RE_DO.sub(do_block, text)
    text = RE_GRAPH.sub("*(graph appears here after build.do)*", text)
    text = RE_DISPLAY.sub("*value*", text)
    text = RE_OTHER.sub("", text)
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--serve", action="store_true", help="serve the result on localhost")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--out", help="render into this folder instead of a temp folder")
    args = ap.parse_args()

    work = args.out or tempfile.mkdtemp(prefix="website-preview-")
    if os.path.exists(work) and os.listdir(work):
        shutil.rmtree(work)
    shutil.copytree(
        ROOT, work, dirs_exist_ok=True,
        ignore=shutil.ignore_patterns("docs", ".quarto", ".git", "_site", "build_render.log"),
    )

    n = 0
    base = os.path.join(work, "software")
    for pkg in sorted(os.listdir(base)):
        src = os.path.join(base, pkg, "_src")
        if not os.path.isdir(src):
            continue
        for dirpath, _, files in os.walk(src):
            rel = os.path.relpath(dirpath, src)
            dest_dir = os.path.join(base, pkg) if rel == "." else os.path.join(base, pkg, rel)
            os.makedirs(dest_dir, exist_ok=True)
            for f in files:
                if not f.endswith(".qmd"):
                    continue
                with open(os.path.join(dirpath, f), encoding="utf-8") as fh:
                    text = fh.read()
                with open(os.path.join(dest_dir, f), "w", encoding="utf-8") as fh:
                    fh.write(fake_dyntext(text))
                n += 1
    print(f"faked dyntext on {n} pages in {work}")

    r = subprocess.run(["quarto", "render"], cwd=work)
    if r.returncode != 0:
        sys.exit(r.returncode)
    site = os.path.join(work, "docs")
    print(f"\nrendered: {site}")

    if args.serve:
        os.chdir(site)
        handler = http.server.SimpleHTTPRequestHandler
        with http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler) as httpd:
            print(f"serving http://127.0.0.1:{args.port}/  (Ctrl-C to stop)")
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                pass


if __name__ == "__main__":
    main()
