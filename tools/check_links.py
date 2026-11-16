"""
check_links.py -- test every outside link in a folder of .qmd pages.

    python tools/check_links.py teaching/cda

Reads the source pages (the _src folders and the course page), opens each
outside address once, and prints three lists: links that are broken, links
that now redirect to a different site, and links whose site refused the check
(open those by hand). Journal sites usually refuse scripts, so those are only
counted. Only reads the pages and the sites.
"""
import concurrent.futures
import glob
import os
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

ROOT = sys.argv[1] if len(sys.argv) > 1 else "teaching/cda"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
DOI_HOSTS = ("doi.org", "dx.doi.org")
JOURNAL_HOSTS = ("doi.org", "journals.sagepub.com", "onlinelibrary.wiley.com",
                 "sciencedirect.com", "tandfonline.com", "academic.oup.com",
                 "jstor.org", "cambridge.org", "link.springer.com",
                 "psycnet.apa.org", "doi.apa.org")

files = [f for f in glob.glob(os.path.join(ROOT, "**", "*.qmd"), recursive=True)
         if "_src" in f.replace("\\", "/").split("/") or
         os.path.dirname(f).replace("\\", "/") == ROOT.rstrip("/")]

MD_LINK = re.compile(r"\]\((https?://[^\s()]+(?:\([^\s()]*\)[^\s()]*)*)\)")
BARE = re.compile(r"https?://[^\s\"'<>\]`()]+")

where = {}
for f in sorted(files):
    with open(f, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            urls = MD_LINK.findall(line)
            urls += BARE.findall(MD_LINK.sub("", line))
            for u in urls:
                u = u.rstrip(".,;:*\\")
                where.setdefault(u, []).append(f"{f.replace(os.sep, '/')}:{n}")


def host(u):
    h = urlparse(u).netloc.lower().split(":")[0]
    return h[4:] if h.startswith("www.") else h


def check(u):
    test = u
    # Stata adds .dta to dataset addresses given without one
    if host(u) == "tdmize.github.io" and not os.path.splitext(urlparse(u).path)[1]:
        test = u + ".dta"
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(test, method=method, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return u, r.status, r.geturl(), ""
        except urllib.error.HTTPError as e:
            if method == "HEAD":
                continue
            return u, e.code, u, ""
        except Exception as e:
            if method == "HEAD":
                continue
            return u, None, u, type(e).__name__ + ": " + str(e)[:80]


with concurrent.futures.ThreadPoolExecutor(max_workers=16) as ex:
    results = list(ex.map(check, sorted(where)))

broken, moved, refused, journals = [], [], [], 0
for u, code, final, err in results:
    if code is None or code in (404, 410):
        broken.append((u, code or err))
    elif code in (401, 403, 405, 406, 429) or code >= 500:
        if any(host(u).endswith(h) for h in JOURNAL_HOSTS):
            journals += 1
        else:
            refused.append((u, code))
    elif host(u) not in DOI_HOSTS and host(final) != host(u):
        moved.append((u, final))


def show(title, rows, fmt):
    print(f"\n== {title}: {len(rows)}")
    for row in rows:
        print("  " + fmt(row))
        for w in where[row[0]]:
            print("      " + w)


show("BROKEN", broken, lambda r: f"{r[0]}  [{r[1]}]")
show("REDIRECTS TO A DIFFERENT SITE", moved, lambda r: f"{r[0]}\n      -> {r[1]}")
show("SITE REFUSED THE CHECK (open by hand)", refused, lambda r: f"{r[0]}  [{r[1]}]")
print(f"\n{journals} journal links refused the check (normal for journal sites).")
print(f"Checked {len(where)} addresses in {len(files)} pages under {ROOT}.")
