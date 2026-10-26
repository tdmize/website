# trentonmize.com

Source for https://www.trentonmize.com, built with [Quarto](https://quarto.org) and served by GitHub Pages from the `docs/` folder.

## How pages map to addresses

Each page's address matches its file:

| File | Address |
|---|---|
| `index.qmd` | www.trentonmize.com/ (and /home) |
| `research.qmd` | /research |
| `research/mize_2019_SocSci.qmd` | /research/mize_2019_SocSci |
| `teaching/cda/index.qmd` | /teaching/cda/ (and /teaching/cda) |
| `teaching/cda/02/2-1-marginal-effects.qmd` | /teaching/cda/02/2-1-marginal-effects |
| `software/mecompare/index.qmd` | /software/mecompare |
| `software/mecompare/interactions/index.qmd` | /software/mecompare/interactions/ |

Keep file names exactly as they are (including capital letters): links elsewhere depend on them.

Every address on the old Google Site has a page here, including pages that are not in the menus (the paper pages under `research/`, `teaching/pred`, `teaching/nonlinear`).

The older software pages (`software/*-old`) are kept only so old links keep working: nothing on the site links to them and they are left out of the site search. Link to the current pages under `software/<pkg>/` instead.

Some addresses forward elsewhere: `software/mecompare-old` goes to `software/mecompare`, and `software/mecompare-old/mecompare_exs` and `software/mecompare-old/gifs` go to their new places under `research/mize_doan_long_2019_SM/`.

Images are in `images/`.

## Editing

- **Ordinary pages** (home, research, teaching, ...): edit the `.qmd` file, then render.
- **Stata documentation** (`software/<pkg>/`): edit only the files in `software/<pkg>/_src/`, then run `build.do` in Stata, which runs the Stata code, fills in the output, and renders. The `.qmd` files next to `_src/` are generated.
- **Teaching sections with Stata code** (`teaching/<course>/<section>/`, e.g. `teaching/cda/02/`): edit only the files in `_src/`, then run `build_teaching.do` in Stata (`do build_teaching.do cda 02`), which runs the Stata code, fills in the output, and renders. A new section is drafted from its Word slides with `python tools/slides2qmd.py cda 03 "path/to/slides.docx"` (writes drafts to `teaching/cda/03/_draft/`; copy them into `_src/` and put the do-file code in place of each `slide-output` block). One-time setup for the tool: `python -m pip install lxml`. Pages that use restricted data switch to its folder in hidden code (fastcd `c rarc` for Stata, the full path for R), so the data never goes in the repository. Each example has a Stata tab and an R tab; Quarto runs the R code when it renders, and saves the results in `_freeze/` (commit it), so a page's R code reruns only when that page changes. One-time setup for the R tabs, in R: `install.packages(c("knitr", "rmarkdown", "haven", "dplyr", "sjmisc", "ggplot2", "modelsummary", "marginaleffects", "sandwich", "lme4", "survey", "lspline", "olsrr"))` and `remotes::install_github("tdmize/cleanplots")`.
- **R package documentation** (`software/cleanplots_r/`, `software/suest_r/`): written in the R packages themselves. After a package's pkgdown site is rebuilt, run `python tools/pkgdown2qmd.py cleanplots` (or `suest`) to bring the new version in, then render. Don't edit these folders by hand; the tool replaces them. One-time setup for the tool: `python -m pip install beautifulsoup4 pyyaml`.
- **Look of the site**: `theme.scss` (colors, font, Stata output blocks). Menus and sidebars: `_quarto.yml`.

## Building

From the repository folder:

```
quarto render
```

or, in Stata, `do build.do render` (render only) / `do build.do mecompare` (rerun one package's Stata output, then render) / `do build_teaching.do cda 02` (rerun one teaching section's Stata output, then render). Then commit and push, including `docs/`.

`python tools/preview_nostata.py --serve` builds a preview without Stata and serves it at http://127.0.0.1:8765/.
