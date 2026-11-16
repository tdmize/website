"""
check_links.py -- test every outside link in a folder of .qmd pages.

    python tools/check_links.py teaching/cda

Reads the source pages (the _src folders and the course page), opens each
outside address once, and prints three lists: links that are broken, links
that now redirect to a different site, and links whose site refused the check
(open those by hand). Only reads the pages and the sites.
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
# redirects to these hosts are expected (DOI resolvers, Google Drive, etc.)
EXPECTED_HOSTS = ("doi.org", "drive.google.com", "accounts.google.com",
                  "docs.google.com", "login.", "idp.", "shibboleth", "sso.")

files = [f for f in glob.glob(os.path.join(ROOT, "**", "*.qmd"), recursive=True)
         if "_src" in f.replace("\\", "/").split("/") or
         os.path.dirname(f).replace("\\", "/") == ROOT.rstrip("/")]

where = {}
for f in sorted(files):
    with open(f, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for u in re.findall(r"https?://[^\s\"'<>\]`]+", line):
                while u and (u[-1] in ".,;:*" or
                             (u[-1] == ")" and u.count("(") < u.count(")"))):
                    u = u[:-1]
                where.setdefault(u, []).append(f"{f.replace(os.sep, '/')}:{n}")


def host(u):
    h = urlparse(u).netloc.lower()
    return h[4:] if h.startswith("www.") else h


def check(u):
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(u, method=method, headers={"User-Agent": UA})
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

broken, moved, refused = [], [], []
for u, code, final, err in results:
    if code is None or code in (404, 410):
        broken.append((u, code or err))
    elif code in (401, 403, 405, 406, 429) or code >= 500:
        refused.append((u, code))
    elif host(final) != host(u) and not any(h in host(final) for h in EXPECTED_HOSTS):
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
print(f"\nChecked {len(where)} addresses in {len(files)} pages under {ROOT}.")
