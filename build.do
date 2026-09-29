*! build.do -- regenerate the Stata output in the documentation pages, then
*! render the website with Quarto.
*!
*! Run it from the repository root (the folder that contains _quarto.yml):
*!
*!     cd "C:\path\to\website"
*!     do build.do                        // every package, then quarto render
*!     do build.do mecompare              // one package, then quarto render
*!     do build.do software/mecompare/_src/examples/mediation.qmd
*!                                        // one page (e.g. after a wording edit),
*!                                        // then quarto render
*!     do build.do mecompare norender     // regenerate output only
*!     do build.do render                 // quarto render only, no Stata output
*!
*! What it does.  For every .qmd page in  software/<pkg>/_src/  (and its subfolders) it
*! runs -dyntext-, which executes the Stata code inside  <<dd_do>> ... <</dd_do>>
*! tags and writes the finished page -- code and output filled in -- to  software/<pkg>/
*! under the same relative name.  Then it calls  quarto render, which builds
*! the site into  docs/  (the folder GitHub Pages serves).  Commit and push.
*!
*! (Comment lines in this file must not contain the two characters slash-star,
*! which open a block comment in Stata even inside a comment.)
*!
*! Only edit the files in  _src/.  The .qmd files next to them are generated
*! and are overwritten on every build.
*!
*! Requirements: Stata 16+ (the floor for mecompare and its siblings; dyntext
*! itself needs 15); Quarto installed and on the PATH
*! (https://quarto.org/docs/download/) -- or put its full path in the -quarto-
*! local below.  Whatever version of each command is first on the adopath is
*! the version that produces the output; the build log records it.
*!
*! The -version- line below must stay at 16 or higher.  Under version 15 the
*! documented commands fail with r(509) even though each declares version 16
*! itself: the behaviour is keyed to the version set at the do-file level.

version 16
set more off
set linesize 100
set rmsg off

* Quarto executable.  Leave as "quarto" when it is on the PATH.  Otherwise the
* full path, e.g.  local quarto `"C:\Users\trent\AppData\Local\Programs\Quarto\bin\quarto.exe"'
local quarto "quarto"

* Python executable, used to render the installed help files as web pages
* (tools/sthlp2qmd.py).  "python" or "py" on most Windows installs.
local python "python"

* Packages documented on the site (folder names).
local all_pkgs "mecompare suest2 metest meinequality totalme balanceplot cleanplots desctable irt_coef irt_me lca_entropy sgmediation2 usetdm"

* Render one installed help file as <section>/<page>.qmd  (the page is written
* next to the generated pages, not under _src/, and is overwritten each build)
capture program drop _build_help
program define _build_help
    args python name section page title ext
    if "`ext'" == "" local ext "sthlp"
    capture findfile `name'.`ext'
    if _rc {
        di as err "  `name'.`ext' not found on the adopath; `section'/`page'.qmd left as is"
        exit
    }
    local src "`r(fn)'"
    di as txt `"  sthlp2qmd `name'.`ext'  ->  software/`section'/`page'.qmd"'
    capture erase "build_help.log"
    !`python' tools/sthlp2qmd.py "`src'" "software/`section'/`page'.qmd" --cmd `section' --title "`title'" > build_help.log 2>&1
    capture confirm file "build_help.log"
    if !_rc  type "build_help.log"
end

* ---------------------------------------------------------------- arguments --
local pkgs   ""
local pages  ""
local dyn    1
local render 1
foreach tok in `0' {
    if `:list posof "`tok'" in all_pkgs' {
        local pkgs "`pkgs' `tok'"
    }
    else if "`tok'" == "all" {
        local pkgs "`all_pkgs'"
    }
    else if strpos("`tok'", ".qmd") {
        local pages "`pages' `tok'"
    }
    else if "`tok'" == "norender" {
        local render 0
    }
    else if "`tok'" == "render" {
        local dyn 0
    }
    else {
        di as err "build.do: unknown argument `tok'"
        di as err "usage:  do build.do [pkgname ...|all] [pkg/_src/page.qmd ...] [norender]"
        di as err "        do build.do render"
        exit 198
    }
}
if "`pkgs'" == "" & "`pages'" == "" & `dyn' local pkgs "`all_pkgs'"

* --------------------------------------------------------------- root check --
capture confirm file "_quarto.yml"
if _rc {
    di as err "build.do must be run from the repository root (the folder that contains _quarto.yml)."
    di as err `"In Stata:   cd "<path to the repo>"   and then   do build.do"'
    exit 601
}
local root "`c(pwd)'"

* ---------------------------------------------- 1. regenerate Stata output --
if `dyn' {
    * record which version of each command produces the output
    di as txt _n "{hline 72}" _n "build.do: commands on the adopath" _n "{hline 72}"
    foreach c of local all_pkgs {
        if "`c'" == "cleanplots" {          // a scheme, not a command
            capture findfile scheme-cleanplots.scheme
            if _rc di as err "  scheme-cleanplots.scheme not found on the adopath"
            else   di as txt "  scheme-cleanplots.scheme: `r(fn)'"
            continue
        }
        capture noisily which `c'
        if _rc di as err "  `c' not found on the adopath"
    }

    * single pages, given as  software/pkg/_src/page.qmd  or  pkg/_src/page.qmd  (from the root)
    foreach pg of local pages {
        local pg : subinstr local pg "\" "/", all
        if substr("`pg'", 1, 9) == "software/"  local pg = substr("`pg'", 10, .)
        if !strpos("`pg'", "/") {
            di as err "build.do: give the page as a path from the repository root, e.g. software/mecompare/_src/getting-started.qmd"
            exit 198
        }
        local pkg = substr("`pg'", 1, strpos("`pg'", "/") - 1)
        local rel = substr("`pg'", strpos("`pg'", "/") + 1, .)
        if substr("`rel'", 1, 5) == "_src/"  local rel = substr("`rel'", 6, .)
        if !`:list posof "`pkg'" in all_pkgs' {
            di as err "build.do: `pg' is not under one of: `all_pkgs'"
            exit 198
        }
        capture confirm file "`root'/software/`pkg'/_src/`rel'"
        if _rc {
            di as err "build.do: source page not found: software/`pkg'/_src/`rel'"
            exit 601
        }
        di as txt _n "{hline 72}" _n "build.do: software/`pkg'/_src/`rel'  ->  software/`pkg'/`rel'" _n "{hline 72}"
        cd "`root'/software/`pkg'"
        capture mkdir fig
        est clear
        if strpos("`rel'", "/") {
            local sub = substr("`rel'", 1, strpos("`rel'", "/") - 1)
            capture mkdir "`sub'"
        }
        dyntext "_src/`rel'", saving("`rel'") replace
        cd "`root'"
    }

    foreach p of local pkgs {
        di as txt _n "{hline 72}" _n "build.do: `p'" _n "{hline 72}"

        * help files -> web pages (from the installed .sthlp, via python)
        if "`p'" == "mecompare" {
            _build_help "`python'" mecompare mecompare help "mecompare help file"
        }
        else if "`p'" == "metest" {
            _build_help "`python'" metest metest help "metest help file"
        }
        else if "`p'" == "suest2" {
            _build_help "`python'" suest2 suest2 help "suest2 help file"
        }
        else if "`p'" == "meinequality" {
            _build_help "`python'" meinequality meinequality help "meinequality help file"
        }
        else if "`p'" == "totalme" {
            _build_help "`python'" totalme totalme help "totalme help file"
        }
        else if "`p'" == "balanceplot" {
            _build_help "`python'" balanceplot balanceplot help "balanceplot help file"
        }
        else if "`p'" == "cleanplots" {
            _build_help "`python'" cleanplots cleanplots help "cleanplots help file"
        }
        else if "`p'" == "desctable" {
            _build_help "`python'" desctable desctable help "desctable help file"
        }
        else if "`p'" == "irt_coef" {
            _build_help "`python'" irt_coef irt_coef help "irt_coef help file"
        }
        else if "`p'" == "irt_me" {
            _build_help "`python'" irt_me irt_me help "irt_me help file"
        }
        else if "`p'" == "lca_entropy" {
            _build_help "`python'" lca_entropy lca_entropy help "lca_entropy help file"
        }
        else if "`p'" == "sgmediation2" {
            _build_help "`python'" sgmediation2 sgmediation2 help "sgmediation2 help file" hlp
        }
        else if "`p'" == "usetdm" {
            _build_help "`python'" usetdm usetdm help "usetdm help file"
        }

        cd "`root'/software/`p'"
        capture mkdir fig                 // for graphs exported by the pages
        est clear

        * pages at the top level of _src/
        local files : dir "_src" files "*.qmd"
        foreach f of local files {
            di as txt `"  dyntext _src/`f'  ->  `f'"'
            dyntext "_src/`f'", saving("`f'") replace
        }

        * pages one folder down, e.g. _src/examples/  ->  examples/
        local subs : dir "_src" dirs "*"
        foreach s of local subs {
            if "`s'" == "." | "`s'" == ".." continue
            capture mkdir "`s'"
            local files : dir "_src/`s'" files "*.qmd"
            foreach f of local files {
                di as txt `"  dyntext _src/`s'/`f'  ->  `s'/`f'"'
                dyntext "_src/`s'/`f'", saving("`s'/`f'") replace
            }
        }
        cd "`root'"
    }
}

* ------------------------------------------------------- 2. quarto render --
if `render' {
    di as txt _n "{hline 72}" _n "build.do: quarto render" _n "{hline 72}"
    capture erase "build_render.log"
    !`quarto' render > build_render.log 2>&1
    capture confirm file "build_render.log"
    if !_rc type "build_render.log"

    * tell GitHub Pages not to run the site through Jekyll
    capture confirm file "docs/.nojekyll"
    if _rc {
        tempname fh
        capture file open `fh' using "docs/.nojekyll", write replace
        capture file close `fh'
    }
    di as txt _n "Site rendered to  `root'/docs/  -- open docs/software/mecompare/index.html to check,"
    di as txt `"then commit and push:   git add -A  &&  git commit -m "rebuild site"  &&  git push"'
}

di as res _n "build.do: done."
