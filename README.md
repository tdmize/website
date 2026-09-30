# trentonmize.com

Source for https://www.trentonmize.com, built with [Quarto](https://quarto.org) and served by GitHub Pages from the `docs/` folder.

## How pages map to addresses

Each page's address matches its file:

| File | Address |
|---|---|
| `index.qmd` | www.trentonmize.com/ (and /home) |
| `research.qmd` | /research |
| `research/mize_2019_SocSci.qmd` | /research/mize_2019_SocSci |
| `teaching/cda.qmd` | /teaching/cda |
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
- **R package documentation** (`software/cleanplots_r/`, `software/suest_r/`): written in the R packages themselves. After a package's pkgdown site is rebuilt, run `python tools/pkgdown2qmd.py cleanplots` (or `suest`) to bring the new version in, then render. Don't edit these folders by hand; the tool replaces them. One-time setup for the tool: `python -m pip install beautifulsoup4 pyyaml`.
- **Look of the site**: `theme.scss` (colors, font, Stata output blocks). Menus and sidebars: `_quarto.yml`.

## Building

From the repository folder:

```
quarto render
```

or, in Stata, `do build.do render` (render only) / `do build.do mecompare` (rerun one package's Stata output, then render). Then commit and push, including `docs/`.

`python tools/preview_nostata.py --serve` builds a preview without Stata and serves it at http://127.0.0.1:8765/.
