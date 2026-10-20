capture 	log close
log using 	stata26-graphs-01-figures, replace text

version 	16.0
clear 		all
set 		linesize 80

// 2026 Stata Sociology Virtual Symposium (October 20, 2026)
// Comparing Effects Within and Across Models Using Marginal Effects
// Every example, table, and figure in the slides, in the order of the slides
// 19oct2026 (rev 13). Graphs are saved in the "- Graphs" subfolder

*The commands used. To install:
* net install suest2, from("https://tdmize.github.io/data") replace
* net install mecompare, from("https://tdmize.github.io/data") replace
* net install meinequality, from("https://tdmize.github.io/data") replace
* net install totalme, from("https://tdmize.github.io/data") replace
* ssc install coefplot, replace
which 		suest2
which 		mecompare
which 		metest
which 		meinequality
which 		totalme
which 		coefplot


**********************************************************
//#1 - Within a model: what patterns political views? (GSS 2021)
**********************************************************
use 		"https://tdmize.github.io/data/data/cda_gss", clear
keep if 	year == 2021
drop if 	missing(polviews, race4, woman, class, age)

*Political views: 1 to 7, conservative high
clonevar 	conpolviews = polviews

quietly regress conpolviews c.age##c.age i.woman i.race4 i.class, vce(robust)
estimates store polmod

*1.a - Figure: predictions for age (marginsplot) and gender (coefplot)
quietly margins, at(age=(18(1)89))
marginsplot, recast(line) recastci(rline) ciopts(lpattern(dash) color(*.4)) ///
	xlabel(20(10)80) xtitle("") ytitle("Cons. political views") ///
	title("Age") name(g_age, replace) nodraw

estimates restore polmod
quietly margins woman, post
estimates store pr_woman
coefplot 	pr_woman, vertical ytitle("Cons. political views") ///
	title("Gender") name(g_woman, replace) nodraw

**graph combine has no scale() option; its iscale() sets the text size
graph combine g_age g_woman, rows(1) ycommon xsize(8) ysize(4) iscale(*1.87)
	graph export "- Graphs/fig-polviews-predictions.png", width(2000) replace

*1.b - MEs of age (5th to 95th percentile) and gender, on one metric
mecompare 	age woman, models(polmod) amount(trimrange)

*1.c - Is the effect of age larger than the effect of gender?
**abs() compares the sizes of the effects regardless of sign
metest 		1 - abs(2)

*The trimmed range of age: its 5th and 95th percentiles
centile 	age, centile(5 95)

*For comparison: a centered 2 SD change in age
mecompare 	age, models(polmod) amount(2sd)


**********************************************************
//#2 - Interactions: support for women in politics (GSS)
**********************************************************
use 		"https://tdmize.github.io/data/data/cda_gss", clear
drop if 	missing(fepolB, woman, age, college)

quietly logit fepolB c.age##c.age##i.woman, vce(robust)
estimates store agemod

*2.a - Figure: predicted support by age and gender
quietly margins woman, at(age=(18(1)89))
marginsplot, recast(line) recastci(rline) ciopts(lpattern(dash) color(*.4)) ///
	xlabel(20(5)85) ylabel(0.4(0.05)0.9) xtitle("Age of respondent") ///
	ytitle("Pr(Supporting women in politics)") title("") scale(1.1)
	graph export "- Graphs/fig-fepol-age-gender.png", width(2000) replace

*2.b - MEs of a 5-year increase in age at the 10th and 90th percentiles of age
**(ages 25 and 72), for men and for women
quietly summarize age, detail
mecompare 	age, models(agemod) start(age=(`r(p10)' `r(p90)')) amount(5) uncentered by(woman)

*2.c - Second differences: does the effect of aging differ for women and men?
metest, 	clear
metest 		3 - 1, add rowname("2nd diff at age 25")
metest 		4 - 2, add rowname("2nd diff at age 72")
metest, 	title("Second differences: women - men")

*2.d - The gender gap at the 10th, 50th, and 90th percentiles of age (25, 44, 72)
**a list in covariates(): one ME per value, each as if the whole sample were that age
quietly summarize age, detail
mecompare 	woman, models(agemod) covariates(age=(`r(p10)' `r(p50)' `r(p90)'))

*Is the gender gap the same at all three ages? A joint test of equality
metest 		1 = 2 = 3


**********************************************************
//#3 - Across models: a curvilinear effect and attenuation (Add Health Wave 4)
**********************************************************
use 		"https://tdmize.github.io/data/data/ah4_cme", clear
drop if 	missing(depsympB, income, inc10, age, woman, race, college, jobsat)

*Base model, and the model adding job satisfaction
quietly regress depsympB c.income##c.income c.age i.woman i.race, vce(robust)
estimates store basemod
quietly regress depsympB c.income##c.income c.age i.woman i.race i.jobsat, vce(robust)
estimates store medmod

*3.a - Figure: predicted depressive symptoms by income, in each model
quietly suest2 basemod medmod
quietly margins, predict(model(basemod)) at(income=(0(5)150)) atmeans
marginsplot, plotopts(msym(i)) recastci(rline) ciopts(lpat(dash) color(gs12)) ///
	xlab(0(25)150) xtitle("Income in thousands of dollars") ///
	ylab(2(1)8) ytitle("Depressive symptoms") ///
	title("Model 1: Base", pos(11)) name(g_base, replace) nodraw
quietly margins, predict(model(medmod)) at(income=(0(5)150)) atmeans
marginsplot, plotopts(msym(i)) recastci(rline) ciopts(lpat(dash) color(gs12)) ///
	xlab(0(25)150) xtitle("Income in thousands of dollars") ///
	ylab(2(1)8) ytitle("Depressive symptoms") ///
	title("Model 2: Adding job satisfaction", pos(11)) name(g_med, replace) nodraw
graph combine g_base g_med, ycommon xsize(10) ysize(5.5) iscale(*1.32)
	graph export "- Graphs/fig-income-models.png", width(2000) replace

*3.b - The ME of income (+SD) in each model, and the cross-model difference
mecompare 	income, models(basemod medmod) amount(sd)

*3.c - The share of the income effect accounted for by job satisfaction
metest 		(1 - 2) / 1


**********************************************************
//#4 - Across models: four nested logit models (GSS 2000-2016)
**********************************************************
use 		"https://tdmize.github.io/data/data/gss_cme", clear
drop if 	year < 2000
drop if 	employed != 1
drop if 	missing(vhappy, college, wages, occprest, age, married, parent, ///
					woman, conserv, reltrad)

*Model 1: college only
quietly logit vhappy i.college, vce(robust)
estimates store m1
*Model 2: + controls
quietly logit vhappy i.college i.married i.parent i.woman i.conserv ///
	i.reltrad i.year c.age##c.age, vce(robust)
estimates store m2
*Model 3: + wages
quietly logit vhappy i.college c.wages i.married i.parent i.woman i.conserv ///
	i.reltrad i.year c.age##c.age, vce(robust)
estimates store m3
*Model 4: + occupational prestige
quietly logit vhappy i.college c.wages c.occprest i.married i.parent i.woman ///
	i.conserv i.reltrad i.year c.age##c.age, vce(robust)
estimates store m4

*4.a - The ME of college in each model, stored for coefplot
mecompare 	college, models(m1 m2 m3 m4) store(nest)

*4.b - Does each set of added variables reduce the college effect?
metest, 	clear
metest 		1 - 2, add
metest 		2 - 3, add
metest 		3 - 4, add

*4.c - Figure: the ME of college across the four models
coefplot 	nest_m1 nest_m2 nest_m3 nest_m4, xline(0) ///
	plotlabels("Model 1: College only" "Model 2: + Controls" "Model 3: + Wages" ///
	"Model 4: + Occupational prestige") ///
	xtitle("Average marginal effect of college on Pr(very happy)") scale(1.1)
	graph export "- Graphs/fig-nested-college.png", width(2000) replace


**********************************************************
//#5 - Across models: longitudinal models (HRS 2010-2020)
**********************************************************
use 		"https://tdmize.github.io/data/data/hrs_si_2025", clear
keep if 	year >= 2010 & age >= 51

*Binary outcomes: depressed (CES-D of 4 or more) and poor health
generate 	depressed = cesd >= 4 if !missing(cesd)
generate 	poorhealth = srhealthB == 0 if !missing(srhealthB)
drop if 	missing(depressed, poorhealth, marstatB, age, woman, race4cat, collegeB)

*Short value labels, so the labels fit in mecompare's table and in coefplot
quietly levelsof marstatB, local(lv)
label define marshort `: word 1 of `lv'' "Not married" `: word 2 of `lv'' "Married"
label values marstatB marshort
quietly levelsof woman, local(lv)
label define womshort `: word 1 of `lv'' "Man" `: word 2 of `lv'' "Woman"
label values woman womshort
quietly levelsof collegeB, local(lv)
label define colshort `: word 1 of `lv'' "No college" `: word 2 of `lv'' "College"
label values collegeB colshort

*Random-effects panel logits; slow with 60 integration points
xtset 		hhidpn year
quietly xtlogit depressed i.marstatB c.age i.woman i.race4cat i.collegeB, re intpoints(60)
estimates store dep
quietly xtlogit poorhealth i.marstatB c.age i.woman i.race4cat i.collegeB, re intpoints(60)
estimates store health

*5.a - MEs of every predictor in each model (age +2 SD), stored for coefplot
**no vce(robust) on the models: mecompare clusters the SEs on person
mecompare, 	models(dep health) amount(2sd) store(pan)

*5.b - Figure: the MEs for each outcome
coefplot 	pan_dep pan_health, xline(0) plotlabels("Depressed" "Poor health") ///
	xtitle("Average marginal effect") scale(1.1)
	graph export "- Graphs/fig-panel-mes.png", width(2000) replace

*5.c - Marriage and college in each model, and the cross-model differences
mecompare 	marstatB collegeB, models(dep health)


**********************************************************
//#6 - Across models: different model types (GSS 2010-2016)
**********************************************************
use 		"https://tdmize.github.io/data/data/gss_cme", clear
drop if 	year < 2010
drop if 	missing(partyid5, woman, edyrs, age, parent, married, faminc, ///
					employed, region4, year)

*Party identification (5 categories) as an ordinal and as a multinomial logit
quietly ologit partyid5 c.age##c.age i.woman c.edyrs i.parent i.married i.race ///
	c.faminc i.employed i.region4 i.year, vce(robust)
estimates store ordinal
quietly mlogit partyid5 c.age##c.age i.woman c.edyrs i.parent i.married i.race ///
	c.faminc i.employed i.region4 i.year, vce(robust)
estimates store nominal

*6.a - Figure: predicted party identification by age in each model
**suest2 posts both models together, so margins can predict from either one
quietly suest2 ordinal nominal
quietly margins, at(age=(20(5)80)) atmeans ///
	predict(model(ordinal) pr outcome(0)) predict(model(ordinal) pr outcome(1)) ///
	predict(model(ordinal) pr outcome(2)) predict(model(ordinal) pr outcome(3)) ///
	predict(model(ordinal) pr outcome(4))
**colors match the party: dark blue, blue, grey, red, dark red
marginsplot, noci plotopts(msym(i) lwidth(medthick)) ///
	plot1opts(lcolor("20 55 85")) plot2opts(lcolor("143 198 235")) ///
	plot3opts(lcolor(gs9)) plot4opts(lcolor("213 0 0")) plot5opts(lcolor("122 0 0")) ///
	legend(order(1 "Strong Dem" 2 "Democrat" 3 "Independent" ///
	4 "Republican" 5 "Strong Repub") position(6) rows(2)) ///
	xlab(20(10)80) xtitle("Age in years") ylab(0(.1).4) ///
	ytitle("Pr(party affiliation)") title("Ordinal logit", pos(11)) ///
	name(g_ordinal, replace) nodraw
quietly margins, at(age=(20(5)80)) atmeans ///
	predict(model(nominal) pr outcome(0)) predict(model(nominal) pr outcome(1)) ///
	predict(model(nominal) pr outcome(2)) predict(model(nominal) pr outcome(3)) ///
	predict(model(nominal) pr outcome(4))
marginsplot, noci plotopts(msym(i) lwidth(medthick)) ///
	plot1opts(lcolor("20 55 85")) plot2opts(lcolor("143 198 235")) ///
	plot3opts(lcolor(gs9)) plot4opts(lcolor("213 0 0")) plot5opts(lcolor("122 0 0")) ///
	legend(order(1 "Strong Dem" 2 "Democrat" 3 "Independent" ///
	4 "Republican" 5 "Strong Repub") position(6) rows(2)) ///
	xlab(20(10)80) xtitle("Age in years") ylab(0(.1).4) ///
	ytitle("Pr(party affiliation)") title("Multinomial logit", pos(11)) ///
	name(g_nominal, replace) nodraw
graph combine g_ordinal g_nominal, ycommon xsize(10) ysize(6) iscale(*1.32)
	graph export "- Graphs/fig-party-models.png", width(2000) replace

*6.b - MEs of age (+SD) on each party category, in each model
mecompare 	age, models(ordinal nominal) amount(sd)


**********************************************************
//#7 - Across models: groups and separate samples (GSS 1986 and 2016)
**********************************************************
use 		"https://tdmize.github.io/data/data/gss_cme", clear
drop if 	missing(helpsickB, polviews, faminc, employed, woman, age, college, ///
					married, parent)

*Separate models for 1986 and 2016; predictions for conservatives and others
quietly logit helpsickB i.conserv faminc i.employed i.woman age i.college ///
	i.married i.parent i.race if year == 1986, vce(robust)
estimates store mod1986
quietly margins conserv, post
estimates store pr1986

quietly logit helpsickB i.conserv faminc i.employed i.woman age i.college ///
	i.married i.parent i.race if year == 2016, vce(robust)
estimates store mod2016
quietly margins conserv, post
estimates store pr2016

*7.a - Figure: bars for not conservative (blue) and conservative (red), in each year
**with subgraphs (||), set the text size in byopts(iscale()); the axis title needs its own size()
coefplot 	(pr1986, keep(0*.conserv) color("143 198 235")) ///
			(pr1986, keep(1*.conserv) color("213 0 0")), bylabel(1986) ///
		 || (pr2016, keep(0*.conserv) color("143 198 235")) ///
			(pr2016, keep(1*.conserv) color("213 0 0")), bylabel(2016) ///
		 ||, vertical recast(bar) barwidth(0.6) nooffsets citop ///
			ciopts(recast(rcap) color(gs8)) ylabel(0(.1).7) ///
			ytitle("Pr(government should help)", size(medlarge)) ///
			byopts(rows(1) legend(off) iscale(*1.7)) xsize(8) ysize(4)
	graph export "- Graphs/fig-groups-conserv.png", width(2000) replace

*7.b - The ME of being conservative in each year, and the difference
mecompare 	conserv, models(mod1986 mod2016) groups


**********************************************************
//#8 - Summary measures: racial-ethnic inequality in wages (GSS 2021)
**********************************************************
use 		"https://tdmize.github.io/data/data/cda_gss", clear
keep if 	year == 2021
drop if 	missing(wages, race4)

quietly regress wages i.race4 c.age i.woman
estimates store wagemod

*8.a - Figure: predicted wages by race-ethnicity (coefplot)
quietly margins race4, post
estimates store pr_race
coefplot 	pr_race, vertical ytitle("Predicted hourly wages (dollars)") scale(1.1)
	graph export "- Graphs/fig-wages-race.png", width(2000) replace

*8.b - ME inequality (weighted by group size, the default)
estimates restore wagemod
meinequality race4


**********************************************************
//#9 - Summary measures: has religion's effect declined? (GSS)
**********************************************************
use 		"https://tdmize.github.io/data/data/cda_gss", clear
drop if 	missing(spkhomo, reltrad, age, woman)

*Allowing a gay person to give a public speech: before 1980 and since 2010
quietly logit spkhomo i.reltrad c.age i.woman if year < 1980, vce(robust)
estimates store premod
quietly logit spkhomo i.reltrad c.age i.woman if year >= 2010, vce(robust)
estimates store postmod

*9.a - Figure: predictions by religious tradition in each period
**the dashed lines are each period's average prediction
estimates restore premod
quietly margins
matrix 		avg = r(b)
local 		avgpre = avg[1,1]
quietly margins reltrad, post
estimates store prpre

estimates restore postmod
quietly margins
matrix 		avg = r(b)
local 		avgpost = avg[1,1]
quietly margins reltrad, post
estimates store prpost

coefplot 	(prpre, label("Before 1980")) (prpost, label("Since 2010")), ///
	xline(`avgpre', lpattern(dash) lcolor("213 0 0")) ///
	xline(`avgpost', lpattern(dash) lcolor("143 198 235")) ///
	xtitle("Pr(support LGB free speech)") scale(1.1)
	graph export "- Graphs/fig-religion-speech.png", width(2000) replace

*9.b - Unweighted ME inequality in each period, and the difference
meinequality reltrad, models(premod postmod) groups unweighted


**********************************************************
//#10 - Summary measures: the total ME on self-rated health (GSS 2000-2021)
**********************************************************
use 		"https://tdmize.github.io/data/data/cda_gss", clear
drop if 	missing(healthR, race4, age, woman, parent, married, faminc, degree)
drop if 	year < 2000 | year > 2021

*Self-rated health: poor, fair, good, excellent
quietly mlogit healthR i.race4 c.age i.woman i.parent i.married c.faminc i.degree

*10.a - Figure: predicted probability of each health category by age
**cleanplots4v: the cleanplots colors for a 4-category outcome
quietly margins, at(age=(20(5)85))
marginsplot, recast(line) recastci(rline) ciopts(lpattern(dash) color(*.4)) ///
	xlabel(20(10)80) xtitle("Age") ytitle("Pr(health status)") title("") ///
	legend(order(5 "Poor" 6 "Fair" 7 "Good" 8 "Excellent") rows(1) position(6)) ///
	scheme(cleanplots4v) scale(1.1)
	graph export "- Graphs/fig-health-age.png", width(2000) replace

*10.b - Total MEs of age (+SD), marriage, and parenthood
totalme 	age married parent, amount(sd)


**********************************************************
//#A1 - Appendix: generalized marginal effects (GSS 2000-2016)
**********************************************************
use 		"https://tdmize.github.io/data/data/gss_cme", clear
drop if 	year < 2000
drop if 	employed != 1
drop if 	missing(vhappy, college, wages, occprest, age, married, parent, ///
					woman, conserv, reltrad)

*Model 4 from section 4
quietly logit vhappy i.college c.wages c.occprest i.married i.parent i.woman ///
	i.conserv i.reltrad i.year c.age##c.age, vce(robust)
estimates store m4

*Mean wages and occupational prestige, without and with a college degree
tabstat 	wages occprest if e(sample), by(college) format(%5.2f)

*A.1 - The ME of college, then with wages and prestige changing along with it
mecompare 	college, models(m4) cochange(wages occprest) ///
	start(wages=13.60 occprest=40.51) end(wages=24.88 occprest=54.68)


**********************************************************
//#A2 - Appendix: within-person effects (HRS 2010-2020)
**********************************************************
use 		"https://tdmize.github.io/data/data/hrs_si_2025", clear
keep if 	year >= 2010 & age >= 51
generate 	depressed = cesd >= 4 if !missing(cesd)
drop if 	missing(depressed, marstatB, age, woman, race4cat, collegeB)

*Short value labels, as in section 5
quietly levelsof marstatB, local(lv)
label define marshort `: word 1 of `lv'' "Not married" `: word 2 of `lv'' "Married"
label values marstatB marshort
quietly levelsof woman, local(lv)
label define womshort `: word 1 of `lv'' "Man" `: word 2 of `lv'' "Woman"
label values woman womshort
quietly levelsof collegeB, local(lv)
label define colshort `: word 1 of `lv'' "No college" `: word 2 of `lv'' "College"
label values collegeB colshort

*Correlated random effects: add each person's mean of the time-varying predictors
xtset 		hhidpn year
bysort hhidpn: egen mean_marstatB = mean(marstatB)
bysort hhidpn: egen mean_age = mean(age)
quietly xtlogit depressed i.marstatB c.age i.woman i.race4cat i.collegeB, re intpoints(30)
estimates store re
quietly xtlogit depressed i.marstatB c.mean_marstatB c.age c.mean_age ///
	i.woman i.race4cat i.collegeB, re intpoints(30)
estimates store cre

*A.2 - The ME of marriage: random effects vs. within persons
mecompare 	marstatB, models(re cre)


**********************************************************
//#A3 - Appendix: multilevel models (Add Health Wave 1)
**********************************************************
use 		"https://tdmize.github.io/data/data/ah_si_2026", clear
keep if 	wave == 1
rename 		cluster school
drop if 	missing(smoker, male, age, race, momeduc)

generate 	momcollege = momeduc >= 4
label define momcollege 0 "No college" 1 "College"
label values momcollege momcollege

*School share of mothers with a college degree
**school_momcol (not school_momcollege): "name + SD (centered)" must fit in 32 characters
bysort school: egen school_momcol = mean(momcollege)

*A multilevel logit (random intercept for school) and an ordinary logit
quietly melogit smoker i.male c.age i.race i.momcollege c.school_momcol || school:
estimates store multilevel
quietly logit smoker i.male c.age i.race i.momcollege c.school_momcol
estimates store ordinary

*A.3.a - MEs in each model (+SD for continuous) and the cross-model differences
**no vce(robust) on the models: mecompare clusters the SEs on school
mecompare, 	models(ordinary multilevel) amount(sd) store(ml)

*A.3.b - Figure: the MEs in each model
coefplot 	ml_ordinary ml_multilevel, xline(0) plotlabels("Logit" "Multilevel logit") ///
	xtitle("Average marginal effect on Pr(smoker)") scale(1.1)
	graph export "- Graphs/fig-multilevel-mes.png", width(2000) replace


**********************************************************
//#A4 - Appendix: totalme across models (GSS 2000-2021)
**********************************************************
use 		"https://tdmize.github.io/data/data/cda_gss", clear
drop if 	missing(healthR, college, race4, age, woman, parent, married, faminc)
drop if 	year < 2000 | year > 2021

quietly mlogit healthR i.college i.race4 c.age i.woman i.parent i.married, vce(robust)
estimates store basemod
quietly mlogit healthR i.college i.race4 c.age i.woman i.parent i.married ///
	c.faminc, vce(robust)
estimates store medmod

*A.4 - The total ME of college in each model, and the difference
totalme 	college, models(basemod medmod)


**********************************************************
//#A5 - Appendix: suest2 in practice (NLSW 1988)
**********************************************************
sysuse 		nlsw88, clear

quietly logit union i.collgrad c.age i.south, vce(robust)
estimates store m1
quietly logit union i.collgrad c.age i.south c.wage c.ttl_exp, vce(robust)
estimates store m2

*A.5 - One set of results with every cross-model covariance
suest2 		m1 m2


*************
log close
exit
*************
