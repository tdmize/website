capture log close
log using "dmv-data_visualization-exs", replace text

version 	16.0
clear 		all
set more 	off
set 		linesize 80

// MCAP Workshop 2026 | Data Visualization
// Trenton Mize | 2026-11-18
// R versions of all examples are in dmv-data_visualization-exs.R


**********************************************************
//#0 - Setup: install packages and set graphics scheme
**********************************************************
net install cleanplots, from("https://tdmize.github.io/data") replace
ssc install coefplot, replace
ssc install combomarginsplot, replace
ssc install binscatter, replace
ssc install estout, replace

// cleanplots: https://www.trentonmize.com/software/cleanplots
set scheme 	cleanplots

capture mkdir "- Figures"		// folder for saved graphs



**********************************************************
//#Introduction - Anscombe's quartet
**********************************************************
use 	"https://tdmize.github.io/data/data/anscombe.dta", clear

tabstat Y* Xabc Xd, stat(mean sd min max) format(%4.2f) col(stats)

regress Ya Xabc
estimates store Ya
regress Yb Xabc
estimates store Yb
regress Yc Xabc
estimates store Yc
regress Yd Xd
estimates store Yd

esttab Ya Yb Yc Yd, b(2) se(2) title("Linear Regression Estimates")

sort Xabc // this forces lines to connect from left to right

// 0.a - Scatterplot of the data
twoway ///
    (scatter Ya Xabc) ///
	(scatter Yb Xabc) ///
	(scatter Yc Xabc) ///
	(scatter Yd Xd), ///
	ylab(0(5)15) xlab(0(5)20) ///
	title("[0.a] Anscombe's Quartet - All y & x Variables Have Same Mean and SD")

	graph export "- Figures/dmv-00_a-anscombe.png", width(3000) replace

// 0.b - Add connected lines
twoway ///
    (connected Ya Xabc) ///
	(connected Yb Xabc) ///
	(connected Yc Xabc) ///
	(scatter Yd Xd), ///
	ylab(0(5)15) xlab(0(5)20) ///
	title("[0.b] Anscombe's Quartet - All y & x Variables Have Same Mean and SD")

	graph export "- Figures/dmv-00_b-anscombe_lines.png", width(3000) replace



**********************************************************
//#1 - Look at your data
**********************************************************
use 	"https://tdmize.github.io/data/data/gss.dta", clear

*****************
// Histograms //
*****************
// 1.a - freq option to plot # of obs in each bin
hist 	wages, freq fcol(none) xlab(0(10)70) ///
	title("[1.a] Histogram of Distribution of Hourly Wages") ///
	subtitle("y-axis shows number of observations in bin")

	graph export "- Figures/dmv-01_a-hist.png", width(3000) replace

***************************
// Kernel Density Plots //
***************************
// 1.b - Overlay a kernel density plot on a histogram to illustrate what it does
*NOTE: Just pedagogical, not a graph you would usually make
twoway 		///
	hist 		wages, fcol(none)  									||		///
	kdensity 	wages, col(red)										|| 		///
	, xlab(0(10)70) legend(order(1 "Histogram" 2 "Kernel Density"))			///
	ytitle("Density") xtitle("Hourly Wages ($)")							///
	title("[1.b] Distribution of Hourly Wages") 							///
	subtitle("Comparison of histogram and kernel density plot")

	graph export "- Figures/dmv-01_b-hist_kdensity.png", width(3000) replace

// 1.c - Usually, just want the density and not the histogram too
kdensity wages, xlab(0(10)70) ///
	ytitle("Density") xtitle("Hourly Wages ($)") ///
	title("[1.c] Kernel Density Plot of Hourly Wages")

	graph export "- Figures/dmv-01_c-kdensity.png", width(3000) replace

******************************
// Box (and Whisker) Plots //
******************************
use 	"https://tdmize.github.io/data/data/ah_si.dta", clear

* Top code drinks in the past year at 1,000
gen 	numdrinksyrT = numdrinksyr
recode 	numdrinksyrT 1000 / 9125 = 1000
lab var numdrinksyrT "# of drinks last year (top coded at 1,000)"

// 1.d - Drinks in the past year, with separate boxes by wave
graph box numdrinksyrT, over(wave) ///
    ytitle("# of drinks in the past year") ///
    title("[1.d] Box plot of drinks in the past year by wave of Add Health") ///
    subtitle("Top coded at 1,000 drinks")

	graph export "- Figures/dmv-01_d-boxplot.png", width(3000) replace

// 1.e - Add a second grouping variable
graph box numdrinksyrT, ///
    over(male)  over(wave)  asyvars horizontal ///
    ytitle("# of drinks in the past year") ///
    title("[1.e] Box plot of drinks in the past year by Add Health wave and gender") ///
    subtitle("Top coded at 1,000 drinks")

	graph export "- Figures/dmv-01_e-boxplot_by_gender.png", width(3000) replace



**********************************************************
//#2 - Use graph types people read accurately
**********************************************************
use 	"https://tdmize.github.io/data/data/hrs_si.dta", clear

* Create variable to flag cohort of respondents who were in first wave of data
egen 	byte in1992 = max(year == 1992), by(hhidpn)
tab 	in1992

// 2.a - Pie charts are generally not recommended
graph pie, over(srhealth) ///
    title("[2.a] Pie chart for distribution of self-rated health among older adults")

	graph export "- Figures/dmv-02_a-pie.png", width(3000) replace

// 2.b - Stacked bar chart
graph bar (count) if in1992, ///
    over(srhealth) horizontal asyvars stack  percentages ///
    ytitle("Self-rated health") title("") ///
    scheme(cleanplots5) legen(pos(6) row(1)) xsize(8) ysize(2) scale(2.5)

	graph export "- Figures/dmv-02_b-stack_bar.png", width(3000) replace
	
// 2.c - Stacked bar chart with 1992 cohort: ordinal colors from cleanplots5 scheme
graph bar (count) if in1992, ///
    over(srhealth) over(year) ///
    asyvars stack  percentages ///
    ytitle("Self-rated health") ///
    title("[2.c] Stacked bar chart of self-rated health among older adults over time (HRS)") ///
    scheme(cleanplots5)

	graph export "- Figures/dmv-02_c-stack_bar.png", width(3000) replace

// 2.d - Bar chart for distribution of days drinking
graph bar (count), ///
    over(dayweekdrink) ///
    title("[2.d] Bar chart for days usually drink each week (older adults, HRS)") ///
    ytitle("Count") b1title("Days usually drink each week")

	graph export "- Figures/dmv-02_d-bar.png", width(3000) replace



**********************************************************
//#3 - Maximize the data-ink ratio, within reason (maybe)
**********************************************************
use 	"https://tdmize.github.io/data/data/hrs_si.dta", clear

* Percent of men and of women in each category of days drinking
proportion 	dayweekdrink if woman == 0
est store 	drink_men
proportion 	dayweekdrink if woman == 1
est store 	drink_wom

// 3.a - Dot plot for days drinking per week, by gender
coefplot (drink_men, label("Men") offset(-0.15)) ///
		 (drink_wom, label("Women") offset(0.15)), ///
	vertical noci msize(*1.5) rescale(100) ylab(0(10)80) ///
	xlab(1 "0" 2 "1" 3 "2" 4 "3" 5 "4" 6 "5" 7 "6" 8 "7") ///
	ytitle("Percent") xtitle("Days usually drink each week") ///
	title("[3.a] Dot plot for days usually drink each week (older adults, HRS)") ///
	subtitle("Percent of men and of women")

	graph export "- Figures/dmv-03_a-dot_gender.png", width(3000) replace

// 3.b - Same information as a bar chart
coefplot (drink_men, label("Men") offset(-0.2)) ///
		 (drink_wom, label("Women") offset(0.2)), ///
	vertical noci rescale(100) ylab(0(10)80) ///
	recast(bar) barwidth(0.4) ///
	xlab(1 "0" 2 "1" 3 "2" 4 "3" 5 "4" 6 "5" 7 "6" 8 "7") ///
	ytitle("Percent") xtitle("Days usually drink each week") ///
	title("[3.b] Bar chart for days usually drink each week (older adults, HRS)") ///
	subtitle("Percent of men and of women")

	graph export "- Figures/dmv-03_b-bar_gender.png", width(3000) replace



**********************************************************
//#4 - Show uncertainty
**********************************************************
// 4.a - Add 95% confidence intervals to the bar chart
mean cesd if year == 2022, over(dayweekdrink)

marginsplot, recast(bar) plotopts(barwidth(.5) col(*.7)) ciopts(col(gs8)) ///
    ytitle("Depressive symptoms") ylabel(0(0.5)2) ///
    xtitle("Days drinking alcohol per week") ///
    title("[4.a] Average number of depressive symptoms") ///
    subtitle("By number of days drinking per week (95% confidence intervals)")

	graph export "- Figures/dmv-04_a-bar_y_CIs.png", width(3000) replace

// 4.b - Recreate plot above but with a dot plot
marginsplot, recast(scatter) recastci(rspike) ciopt(col(*.5)) ///
    ytitle("Depressive symptoms") ylabel(0(0.5)2) ///
    xtitle("Days drinking alcohol per week") ///
    title("[4.b] Average number of depressive symptoms") ///
    subtitle("By number of days drinking per week (95% confidence intervals)")

	graph export "- Figures/dmv-04_b-dot_y_CIs.png", width(3000) replace



**********************************************************
//#BREAK 1 - Group task
**********************************************************
// Load the data and make a quick graph. What does it show? How could it be better?
use 	"https://tdmize.github.io/data/data/hrs_si.dta", clear
graph bar (mean) lifesat if year == 2022, over(marstat)

	graph export "- Figures/dmv-B1_a-task.png", width(3000) replace

// B1.b - A publication-quality version
mean lifesat if year == 2022, over(marstat)

coefplot, vertical msize(*1.2) ciopts(col(*.5)) ///
    xlab(1 "married/partnered" 2 "separated/divorced" 3 "widowed" 4 "never married") ///
    ytitle("Life satisfaction (1 to 7)") ylabel(4(.5)5.5) ///
    xtitle("Marital status") ///
    title("[B1.b] Average life satisfaction by marital status (older adults, HRS)") ///
    subtitle("With 95% confidence intervals")

	graph export "- Figures/dmv-B1_b-task_pub.png", width(3000) replace



**********************************************************
//#5 - Make groups easy to tell apart
**********************************************************
use 	"https://tdmize.github.io/data/data/gss.dta", clear

// 5.a - Overlay multiple densities for different groups
twoway 	kdensity wages if degree==0 || ///
		kdensity wages if degree==1 || ///
		kdensity wages if degree==2 || ///
		kdensity wages if degree==3 || ///
		kdensity wages if degree==4 ||, ///
		legend(order(1 "< High School" 2 "HS Degree" 3 "Junior College" ///
				4 "College Degree" 5 "Grad Degree")) ///
		ytitle("Density") xtitle("Hourly Wages") xlab(0(10)70) ///
		title("[5.a] Kernel-Density Plots of Hourly Wages Based on Educational Attainment") ///
		subtitle("Densities are group specific")

	graph export "- Figures/dmv-05_a-kdensity_groups.png", width(3000) replace

use 	"https://tdmize.github.io/data/data/hrs_si.dta", clear
egen 	byte in1992 = max(year == 1992), by(hhidpn)

* Value labels for year so coefplot labels each wave with its year
levelsof year, local(yrs)
foreach y of local yrs {
	label define yearlab `y' "`y'", add
}
label values year yearlab

// 5.b - Mean cognitive test score by year, separately for men and women
*coefplot offsets the groups so their confidence intervals do not overlap
regress 	cog ibn.year if in1992 & woman == 0, nocons
est store 	cog_men
regress 	cog ibn.year if in1992 & woman == 1, nocons
est store 	cog_wom

coefplot (cog_men, label("Men")) (cog_wom, label("Women")), ///
	vertical ylabel(12(1)18) ///
	xtitle("Year") ytitle("Cognitive test score") ///
	title("[5.b] Performance on a cognitive test over time, by gender") ///
	subtitle("Means and 95% confidence intervals")

	graph export "- Figures/dmv-05_b-dot_cog_gender.png", width(3000) replace

// 5.c - Many groups: cleanplots changes marker shapes in addition to color
local plots
forvalues d = 0/7 {
	qui regress cog ibn.year if in1992 & degree == `d', nocons
	est store cog_deg`d'
	local lab : label (degree) `d'
	local plots `plots' (cog_deg`d', label("`lab'"))
}

coefplot `plots', vertical ylabel(10(2)20) ///
	xtitle("Year") ytitle("Cognitive test score") ///
	title("[5.c] Performance on a cognitive test over time, by education") ///
	subtitle("Means and 95% confidence intervals")

	graph export "- Figures/dmv-05_c-dot_cog_educ.png", width(3000) replace

// 5.d & 5.e - Mize 2025 SPQ data on stereotypes
use 	"https://tdmize.github.io/data/data/cgr.dta", clear

*collapse to means by experimental condition
collapse 	compSS warmSS if ordcond == 2, by(cond)
list

// 5.d - discrete color for each marker (too many colors to understand)
twoway 	scatter warmSS compSS, ///
			colorvar(cond) colordiscrete coloruseplegend ///
			zlabel(, valuelabel) colorrule(phue) ///
		ytitle("Warmth") xtitle("Competence") ylab(3(1)7) xlab(3(1)7) ///
		title("[5.d] Warmth and competence stereotypes of gender X racial-ethnic groups")

	graph export "- Figures/dmv-05_d-scatter_colors.png", width(3000) replace

// 5.e - With so many groups, better to just directly label points
twoway 	scatter warmSS compSS, mlabel(cond) mlabangle(35) mlabsize(*.75) ///
		ytitle("Warmth") xtitle("Competence") ylab(3(1)7) xlab(3(1)7) ///
		title("[5.e] Warmth and competence stereotypes of gender X racial-ethnic groups")

	graph export "- Figures/dmv-05_e-scatter_labels.png", width(3000) replace

// 5.f - Ordinal (viridis) colors for an ordered variable: cleanplots8v scheme
use 	"https://tdmize.github.io/data/data/hrs_si.dta", clear

graph bar (mean) dzcount, over(degree) asyvars showyvars legend(off) ///
    yvaroptions(label(angle(45))) ///
    ytitle("Count of chronic diseases") ///
    title("[5.f] Average chronic disease count by educational attainment") ///
    subtitle("Colors are from cleanplots ordinal viridis scheme") ///
    scheme(cleanplots8v)

	graph export "- Figures/dmv-05_f-color_viridis.png", width(3000) replace



**********************************************************
//#6 - Choose axes that fit the data
**********************************************************
use		"https://tdmize.github.io/data/data/addhealth4.dta", clear
drop if employed != 1

sum 	wages, d
reg 	wages ibn.educ if employed, nocon

// 6.a - y-axis covers the observed range in data
coefplot, noci vertical ylab(0(50)500) ///
	title("[6.a] Predicted Hourly Wages Based on Educational Attainment") ///
	subtitle("y-axis range = range of observed values in data") ///
	ytitle("Hourly Wages in $") ///
	xlab(1 `" "No High" "School Degree" "' 2 `" "High School" "Degree" "' ///
	3 `" "Some" "College" "' 4 `" "College" "Degree" "' 5 `" "Graduate" "Degree" "')

	graph export "- Figures/dmv-06_a-yaxis_range.png", width(3000) replace

// 6.b - y-axis covers the 10th to 90th percentile of data
coefplot, vertical ylab(5(5)30) ///
	title("[6.b] Predicted Hourly Wages Based on Educational Attainment") ///
	subtitle("y-axis range = 10th to 90th percentile of observed values in data") ///
	ytitle("Hourly Wages in $") ///
	xlab(1 `" "No High" "School Degree" "' 2 `" "High School" "Degree" "' ///
	3 `" "Some" "College" "' 4 `" "College" "Degree" "' 5 `" "Graduate" "Degree" "')

	graph export "- Figures/dmv-06_b-yaxis_10-90th.png", width(3000) replace

// 6.c - y-axis covers the 5th to 95th percentile of data
coefplot, vertical ylab(0(5)40) ///
	title("[6.c] Predicted Hourly Wages Based on Educational Attainment") ///
	subtitle("y-axis range = 5th to 95th percentile of observed values in data") ///
	ytitle("Hourly Wages in $") ///
	xlab(1 `" "No High" "School Degree" "' 2 `" "High School" "Degree" "' ///
	3 `" "Some" "College" "' 4 `" "College" "Degree" "' 5 `" "Graduate" "Degree" "')

	graph export "- Figures/dmv-06_c-yaxis_5-95th.png", width(3000) replace



**********************************************************
//#7 - Design for your audience
**********************************************************
use		"https://tdmize.github.io/data/data/gss.dta", clear
drop 	if year < 2000
drop 	if employed != 1

regress 	wages c.age##c.age##i.woman i.college i.race
qui margins, at(age=(18(2)90) woman=(0 1))

*****************
// Fonts //
*****************
// 7.a - Arial
graph set window fontface "Arial"
marginsplot, plotopts(msym(none)) xlab(20(10)90) ylab(0(5)30) ///
	recastci(rline) ciopts(lpat(dash) col(gs12)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[7.a] Predicted Hourly Wages Based on Age of Worker", size(medium)) ///
	subtitle("Font: Arial")

	graph export "- Figures/dmv-07_a-font_arial.png", width(3000) replace

// 7.b - Cambria
graph set window fontface "Cambria"
marginsplot, plotopts(msym(none)) xlab(20(10)90) ylab(0(5)30) ///
	recastci(rline) ciopts(lpat(dash) col(gs12)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[7.b] Predicted Hourly Wages Based on Age of Worker", size(medium)) ///
	subtitle("Font: Cambria")

	graph export "- Figures/dmv-07_b-font_cambria.png", width(3000) replace

*NOTE: graph set changes the font for all later graphs. To go back to Stata's default:
*graph set window fontface default

*****************
// Graphics schemes //
*****************
// 7.c - s2color (pre-Stata 18 default)
marginsplot, plotopts(msym(none)) xlab(20(10)90) ylab(0(5)30) ///
	recastci(rline) ciopts(lpat(dash) col(*.4)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[7.c] Predicted Hourly Wages Based on Age of Worker", size(medium)) ///
	subtitle("Graphics Scheme: s2color (pre-Stata 18 default)") scheme(s2color)

	graph export "- Figures/dmv-07_c-s2color.png", width(3000) replace

// 7.d - stcolor (Stata 18 default)
marginsplot, plotopts(msym(none)) xlab(20(10)90) ylab(0(5)30) ///
	recastci(rline) ciopts(lpat(dash) col(*.4)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[7.d] Predicted Hourly Wages Based on Age of Worker", size(medium)) ///
	subtitle("Graphics Scheme: stcolor (Stata 18 default)") scheme(stcolor)

	graph export "- Figures/dmv-07_d-stcolor.png", width(3000) replace

// 7.e - cleanplots
marginsplot, plotopts(msym(none)) xlab(20(10)90) ylab(0(5)30) ///
	recastci(rline) ciopts(lpat(dash) col(*.4)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[7.e] Predicted Hourly Wages Based on Age of Worker", size(medium)) ///
	subtitle("Graphics Scheme: cleanplots") scheme(cleanplots)

	graph export "- Figures/dmv-07_e-cleanplots.png", width(3000) replace



**********************************************************
//#8 - Use graphs, not tables, for model results
**********************************************************
** Ex 1: Linear Regression with Interaction
use "https://tdmize.github.io/data/data/dmv_intsim01.dta", clear

regress 	y b c
estimates store mod1a

regress 	y c.c##i.b
estimates store mod1b

regress 	y c.c##i.b x1
estimates store mod1c

esttab mod1a mod1b mod1c, noomit nobase se  ///
		title("Linear interaction models")

// 8.a - Plot the predictions
estimates restore mod1c
qui margins, at(c=(-150(5)150) b=(0 1))

*Generate variables to make rugs on plot
gen 	pipe = "|" if c != .		// What rug looks like
gen 	where =  -150				// Where on y-axis to put  rug

marginsplot, ///
	recastci(rline) ciopt(lpat(dash) col(gs12)) plotopt(msym(none)) ///
	addplot(scatter where c, ms(none) mlabel(pipe) mlabcol(gs6) ///
	xlab(-150(50)150) ylab(-150(50)150) xline(0) yline(0) legend(order(3 "b=0" 4 "b=1"))) ///
	title("[8.a] Predictions from linear regression that includes b*c product term") ///
	ytitle("Predicted y") xtitle("c")

	graph export "- Figures/dmv-08_a-preds_int_linear.png", width(3000) replace


** Ex 2: Binary Logit with Interaction
use "https://tdmize.github.io/data/data/dmv_intsim02.dta", clear

logit 		y b c
estimates store mod2a

logit 		y c.c##i.b
estimates store mod2b

logit 		y c.c##i.b x1
estimates store mod2c

esttab mod2a mod2b mod2c, noomit nobase se  ///
			title("Logit interaction models")

// 8.b - Plot the predictions
estimates restore mod2c
qui margins, at(c=(3(.25)9) b=(0 1))

*Generate variables to make rugs on plot
gen 	pipe = "|" if c != .		// What rug looks like
gen 	where =  0					// Where on y-axis to put  rug

marginsplot, ///
	recastci(rline) ciopt(lpat(dash) col(gs12)) plotopt(msym(none)) ///
	addplot(scatter where c, ms(none) mlabel(pipe) mlabcol(gs6) ///
			xlab(3(1)9) ylab(0(.2)1) legend(order(3 "b=0" 4 "b=1"))) ///
	title("[8.b] Predictions from binary logit model that includes b*c product term") ///
	ytitle("Predicted probability") xtitle("c")

	graph export "- Figures/dmv-08_b-preds_int_logit.png", width(3000) replace


*****************
// Coefficient plots //
*****************
use		"https://tdmize.github.io/data/data/addhealth4.dta", clear

// 8.c - Coefficients from a linear regression model
regress	subjclass i.woman i.race3 c.age c.income i.college i.workstat

coefplot, xline(0) xlab(-1(.5)1) baselevels ciop(col(gs12)) drop(_cons 0.woman)  ///
	title("[8.c] Predictors of Subjective Class Standing - Linear Regression") ///
	note("Effects above zero indicate higher subjective class standing")

	graph export "- Figures/dmv-08_c-coefplot.png", width(3000) replace

// 8.d - Separate models for men and women
regress		subjclass i.race3 c.age c.income i.college i.workstat if woman == 0
est store 	scmen

regress		subjclass i.race3 c.age c.income i.college i.workstat if woman == 1
est store 	scwom

coefplot (scmen, label("Men")) (scwom, label("Women")), ///
	xline(0) xlab(-1(.5)1) baselevels ciop(col(*.5)) drop(*_cons) ///
	title("[8.d] Predictors of Subjective Class Standing - Linear Regression") ///
	subtitle("Separate Models for Men and Women") ///
	note("Effects above zero indicate higher subjective class standing")

	graph export "- Figures/dmv-08_d-coefplot_by_gender.png", width(3000) replace


*****************
// Coefficient plots of marginal effects //
*****************
use		"https://tdmize.github.io/data/data/pew16.dta", clear

logit	trump i.woman c.age ib4.educ i.religB c.income ib3.region, or

* Average marginal effects (AMEs) for all predictors
margins, dydx(*) post
est 	store ames

// 8.e - Coefficient plot of the AMEs
coefplot ames, xline(0) xlab(-.4(.1).4) ciop(col(gs12)) ///
	baselevels drop(0.woman 0.religB) ///
	title("[8.e] Binary Logit: Average Marginal Effects of Support for Trump vs Clinton") ///
	note("Effects above zero indicate more support for Trump")

	graph export "- Figures/dmv-08_e-ames.png", width(3000) replace



**********************************************************
//#BREAK 2 - Group task
**********************************************************
// Fit a model and make a quick graph. What does it show? How could it be better?
use 	"https://tdmize.github.io/data/data/gss.dta", clear
regress occprest c.age c.income i.woman i.college i.race
coefplot

	graph export "- Figures/dmv-B2_a-task.png", width(3000) replace

// B2.b - A publication-quality version
* Show effects of the continuous IVs for a 2 standard deviation increase
sum 	age if e(sample)
global 	age2sd = 2*r(sd)
sum 	income if e(sample)
global 	inc2sd = 2*r(sd)

coefplot, xline(0) baselevels ciop(col(*.6)) drop(_cons 0.woman) ///
	rescale(age = $age2sd income = $inc2sd) ///
	coeflabels(age = "Age (+2 SD)" income = "Income (+2 SD)") ///
	xtitle("Difference in occupational prestige") ///
	title("[B2.b] Predictors of Occupational Prestige - Linear Regression") ///
	note("Age and income effects shown for a 2 standard deviation increase")

	graph export "- Figures/dmv-B2_b-task_pub.png", width(3000) replace



**********************************************************
//#9 - Show what the model predicts
**********************************************************
use		"https://tdmize.github.io/data/data/gss.dta", clear
drop 	if year < 2000
drop 	if employed != 1

// Linear regression model with age and age-squared
regress 	wages c.age##c.age i.woman i.college i.race
qui margins, at(age=(18(2)90))

// 9.a - Plot predictions for age
marginsplot, plotopts(msym(none)) xlab(20(10)90) ylab(0(5)30) ///
	recastci(rline) ciopts(lpat(dash) col(gs12)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[9.a] Predicted Hourly Wages Based on Age of Worker")

	graph export "- Figures/dmv-09_a-preds.png", width(3000) replace

*****************
// Adding distributional information //
*****************
// Allow the age effect to differ for men and women
regress 	wages c.age##c.age##i.woman i.college i.race
qui margins, at(age=(18(2)90) woman=(0 1))

// 9.b - Histogram to show distribution of age
marginsplot, plotopts(msym(i)) ///
	recastci(rline) ciopts(lpat(dash) col(gs12)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[9.b] Predicted Hourly Wages Based on Age of Worker") ///
	addplot(hist age, width(1) lcol(gs10) ///
	fcol(none) yaxis(2) yscale(range(0 0.15) off alt axis(2)) ///
	legend(order(3 "Men" 4 "Women")) xlab(20(10)90) ylab(0(5)30))

	graph export "- Figures/dmv-09_b-preds_hist.png", width(3000) replace

// Generate variables to make rugs on plot
gen 	pipe = "|" if age != .	// What rug looks like
gen 	agerand = age + rnormal(0,1) // "jitter" age
gen 	where =  0				// Where on y-axis to put 1st rug
gen 	where2 = 1.2			// Where on y-axis to put 2nd rug

// 9.c - Rug plots: separate rugs for men and women (faded colors)
marginsplot, plotopts(msym(i)) ///
	recastci(rline) ciopts(lpat(dash) col(gs12)) ///
	ytitle("Hourly Wages") xtitle("Age in Years") ///
	title("[9.c] Predicted Hourly Wages Based on Age of Worker") ///
	addplot(scatter where2 agerand if woman == 0, ///
		ms(none) mlabel(pipe) mlabcol(red*.6) mlabpos(0) || ///
	scatter where agerand if woman == 1, ///
		ms(none) mlabel(pipe) mlabcol(eltblue*.6) mlabpos(0) ///
	legend(order(3 "Men" 4 "Women")) xlab(20(10)90) ylab(0(5)30))

	graph export "- Figures/dmv-09_c-preds_rug.png", width(3000) replace

*****************
// Plots for nominal IVs //
*****************
use 		"https://tdmize.github.io/data/data/cda_gss.dta", clear

tab 		samesexop
gen 		samesexAW = samesexop
lab var		samesexAW "Same Sex Relationship Always Wrong"
recode		samesexAW 1=1 	2/4 = 0
lab def		ssaw 0"Not Always Wrong" 1"Always Wrong"
lab val		samesexAW ssaw
tab 		samesexop samesexAW

drop if missing(samesexAW, reltrad, woman, college, race3, faminc, age, year)

tab 		samesexAW
tab 		reltrad

*Omitting Catholic -- Only including surveys beginning in 2000
logit 		samesexAW ib4.reltrad i.woman i.college i.race3 c.faminc c.age ///
			if year >= 2000

*Get predictions for each category
margins reltrad

// 9.d - Use recast(scatter) for a dot plot for a nominal IV
marginsplot, recast(scatter) ylab(0(.2)1) ciopts(col(*.4)) xtitle(" ") ///
	xlab(, angle(45)) ytitle("Pr(Always Wrong)") ///
	title("[9.d] Predicted Probability of Viewing Same-Sex Relationships As 'Always Wrong'", size(medium)) ///
	subtitle("By Religious Affiliation")

	graph export "- Figures/dmv-09_d-preds_nominal.png", width(3000) replace

// 9.e - DON'T DO THIS! marginsplot's default connects lines for a nominal IV
marginsplot, ylab(0(.2)1) ciopts(col(*.4)) xtitle(" ") ///
	xlab(, angle(45)) ytitle("Pr(Always Wrong)") ///
	title("[9.e] {bf:Don't Do This:} Do Not Connect Lines of Predictions for Nominal IVs", size(medium)) ///
	subtitle("Connected lines suggest a continuous IV which this is not")

	graph export "- Figures/dmv-09_e-preds_nominal-BAD.png", width(3000) replace

// 9.f - A bar chart is an equally good alternative
marginsplot, recast(bar) plotopts(barw(.6) color(ltblue)) ylab(0(.2)1) ciopts(color(gs8)) ///
	xtitle(" ") xlab(, angle(45)) ytitle("Pr(Always Wrong)") ///
	title("[9.f] Predicted Probability of Viewing Same-Sex Relationships As 'Always Wrong'", size(medium)) ///
	subtitle("By Religious Affiliation")

	graph export "- Figures/dmv-09_f-preds_nominal_bar.png", width(3000) replace

*****************
// Confidence intervals and statistical significance //
*****************
// Simulated data: two groups (b = 0 vs b = 1) with a true difference of 5
clear
set seed 	30004
set obs 	1000

gen 		b = .
replace 	b = 0 in 1/500
replace 	b = 1 in 501/1000
gen 		y10 = 50 + 5*b + rnormal(0,10)
gen 		y20 = 50 + 5*b + rnormal(0,20)
gen 		y25 = 50 + 5*b + rnormal(0,25)
gen 		y30 = 50 + 5*b + rnormal(0,30)

* Estimate the models and save the predictions for each outcome
foreach y in y30 y20 y25 {
	reg 		`y' i.b
	margins, 	at(b=(0 1)) post
	est store 	pr_`y'
	lincom 		2._at - 1._at		// test of the difference in predictions
}

*****************
// Without the significance tests: which differences are significant? //
*****************
// 9.g - Error term has SD of 30
est restore pr_y30
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.g] Predictions and 95% Confidence Intervals - Linear Regression Model")

	graph export "- Figures/dmv-09_g-CIs_y30.png", width(3000) replace

// 9.h - Error term has SD of 20
est restore pr_y20
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.h] Predictions and 95% Confidence Intervals - Linear Regression Model")

	graph export "- Figures/dmv-09_h-CIs_y20.png", width(3000) replace

// 9.i - Error term has SD of 25
est restore pr_y25
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.i] Predictions and 95% Confidence Intervals - Linear Regression Model")

	graph export "- Figures/dmv-09_i-CIs_y25.png", width(3000) replace

*****************
// With the significance tests //
*****************
// 9.j - Error term has SD of 30
est restore pr_y30
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.j] Predictions and 95% Confidence Intervals - Linear Regression Model") ///
	subtitle("Group Difference (b{sub: 0} vs b{sub: 1}) is significant: {it: p} < 0.001 (two-tailed test)")

	graph export "- Figures/dmv-09_j-CIs_y30_p.png", width(3000) replace

// 9.k - Error term has SD of 20
est restore pr_y20
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.k] Predictions and 95% Confidence Intervals - Linear Regression Model") ///
	subtitle("Group Difference (b{sub: 0} vs b{sub: 1}) is significant: {it: p} = 0.011 (two-tailed test)")

	graph export "- Figures/dmv-09_k-CIs_y20_p.png", width(3000) replace

// 9.l - Error term has SD of 25
est restore pr_y25
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.l] Predictions and 95% Confidence Intervals - Linear Regression Model") ///
	subtitle("Group Difference (b{sub: 0} vs b{sub: 1}) is significant: {it: p} = 0.032 (two-tailed test)")

	graph export "- Figures/dmv-09_l-CIs_y25_p.png", width(3000) replace

// 9.m - Add significance info to the graph using the text( ) option
*NOTE: specify the y-x coordinates for where to place text
coefplot, vertical ciop(recast(rcap) col(gs10)) ylab(45(1)60) ///
	xlab(1 "b = 0" 2 "b = 1") ytitle("y-hat") ///
	title("[9.m] Predictions and 95% Confidence Intervals - Linear Regression Model") ///
	text(53 1.5 "diff {it:p} = 0.032")

	graph export "- Figures/dmv-09_m-CIs_y25_text.png", width(3000) replace



**********************************************************
//#10 - Don't assume linearity
**********************************************************
use 	"https://tdmize.github.io/data/data/hrs_si.dta", clear

*****************
// Scatterplots //
*****************
// 10.a - Basic scatterplot doesn't work because of overlapping data points
twoway scatter dzcount age, ///
    title("[10.a] Relationship between number of chronic diseases and age") ///
    xtitle("Age") ytitle("Number of chronic diseases") ///
    xlabel(20(10)100)

	graph export "- Figures/dmv-10_a-scatterplot.png", width(3000) replace

// 10.b - Jitter (random noise) points to prevent overlap
twoway scatter dzcount age, jitter(3) ///
    title("[10.b] Relationship between number of chronic diseases and age") ///
    subtitle("Data points have been jittered to prevent overlap") ///
    xtitle("Age") ytitle("Number of chronic diseases") ///
    xlabel(20(10)100)

	graph export "- Figures/dmv-10_b-scatterplot-jitter.png", width(3000) replace

// 10.c - Binned scatterplot: mean of y within 20 equal-sized bins of x
binscatter dzcount age, linetype(none) mcolors(red*1.2) ///
    title("[10.c] Binned scatterplot for number of chronic diseases by age") ///
    subtitle("Each point is the mean in one of 20 equal-sized age groups") ///
    xtitle("Age") ytitle("Number of chronic diseases") ///
    xlabel(20(10)100) ylabel(0(.5)3)
	
*Because so many older adults, most bins are at older ages. Create own bin
**variable to see more of age range
*3-year age bins, coded at the bin midpoint (18-20 = 19, 21-23 = 22, ...)
gen 	age3 = floor(age/3)*3 + 1
label var age3 "Age (3-year bins, midpoint)"

*check: min and max age in each bin
tabstat age, by(age3) stat(min max mean n)

binscatter dzcount age, linetype(none) mcolors(red*1.2) xq(age3) ///
    title("[10.c] Binned scatterplot for number of chronic diseases by age") ///
    subtitle("Each bin is a 3-year range of age") ///
    xtitle("Age") ytitle("Number of chronic diseases") ///
    xlabel(20(10)100) ylabel(0(.5)3)	

	graph export "- Figures/dmv-10_c-binscatter.png", width(3000) replace

	
************************
// Smoothed trend lines //
************************
// 10.d - Linear regression line overlaid on scatterplot
twoway ///
    (scatter dzcount age, jitter(3) mcolor(gs12)) ///
    (lfit dzcount age, lcolor(red)), ///
    legend(off) xlabel(20(10)100) ///
    title("[10.d] Relationship between number of chronic diseases and age") ///
    subtitle("With linear trend line") ///
    xtitle("Age") ytitle("Number of chronic diseases")

	graph export "- Figures/dmv-10_d-scatterplot-linear_fit.png", width(3000) replace

// 10.e - Quadratic regression line (x and x^2) overlaid on scatterplot
twoway ///
    (scatter dzcount age, jitter(2) mcolor(gs12)) ///
    (qfit dzcount age, lcolor(red)), ///
    legend(off) xlabel(20(10)100) ///
    title("[10.e] Relationship between number of chronic diseases and age") ///
    subtitle("With quadratic trend line") ///
    xtitle("Age") ytitle("Number of chronic diseases")

	graph export "- Figures/dmv-10_e-scatterplot-quadratic_fit.png", width(3000) replace

// 10.f - Lowess smoothed fit line (2022 wave only)
twoway ///
    (scatter dzcount age if year == 2022, jitter(2) mcolor(gs12)) ///
    (lowess dzcount age if year == 2022, bwidth(.4) lcolor(red)), ///
    legend(off) xlabel(20(10)100) ///
    title("[10.f] Relationship between number of chronic diseases and age") ///
    subtitle("With lowess trend line (bandwidth = 0.4)") ///
    xtitle("Age") ytitle("Number of chronic diseases")

	graph export "- Figures/dmv-10_f-scatterplot-lowess_fit.png", width(3000) replace

**********************************************************
//#Appendix - Model specification: continuous and ordinal IVs as nominal
**********************************************************
*********************
// Treating a continuous variable as nominal //
*********************
use 		"https://tdmize.github.io/data/data/cda_ah4.dta", clear

codebook 	role masterySS age income race exercisSS, c

// 10.g - Number of social roles entered as nominal
reg 		masterySS i.role ///
				c.age c.income i.race c.exercisSS

*Save predictions for later use
margins, 	at(role=(0(1)10)) saving(prs_nom, replace)

marginsplot, ///
	title("[10.g] Predicted mastery levels based on # of social roles held") ///
	ytitle("Mastery") xtitle("Number of Social Roles")

	graph export "- Figures/dmv-10_g-roles_nominal.png", width(3000) replace

// 10.h - Compare to roles and roles^2 (quadratic) specification
reg 		masterySS c.role##c.role ///
				c.age c.income i.race c.exercisSS

margins, 	at(role=(0(1)10)) saving(prs_sq, replace)

combomarginsplot prs_nom prs_sq, ///
    labels("Categorical Model" "Roles^2 Model") ///
	title("[10.h] Comparison of Predictions for Various Functional Forms of Roles") ///
	ytitle("Mastery") xtitle("Number of Social Roles") ///
	legend(pos(6) row(1))

	graph export "- Figures/dmv-10_h-roles_overlay.png", width(3000) replace

*****************
// Ordinal predictors: continuous or nominal specification? //
*****************
use 		"https://tdmize.github.io/data/data/cda_anes.dta", clear

drop if 	missing(vote_trump, age, hhincome, woman, lgb, race4, ///
					educ, relimport, wrongtrack)
tab 		relimport

// 10.i - Importance of religion entered as nominal
logit 		vote_trump 	i.educ i.relimport age hhincome i.woman ///
						i.lgb i.race4 i.wrongtrack
est store 	nom_rel

margins, at(relimport=(1(1)5)) saving(pr_rel_nom, replace)
marginsplot, ///
	xlab(1 "Ext. Important" 2 "Very Important" 3 "Moderately Important" ///
			4 "A Little Important" 5 "Not Important") graphregion(margin(r+5)) ///
	ytitle("Pr(support Trump)") xtitle("Importance of religion") ///
	title("[10.i] Pr(support Trump) by importance of religion -- Nominal specification")

	graph export "- Figures/dmv-10_i-relimport_nominal.png", width(3000) replace

// 10.j - Compare to importance of religion entered as continuous
logit 		vote_trump 	c.relimport i.educ age hhincome i.woman ///
						i.lgb i.race4 i.wrongtrack
est store 	con_rel

lrtest 		nom_rel con_rel

margins, at(relimport=(1(1)5)) saving(pr_rel_con, replace)

combomarginsplot pr_rel_nom pr_rel_con, ///
	labels("Nominal spec." "Continuous spec.") ytitle("Pr(support Trump)") ///
	xlab(1 "E. Important" 2 "V. Important" 3 "Mod. Important" ///
			4 "Little Important" 5 "Not Important") graphregion(margin(r+5)) ///
	xtitle("Importance of religion") ///
	title("[10.j] Pr(support Trump) by importance of religion - comparing IV specifications")

	graph export "- Figures/dmv-10_j-relimport_overlay.png", width(3000) replace



****************
log close
exit
****************
