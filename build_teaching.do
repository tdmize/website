*! build_teaching.do -- run the Stata code in the teaching pages, then render
*! the website with Quarto.  (The software pages have their own build.do.)
*!
*! Run it from the repository root (the folder that contains _quarto.yml):
*!
*!     do build_teaching.do cda 02            // one course section, then quarto render
*!     do build_teaching.do cda 02 03         // several sections of a course
*!     do build_teaching.do cda all           // every section of a course
*!     do build_teaching.do cda 02 norender   // regenerate output only
*!     do build_teaching.do teaching/cda/02/_src/2-1-marginal-effects.qmd
*!                                            // one page, then quarto render
*!     do build_teaching.do render            // quarto render only
*!
*! What it does.  For every .qmd page in  teaching/<course>/<section>/_src/
*! (and one folder down) it runs -dyntext-, which executes the Stata code inside
*! <<dd_do>> ... <</dd_do>> tags and writes the finished page to
*! teaching/<course>/<section>/ under the same relative name.  Each page starts
*! from an empty dataset, so each page loads its own data.  Then it calls
*! quarto render, which builds the site into docs/.  Commit and push.
*!
*! Only edit the files in _src/.  The .qmd files next to them are generated
*! and are overwritten on every build.  New sections are drafted from the Word
*! slides with  python tools/slides2qmd.py <course> <section> <slides.docx>.
*!
*! R tabs.  Pages with Stata and R tabs also hold R code chunks, which quarto
*! render runs.  The results are saved in _freeze/, so a page's R code reruns
*! only when that page changes.  Commit _freeze/ along with docs/.
*!
*! Restricted data.  Pages that use data that cannot be shared switch to its
*! folder in hidden code: fastcd (e.g., c rarc) for Stata, the full path for R.
*! Each then returns to the folder the page started in.
*!
*! Requirements: Stata 16+; the commands the pages use (listed below, with the
*! version of each that produced the output); Quarto on the PATH; for the R
*! tabs, R with the packages listed in README.md.
*!
*! (Comment lines in this file must not contain the two characters slash-star.)

version 16
set more off
set linesize 80
set rmsg off

* Quarto executable.  Leave as "quarto" when it is on the PATH.
local quarto "quarto"

* Commands used by the teaching pages (their versions are recorded in the log)
local cmds "mecompare metest meinequality totalme mtable mchange mlincom mgen listcoef mlogtest fre esttab coefplot binscatter binscatterhist combomarginsplot mkspline2 adjustrcspline usetdm"

* ---------------------------------------------------------------- arguments --
capture confirm file "_quarto.yml"
if _rc {
    di as err "build_teaching.do must be run from the repository root (the folder that contains _quarto.yml)."
    exit 601
}
local root "`c(pwd)'"

local course ""
local sections ""
local pages ""
local dyn 1
local render 1
foreach tok in `0' {
    local tok : subinstr local tok "\" "/", all
    if "`tok'" == "norender" local render 0
    else if "`tok'" == "render" local dyn 0
    else if strpos("`tok'", ".qmd") local pages "`pages' `tok'"
    else if "`course'" == "" {
        mata: st_local("isdir", strofreal(direxists("teaching/`tok'")))
        if !`isdir' {
            di as err "build_teaching.do: no course folder teaching/`tok'"
            exit 601
        }
        local course "`tok'"
    }
    else if "`tok'" == "all" {
        local subs : dir "teaching/`course'" dirs "*"
        foreach s of local subs {
            if inlist("`s'", ".", "..") continue
            mata: st_local("hassrc", strofreal(direxists("teaching/`course'/`s'/_src")))
            if `hassrc' local sections "`sections' `s'"
        }
    }
    else {
        mata: st_local("hassrc", strofreal(direxists("teaching/`course'/`tok'/_src")))
        if !`hassrc' {
            di as err "build_teaching.do: no teaching/`course'/`tok'/_src folder"
            exit 601
        }
        local sections "`sections' `tok'"
    }
}
if `dyn' & "`sections'" == "" & "`pages'" == "" {
    di as err "usage:  do build_teaching.do <course> <section> [<section> ...|all] [norender]"
    di as err "        do build_teaching.do teaching/<course>/<section>/_src/<page>.qmd"
    di as err "        do build_teaching.do render"
    exit 198
}

* run one source page (path relative to _src) from inside its section folder
capture program drop _teach_page
program define _teach_page
    args rel
    di as txt `"  dyntext _src/`rel'  ->  `rel'"'
    clear
    est clear
    graph drop _all
    if strpos("`rel'", "/") {
        local sub = substr("`rel'", 1, strpos("`rel'", "/") - 1)
        capture mkdir "`sub'"
    }
    dyntext "_src/`rel'", saving("`rel'") replace
end

* -------------------------------------------- 1. regenerate Stata output --
if `dyn' {
    di as txt _n "{hline 72}" _n "build_teaching.do: commands on the adopath" _n "{hline 72}"
    foreach c of local cmds {
        capture noisily which `c'
        if _rc di as err "  `c' not found on the adopath"
    }

    * single pages, given as teaching/<course>/<section>/_src/<page>.qmd
    foreach pg of local pages {
        local pg : subinstr local pg "\" "/", all
        local at = strpos("`pg'", "/_src/")
        if !`at' | substr("`pg'", 1, 9) != "teaching/" {
            di as err "build_teaching.do: give the page as teaching/<course>/<section>/_src/<page>.qmd"
            exit 198
        }
        local secdir = substr("`pg'", 1, `at' - 1)
        local rel = substr("`pg'", `at' + 6, .)
        capture confirm file "`root'/`pg'"
        if _rc {
            di as err "build_teaching.do: source page not found: `pg'"
            exit 601
        }
        di as txt _n "{hline 72}" _n "build_teaching.do: `pg'" _n "{hline 72}"
        cd "`root'/`secdir'"
        capture mkdir fig
        _teach_page "`rel'"
        foreach ext in dta gph {
            local tmps : dir . files "*.`ext'"
            foreach f of local tmps {
                erase "`f'"
            }
        }
        cd "`root'"
    }

    foreach s of local sections {
        di as txt _n "{hline 72}" _n "build_teaching.do: teaching/`course'/`s'" _n "{hline 72}"
        cd "`root'/teaching/`course'/`s'"
        capture mkdir fig
        local files : dir "_src" files "*.qmd"
        foreach f of local files {
            _teach_page "`f'"
        }
        local subs : dir "_src" dirs "*"
        foreach d of local subs {
            if inlist("`d'", ".", "..") continue
            local files : dir "_src/`d'" files "*.qmd"
            foreach f of local files {
                _teach_page "`d'/`f'"
            }
        }
        * files written by -margins, saving()-, -graph, saving()- and the like
        foreach ext in dta gph {
            local tmps : dir . files "*.`ext'"
            foreach f of local tmps {
                erase "`f'"
            }
        }
        cd "`root'"
    }
}

* ------------------------------------------------------- 2. quarto render --
if `render' {
    di as txt _n "{hline 72}" _n "build_teaching.do: quarto render" _n "{hline 72}"
    capture erase "build_render.log"
    !`quarto' render > build_render.log 2>&1
    capture confirm file "build_render.log"
    if !_rc type "build_render.log"
    capture confirm file "docs/.nojekyll"
    if _rc {
        tempname fh
        capture file open `fh' using "docs/.nojekyll", write replace
        capture file close `fh'
    }
    di as txt _n "Site rendered to  `root'/docs/"
}

di as res _n "build_teaching.do: done."
