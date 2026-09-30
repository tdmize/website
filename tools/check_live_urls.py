"""
check_live_urls.py -- check that every address from the old Google Site works.

Run after switching www.trentonmize.com to the new site:
    python tools/check_live_urls.py

Prints any address that doesn't open (or still shows the old Google Site),
then a summary. Only reads the site.
"""
import sys
import urllib.error
import urllib.request

BASE = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "https://www.trentonmize.com"

PATHS = [
    "/",
    "/about",
    "/cv",
    "/help",
    "/home",
    "/research",
    "/research/benard_berg_mize_2017_SPQ",
    "/research/benard_mize_2016_HCST",
    "/research/doan_mize_2020_SocSci",
    "/research/doan_mize_or_HSP_2025",
    "/research/han_mize_2026_ssr",
    "/research/kaufman_et_al_2024_SCur",
    "/research/manago_mize_2022_SSR",
    "/research/manago_mize_doan_2022_SM",
    "/research/managomize2024",
    "/research/mize_2015_SocComp",
    "/research/mize_2016_ASR",
    "/research/mize_2017_SSM",
    "/research/mize_2019_SocPro",
    "/research/mize_2019_SocSci",
    "/research/mize_2024_socius",
    "/research/mize_2025_spq",
    "/research/mize_2026_ores",
    "/research/mize_doan_2023_IT",
    "/research/mize_doan_long_2019_SM",
    "/research/mize_han_hdma_2025",
    "/research/mize_han_socsci_2025",
    "/research/mize_kaufman_petts_2021_Socius",
    "/research/mize_kincaid_asr_2025",
    "/research/mize_manago_2018_ASR",
    "/research/mize_manago_2018_SCur",
    "/research/mize_manago_2022_SSR",
    "/research/mize_myers_2011_JURO",
    "/research/petts_et_al_JMF_2025",
    "/research/petts_kaufman_mize_2023_JMF",
    "/research/petts_mize_kaufman_2022_SSR",
    "/research/petts_mize_kaufman_2025_CWF",
    "/research/quadlin_mize_2026_asr",
    "/resources",
    "/resources/it",
    "/software",
    "/software/balanceplot",
    "/software/cleanplots",
    "/software/cleanplots-old",
    "/software/cleanplots-old/help",
    "/software/cleanplots_r",
    "/software/desctable",
    "/software/desctable-old",
    "/software/desctable-old/help",
    "/software/irt_coef",
    "/software/irt_coef-old",
    "/software/irt_coef-old/irt_coef_help",
    "/software/irt_me",
    "/software/irt_me-old",
    "/software/irt_me-old/irt_me_help",
    "/software/lca_entropy",
    "/software/mecompare",
    "/software/mecompare-old",
    "/software/mecompare-old/gifs",
    "/software/mecompare-old/mecompare_exs",
    "/software/meinequality",
    "/software/metest",
    "/software/sgmediation2",
    "/software/suest2",
    "/software/totalme",
    "/software/usetdm",
    "/teaching",
    "/teaching/cda",
    "/teaching/cdash",
    "/teaching/cdaws",
    "/teaching/dataviz",
    "/teaching/dmv",
    "/teaching/dmv/r-output",
    "/teaching/dvs",
    "/teaching/em",
    "/teaching/int",
    "/teaching/irt",
    "/teaching/lvm",
    "/teaching/mcapsi",
    "/teaching/miss",
    "/teaching/nonlinear",
    "/teaching/pred",
    "/teaching/sew",
    "/teaching/spgrad",
    "/teaching/spug",
    "/teaching/stata",
    "/teaching/surveys",
    "/teaching/twm",
    "/teaching/workflow",
    "/software/suest_r/",
    "/software/cleanplots_r/",
    "/software/meinequality_r/",
    "/software/totalme_r/",
    "/software/mecompare/interactions/",
    "/research/mize_doan_long_2019_SM/gifs",
]

failed = []
for p in PATHS:
    url = BASE + p
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read()
            if r.status != 200:
                failed.append((url, r.status))
            elif b"/atari/" in body:
                failed.append((url, "still the old Google Site"))
    except urllib.error.HTTPError as e:
        failed.append((url, e.code))
    except Exception as e:
        failed.append((url, str(e)))

for url, status in failed:
    print(f"NOT OK  {status}  {url}")
print(f"{len(PATHS) - len(failed)} of {len(PATHS)} addresses work.")
