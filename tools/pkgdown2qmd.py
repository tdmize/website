"""
pkgdown2qmd.py -- put an R package's documentation on this site.

Downloads the package's built pkgdown site (the gh-pages branch of
github.com/tdmize/<pkg>), turns every page into a Quarto page under
software/<pkg>_r/ (same look and menus as the Stata packages), copies its
figures, and updates that package's entry in the Software menu (_quarto.yml).

The R package stays the one place its documentation is written; rerun this
after the package's pkgdown site is rebuilt, then render the website.

Run from the website folder:
    python tools/pkgdown2qmd.py cleanplots
    python tools/pkgdown2qmd.py suest

The package changelog (NEWS.md) stays on GitHub and is not brought in.

Needs Quarto and two Python packages
(one time: python -m pip install beautifulsoup4 pyyaml).
"""
import io
import json
import os
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

try:
    import yaml
    from bs4 import BeautifulSoup, Comment
except ImportError:
    sys.exit("First run:  python -m pip install beautifulsoup4 pyyaml")

QUARTO = shutil.which("quarto")

SKIP = {"404.html", "authors.html", "LICENSE-text.html", "LICENSE.html", "DEVELOPMENT.html"}
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp")
STATA_PKGS = {"balanceplot", "cleanplots", "desctable", "irt_coef", "irt_me", "lca_entropy", "mecompare",
              "meinequality", "metest", "sgmediation2", "suest2", "totalme", "usetdm"}


def download(pkg, dest):
    url = f"https://codeload.github.com/tdmize/{pkg}/zip/refs/heads/gh-pages"
    data = urllib.request.urlopen(url, timeout=60).read()
    zipfile.ZipFile(io.BytesIO(data)).extractall(dest)
    return os.path.join(dest, f"{pkg}-gh-pages")


def rel(from_page, to_path):
    """Relative link from one page (site-relative path) to another."""
    return posixpath.relpath(to_path, posixpath.dirname(from_page) or ".")


def fix_href(href, page, pkg, pages, aliases):
    """page is the pkgdown-relative path of the current page (e.g. reference/x.html)."""
    if not href or href.startswith("#") or href.startswith("mailto:"):
        return href
    u = urllib.parse.urlsplit(href)
    frag = ("#" + u.fragment) if u.fragment else ""
    host = u.netloc.lower()
    news = f"https://github.com/tdmize/{pkg}/blob/main/NEWS.md"
    own = None
    if host == "tdmize.github.io" and u.path.startswith(f"/{pkg}/"):
        own = u.path[len(f"/{pkg}/"):]
    if host == "tdmize.github.io" and u.path.rstrip("/") == f"/{pkg}":
        own = ""
    if host in ("www.trentonmize.com", "trentonmize.com"):
        parts = u.path.strip("/").split("/")
        if len(parts) < 2 or parts[0] != "software":
            return href
        name, rest = parts[1], "/".join(parts[2:])
        if name == f"{pkg}_r":
            own = rest
        else:
            qmd = (rest[:-5] + ".qmd") if rest.endswith(".html") else posixpath.join(rest, "index.qmd")
            qmd = posixpath.join("software", name, qmd)
            if os.path.exists(qmd):
                return "/" + qmd + frag
            if name in STATA_PKGS or name.endswith("_r"):
                return f"/software/{name}/index.qmd"
            return href
    if own is not None:
        target = own or "index.html"
        if target.endswith("/"):
            target += "index.html"
        if target.startswith("news/"):
            return news
        target = aliases.get(target, target)
        return rel(page, target) + frag if target in pages else href
    if not u.scheme and not host:
        target = posixpath.normpath(posixpath.join(posixpath.dirname(page), u.path))
        if target.startswith("news/"):
            return news
        name = posixpath.basename(target)
        if name in ("LICENSE-text.html", "LICENSE.html"):
            return f"https://github.com/tdmize/{pkg}/blob/main/LICENSE"
        if name == "authors.html":
            return None
        if target in aliases:
            return rel(page, aliases[target]) + frag
        return href
    return href


def code_segments(pre):
    """Split a pkgdown code block into code lines, output lines, and plots."""
    segs = []

    def add(kind, value):
        if segs and segs[-1][0] == kind and kind != "img":
            segs[-1][1].append(value)
        else:
            segs.append((kind, [value] if kind != "img" else value))

    code = pre.find("code") or pre
    if code.find(class_=re.compile(r"^r-(in|out|plt|err|wrn|msg)")):
        for sp in code.find_all("span", recursive=False):
            cls = sp.get("class") or []
            if "r-plt" in cls:
                img = sp.find("img")
                if img is not None:
                    add("img", img.get("src"))
            elif "r-in" in cls:
                add("code", sp.get_text())
            else:
                add("out", re.sub(r"^#>\s?", "", sp.get_text()))
    else:
        for line in code.get_text().split("\n"):
            if line.startswith("#>"):
                add("out", re.sub(r"^#>\s?", "", line))
            else:
                add("code", line)
    out = []
    for kind, v in segs:
        if kind == "img":
            out.append((kind, v))
            continue
        while v and not v[0].strip():
            v.pop(0)
        while v and not v[-1].strip():
            v.pop()
        if v:
            out.append((kind, v))
    return out


def segments_md(segs, lang="r"):
    md, i = [], 0
    while i < len(segs):
        kind, v = segs[i]
        if kind == "code":
            block = f"```{lang}\n" + "\n".join(v) + "\n```"
            if i + 1 < len(segs) and segs[i + 1][0] == "out":
                out = "```{.r-output}\n" + "\n".join(segs[i + 1][1]) + "\n```"
                md.append("::: {.r-run}\n" + block + "\n" + out + "\n:::")
                i += 2
                continue
            md.append(block)
        elif kind == "out":
            md.append("::: {.r-run}\n```{.r-output}\n" + "\n".join(v) + "\n```\n:::")
        else:
            md.append(f"![]({v})")
        i += 1
    return "\n\n".join(md)


def to_markdown(html):
    r = subprocess.run([QUARTO, "pandoc", "-f", "html", "-t",
                        "markdown-raw_html-native_divs-native_spans-bracketed_spans-link_attributes"
                        "-header_attributes-fenced_divs-smart-simple_tables-multiline_tables-grid_tables",
                        "--wrap=none"], input=html, capture_output=True, text=True, encoding="utf-8")
    if r.returncode:
        raise RuntimeError(r.stderr)
    return r.stdout


def convert(site, page, pkg, pages, aliases):
    soup = BeautifulSoup(open(os.path.join(site, page), encoding="utf-8").read(), "html.parser")
    main = soup.find("main")
    h1 = main.find("h1")
    for a in h1.find_all("a", class_="anchor"):
        a.decompose()
    title = h1.get_text(" ", strip=True)
    header = main.find(class_="page-header")
    (header or h1).decompose()
    for el in main.find_all(string=lambda t: isinstance(t, Comment)):
        el.extract()
    for el in main.select("a.anchor, small.dont-index, .d-none, script, style"):
        el.decompose()
    blocks = []
    for pre in main.find_all("pre"):
        wrap = pre.parent if pre.parent.name == "div" and "sourceCode" in (pre.parent.get("class") or []) else pre
        lang = "stata" if "stata" in (pre.get("class") or []) else "r"
        blocks.append(segments_md(code_segments(pre), lang))
        wrap.replace_with(soup.new_string(f"@@BLOCK{len(blocks) - 1}@@"))
    for a in main.find_all("a"):
        h = fix_href(a.get("href"), page, pkg, pages, aliases)
        if h is None:
            a.unwrap()
        else:
            a.attrs = {"href": h}
    for img in main.find_all("img"):
        img.attrs = {"src": img.get("src", ""), "alt": img.get("alt", "")}
    md = to_markdown(str(main))
    md = re.sub(r"@@BLOCK(\d+)@@", lambda m: "\n\n" + blocks[int(m.group(1))] + "\n\n", md)
    md = re.sub(r"(?m)^[ \t\u00a0]+$", "", md)
    md = re.sub(r"\n{3,}", "\n\n", md).strip() + "\n"
    return title, md


def article_sections(site):
    """(section title, [article pages]) in the order of the package's articles index."""
    path = os.path.join(site, "articles", "index.html")
    if not os.path.exists(path):
        return []
    main = BeautifulSoup(open(path, encoding="utf-8").read(), "html.parser").find("main")
    out = []
    for sec in main.find_all("div", class_="section"):
        h = sec.find(["h2", "h3"])
        arts = ["articles/" + a["href"].split("#")[0] for a in sec.select("dt a[href]")
                if "/" not in a["href"] and ":" not in a["href"]]
        out.append((h.get_text(" ", strip=True) if h else "Articles", arts))
    return out


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python tools/pkgdown2qmd.py <package>   (e.g. cleanplots)")
    pkg = sys.argv[1]
    if not os.path.exists("_quarto.yml"):
        sys.exit("run this from the website folder (cd ~/website)")
    if QUARTO is None:
        sys.exit("Quarto was not found; check that  quarto --version  works in this window")
    out = os.path.join("software", f"{pkg}_r")
    tmp = tempfile.mkdtemp()
    site = download(pkg, tmp)
    pages = []
    for root, dirs, files in os.walk(site):
        dirs[:] = [d for d in dirs if d not in ("deps", ".git")]
        for f in files:
            p = os.path.relpath(os.path.join(root, f), site).replace(os.sep, "/")
            if f.endswith(".html") and f not in SKIP and (p == "index.html" or p.split("/")[0] in ("articles", "reference")):
                pages.append(p)
    aliases = {}
    for p in list(pages):
        html = open(os.path.join(site, p), encoding="utf-8").read()
        if "<main" not in html:
            m = re.search(r'http-equiv="refresh" content="0;\s*URL=([^"]+)"', html, re.I)
            if m:
                t = m.group(1)
                t = t.split(f"/{pkg}/", 1)[1] if f"/{pkg}/" in t else posixpath.normpath(posixpath.join(posixpath.dirname(p), t))
                aliases[p] = t
            pages.remove(p)
    # GitHub keeps pages the package no longer has; keep only the ones its site lists now
    listed = set()
    yml = os.path.join(site, "pkgdown.yml")
    if os.path.exists(yml):
        meta = yaml.safe_load(open(yml, encoding="utf-8")) or {}
        listed |= {"articles/" + v for v in (meta.get("articles") or {}).values()}
    ref_index = os.path.join(site, "reference", "index.html")
    if os.path.exists(ref_index):
        for a in BeautifulSoup(open(ref_index, encoding="utf-8").read(), "html.parser").find_all("a", href=True):
            h = a["href"].split("#")[0]
            if h.endswith(".html") and "/" not in h and ":" not in h:
                listed.add("reference/" + h)
    stale = [p for p in pages if (p.startswith("articles/") and p != "articles/index.html" and p not in listed)
             or (p.startswith("reference/") and p != "reference/index.html" and p not in listed
                 and not p.endswith("-package.html"))]
    pages = sorted(p for p in pages if p not in stale)
    if stale:
        print(f"{pkg}: skipped {len(stale)} old pages no longer in the package: " + ", ".join(stale))
    if os.path.isdir(out):
        shutil.rmtree(out)
    titles = {}
    for p in pages:
        title, md = convert(site, p, pkg, set(pages), aliases)
        titles[p] = title
        dest = os.path.join(out, p[:-5] + ".qmd")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as fh:
            fh.write(f"---\ntitle: {json.dumps(title, ensure_ascii=False)}\n---\n\n{md}")
    n_img = 0
    for root, dirs, files in os.walk(site):
        dirs[:] = [d for d in dirs if d not in ("deps", ".git")]
        for f in files:
            if f.lower().endswith(IMAGE_EXT):
                p = os.path.relpath(os.path.join(root, f), site)
                dest = os.path.join(out, p)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.copy(os.path.join(root, f), dest)
                n_img += 1
    sections = article_sections(site)
    shutil.rmtree(tmp, ignore_errors=True)

    # Software menu entry for this package
    base = f"software/{pkg}_r/"
    q = lambda p: base + p[:-5] + ".qmd"
    contents = [{"text": "Overview", "href": q("index.html")}]
    main_article = f"articles/{pkg}.html"
    if main_article in titles:
        contents.append({"text": "Getting started", "href": q(main_article)})
    seen = {main_article, "articles/index.html"}
    for name, arts in sections:
        arts = [a for a in arts if a in titles and a not in seen]
        seen.update(arts)
        if len(arts) == 1:
            contents.append({"text": titles[arts[0]], "href": q(arts[0])})
        elif arts:
            contents.append({"section": name, "href": q(arts[0]),
                             "contents": [{"text": titles[a], "href": q(a)} for a in arts]})
    others = [p for p in pages if p.startswith("articles/") and p not in seen]
    if others:
        contents.append({"section": "Examples", "href": q(others[0]),
                         "contents": [{"text": titles[p], "href": q(p)} for p in others]})
    refs = [p for p in pages if p.startswith("reference/") and p != "reference/index.html"]
    if refs:
        contents.append({"section": "Function reference", "href": q("reference/index.html"),
                         "contents": [{"text": posixpath.basename(p)[:-5], "href": q(p)} for p in refs]})
    entry = {"section": f"{pkg} (R)", "href": q("index.html"), "contents": contents}

    txt = open("_quarto.yml", encoding="utf-8").read()
    head = txt[:txt.index("project:")]
    cfg = yaml.safe_load(txt)
    for sb in cfg["website"]["sidebar"]:
        if sb.get("id") != "software":
            continue
        items = sb["contents"]
        k = next((i for i, it in enumerate(items)
                  if it.get("text") == f"{pkg} (R)" or it.get("section") == f"{pkg} (R)"), None)
        if k is None:
            items.append(entry)
        else:
            items[k] = entry
    with open("_quarto.yml", "w", encoding="utf-8") as fh:
        fh.write(head + yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True, width=100))
    print(f"{pkg}: {len(pages)} pages and {n_img} images written to {out}/; Software menu updated.")
    print("Next: quarto render")


if __name__ == "__main__":
    main()
