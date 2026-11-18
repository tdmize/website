# MCAP Workshop 2026 - Data Visualization
# dmv-data_visualization-exs.R
# Trenton Mize 2026-11-18

library(foreign)            # load Stata datasets
library(ggplot2)            # main graphics package
library(dplyr)              # data manipulation tools
library(marginaleffects)    # predictions and marginal effects
library(modelsummary)       # coefficient plots & nice tables
library(remotes)            # installs packages from GitHub
install_github("tdmize/cleanplots")   # Mize's graphics scheme
library(cleanplots)         # Mize's graphics scheme

## Use cleanplots colors, markers, lines, and theme for all graphs ##
cleanplots_defaults()
theme_update(plot.title.position = "plot")   # titles start at left edge of graph

# setwd( )    # set your working directory
dir.create("- Figures", showWarnings = FALSE)   # folder for saved graphs



######################################################
# 0 - Load datasets
######################################################
# Anscombe's quartet
anscombe <- read.dta("https://tdmize.github.io/data/data/anscombe.dta")
# Add Health Data
ah <- read.dta("https://tdmize.github.io/data/data/ah_si.dta")
# Health and Retirement Study Data
hrs <- read.dta("https://tdmize.github.io/data/data/hrs_si.dta")
# Mize 2025 SPQ stereotypes data
cgr <- read.dta("https://tdmize.github.io/data/data/cgr.dta")
# droplevels( ) removes unused categories (e.g., "Refused") from factor variables
# Add Health Wave 4 Data
ah4 <- droplevels(read.dta("https://tdmize.github.io/data/data/addhealth4.dta"))
# Simulated data for interaction exs
intsim01 <- read.dta("https://tdmize.github.io/data/data/dmv_intsim01.dta")
intsim02 <- read.dta("https://tdmize.github.io/data/data/dmv_intsim02.dta")
# Pew 2016 election data
pew <- droplevels(read.dta("https://tdmize.github.io/data/data/pew16.dta"))
# General Social Survey Data
gss <- droplevels(read.dta("https://tdmize.github.io/data/data/gss.dta"))
# General Social Survey Data (religious tradition ex)
cda_gss <- droplevels(read.dta("https://tdmize.github.io/data/data/cda_gss.dta"))
# Add Health Wave 4 Data (social roles ex)
cda_ah4 <- droplevels(read.dta("https://tdmize.github.io/data/data/cda_ah4.dta"))
# American National Election Study 2020 Data
anes <- droplevels(read.dta("https://tdmize.github.io/data/data/cda_anes.dta"))

# Quick work to flag only those included in first HRS wave
ids_1992 <- hrs %>%
  filter(year == 1992) %>%
  pull(hhidpn) %>% unique()

hrs_filtered <- hrs %>%
  filter(hhidpn %in% ids_1992)



######################################################
# Introduction - Anscombe's quartet
######################################################
summary(anscombe[c("Ya", "Yb", "Yc", "Yd")])

amod1 <- lm(Ya ~ Xabc, data = anscombe)
amod2 <- lm(Yb ~ Xabc, data = anscombe)
amod3 <- lm(Yc ~ Xabc, data = anscombe)
amod4 <- lm(Yd ~ Xd, data = anscombe)
modelsummary(list(amod1, amod2, amod3, amod4), stars = TRUE)

# 0.a - Scatterplot of the data
ggplot(anscombe) +
  geom_point(aes(x = Xabc, y = Ya), color = cleanplots_colors("red"), size = 3) +
  geom_point(aes(x = Xabc, y = Yb), color = cleanplots_colors("ltblue"), size = 3) +
  geom_point(aes(x = Xabc, y = Yc), color = cleanplots_colors("gray"), size = 3) +
  geom_point(aes(x = Xd,   y = Yd), color = cleanplots_colors("black"), size = 3) +
  labs(x = "X", y = "Y",
       title = "[0.a] Anscombe's quartet - All y & x variables have same mean and SD")

cleanplots_save('- Figures/dmv-00_a-anscombe.png', width = 10, height = 5.6)

# 0.b - Add connected lines
ggplot(anscombe) +
  geom_point(aes(x = Xabc, y = Ya), color = cleanplots_colors("red"), size = 3) +
  geom_line( aes(x = Xabc, y = Ya), color = cleanplots_colors("red")) +
  geom_point(aes(x = Xabc, y = Yb), color = cleanplots_colors("ltblue"), size = 3) +
  geom_line( aes(x = Xabc, y = Yb), color = cleanplots_colors("ltblue")) +
  geom_point(aes(x = Xabc, y = Yc), color = cleanplots_colors("gray"), size = 3) +
  geom_line( aes(x = Xabc, y = Yc), color = cleanplots_colors("gray")) +
  geom_point(aes(x = Xd,   y = Yd), color = cleanplots_colors("black"), size = 3) +
  labs(x = "X", y = "Y",
       title = "[0.b] Anscombe's quartet - All y & x variables have same mean and SD")

cleanplots_save('- Figures/dmv-00_b-anscombe_lines.png', width = 10, height = 5.6)



######################################################
# 1 - Look at your data
######################################################

###############
## Histogram ##
###############
# 1.a - Frequency option to plot # of observations in each bin
ggplot(gss, aes(x = wages)) +
  geom_histogram(fill = NA, color = "gray20") +
  labs(x = "Wages", y = "Frequency",
       title = "[1.a] Histogram of Distribution of Hourly Wages",
       subtitle = "y-axis shows number of observations in bin") +
  scale_x_continuous(breaks = seq(0, 70, 10))

cleanplots_save('- Figures/dmv-01_a-hist.png', width = 10, height = 5.6)

###############
## Kernel Density Plot ##
###############
# 1.b - Overlay a kernel density plot on a histogram to illustrate what it does
# NOTE: Just pedagogical, not a graph you would usually make
ggplot(gss, aes(x = wages)) +
  geom_histogram(aes(y = after_stat(density)), fill = NA, color = "gray20") +
  geom_density(color = cleanplots_colors("red")) +
  labs(x = "Hourly Wages ($)", y = "Density",
       title = "[1.b] Distribution of Hourly Wages",
       subtitle = "Comparison of histogram and kernel density plot") +
  scale_x_continuous(breaks = seq(0, 70, 10))

cleanplots_save('- Figures/dmv-01_b-hist_kdensity.png', width = 10, height = 5.6)

# 1.c - Usually, just want the density and not the histogram too
ggplot(gss, aes(x = wages)) +
  geom_density() +
  labs(x = "Hourly Wages ($)", y = "Density",
       title = "[1.c] Kernel Density Plot of Hourly Wages") +
  scale_x_continuous(breaks = seq(0, 70, 10))

cleanplots_save('- Figures/dmv-01_c-kdensity.png', width = 10, height = 5.6)

###############
## Box plots ##
###############
# Top code drinks in the past year at 1,000
ah$numdrinksyrT <- pmin(ah$numdrinksyr, 1000)

# 1.d - Drinks in the past year, with separate boxes by wave
ggplot(ah, aes(x = wave, y = numdrinksyrT)) +
  geom_boxplot() +
  labs(x = "",
       y = "# of drinks in the past year",
       title = "[1.d] Box plot of drinks in the past year by wave of Add Health",
       subtitle = "Top coded at 1,000 drinks")

cleanplots_save('- Figures/dmv-01_d-boxplot.png', width = 10, height = 5.6)

# 1.e - Add a second grouping variable
ggplot(filter(ah, !is.na(male)), aes(x = wave, y = numdrinksyrT, fill = male)) +
  geom_boxplot() +
  coord_flip() +
  labs(x = "",
       y = "# of drinks in the past year", fill = "",
       title = "[1.e] Box plot of drinks in the past year by Add Health wave and gender",
       subtitle = "Top coded at 1,000 drinks")

cleanplots_save('- Figures/dmv-01_e-boxplot_by_gender.png', width = 10, height = 5.6)



######################################################
# 2 - Use graph types people read accurately
######################################################

##############
## 2.a - Pie charts (generally not recommended)
##############
ggplot(filter(hrs, !is.na(srhealth)), aes(x = "", fill = srhealth)) +
  geom_bar(width = 1) +
  coord_polar(theta = "y") +
  labs(title = "[2.a] Pie chart for distribution of self-rated health among older adults",
       fill = "") +
  scale_fill_viridis_d() +
  theme_void(base_size = 12)

cleanplots_save('- Figures/dmv-02_a-pie.png', width = 10, height = 5.6, bg = "white")

##############
## Stacked bar chart ##
##############
# 2.b - Stacked bar chart
ggplot(filter(hrs_filtered, !is.na(srhealth)), aes(y = "", fill = srhealth)) +
  geom_bar(position = position_fill(reverse = TRUE), width = .5) +
  labs(x = "Self-rated health", y = NULL, fill = "") +
  scale_fill_viridis_d(option = "cividis", direction = -1, end = .95) +
  theme(legend.position = "bottom")

cleanplots_save('- Figures/dmv-02_b-stack_bar.png', width = 8, height = 2)

# 2.c - Stacked bar chart with 1992 cohort
ggplot(filter(hrs_filtered, !is.na(srhealth)), aes(fill = srhealth, x = year)) +
  geom_bar(position = "fill") +
  labs(title = "[2.c] Stacked bar chart of self-rated health among older adults over time (HRS)",
       y = "Self-rated health", fill = "") +
  scale_fill_viridis_d(option = "cividis", direction = -1, end = .95)

cleanplots_save('- Figures/dmv-02_c-stack_bar.png', width = 10, height = 5.6)

##############
## Bar charts ##
##############
# 2.d - Bar chart for distribution of days drinking
ggplot(filter(hrs, !is.na(dayweekdrink)), aes(x = dayweekdrink)) +
  geom_bar() +
  labs(title = "[2.d] Bar chart for days usually drink each week (older adults, HRS)",
       x = "Days usually drink each week", y = "Count")

cleanplots_save('- Figures/dmv-02_d-bar.png', width = 10, height = 5.6)



######################################################
# 3 - Maximize the data-ink ratio, within reason (maybe)
######################################################
# Percent of men and of women in each category of days drinking
drink_pct <- hrs %>%
  filter(!is.na(dayweekdrink)) %>%
  count(woman, dayweekdrink) %>%
  group_by(woman) %>%
  mutate(pct = 100 * n / sum(n))

# 3.a - Dot plot for days drinking per week, by gender
ggplot(drink_pct, aes(x = factor(dayweekdrink), y = pct, color = woman)) +
  geom_point(size = 4.5, position = position_dodge(width = .3)) +
  labs(x = "Days usually drink each week", y = "Percent", color = "",
       title = "[3.a] Dot plot for days usually drink each week (older adults, HRS)",
       subtitle = "Percent of men and of women") +
  scale_y_continuous(breaks = seq(0, 80, 10), limits = c(0, 80))

cleanplots_save('- Figures/dmv-03_a-dot_gender.png', width = 10, height = 5.6)

# 3.b - Same information as a bar chart
ggplot(drink_pct, aes(x = factor(dayweekdrink), y = pct, fill = woman)) +
  geom_col(position = position_dodge(width = .8), width = .8) +
  labs(x = "Days usually drink each week", y = "Percent", fill = "",
       title = "[3.b] Bar chart for days usually drink each week (older adults, HRS)",
       subtitle = "Percent of men and of women") +
  scale_y_continuous(breaks = seq(0, 80, 10), limits = c(0, 80))

cleanplots_save('- Figures/dmv-03_b-bar_gender.png', width = 10, height = 5.6)



######################################################
# 4 - Show uncertainty
######################################################
# 4.a - Add 95% confidence intervals to the bar chart (2022 wave)
ggplot(filter(hrs, year == 2022), aes(x = dayweekdrink, y = cesd)) +
  stat_summary(fun = mean, geom = "bar", fill = cleanplots_colors("ltblue", bars = TRUE),
               width = .7) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = .3, color = "gray50") +
  labs(x = "Days drinking alcohol per week",
       y = "Depressive symptoms",
       title = "[4.a] Average number of depressive symptoms",
       subtitle = "By number of days drinking per week (95% confidence intervals)") +
  scale_y_continuous(breaks = seq(0, 2, 0.5)) + coord_cartesian(ylim = c(0, 2))

cleanplots_save('- Figures/dmv-04_a-bar_y_CIs.png', width = 10, height = 5.6)

# 4.b - Recreate plot above but with a dot plot
ggplot(filter(hrs, year == 2022), aes(x = dayweekdrink, y = cesd)) +
  stat_summary(fun = mean, geom = "point", size = 3) +
  stat_summary(fun.data = mean_cl_normal, geom = "linerange", alpha = .5) +
  labs(x = "Days drinking alcohol per week",
       y = "Depressive symptoms",
       title = "[4.b] Average number of depressive symptoms",
       subtitle = "By number of days drinking per week (95% confidence intervals)") +
  scale_y_continuous(breaks = seq(0, 2, 0.5)) + coord_cartesian(ylim = c(0, 2))

cleanplots_save('- Figures/dmv-04_b-dot_y_CIs.png', width = 10, height = 5.6)



######################################################
# BREAK 1 - Group task
######################################################
# Load the data and make a quick graph. What does it show? How could it be better?
hrs <- read.dta("https://tdmize.github.io/data/data/hrs_si.dta")
ggplot(filter(hrs, !is.na(marstat), year == 2022), aes(x = marstat, y = lifesat)) +
  stat_summary(fun = mean, geom = "bar")

cleanplots_save('- Figures/dmv-B1_a-task.png', width = 10, height = 5.6)

# B1.b - A publication-quality version
ggplot(filter(hrs, !is.na(marstat), !is.na(lifesat), year == 2022),
       aes(x = marstat, y = lifesat)) +
  stat_summary(fun = mean, geom = "point", size = 3.6) +
  stat_summary(fun.data = mean_cl_normal, geom = "linerange", alpha = .5) +
  labs(x = "Marital status",
       y = "Life satisfaction (1 to 7)",
       title = "[B1.b] Average life satisfaction by marital status (older adults, HRS)",
       subtitle = "With 95% confidence intervals") +
  scale_y_continuous(breaks = seq(4, 5.5, .5)) + coord_cartesian(ylim = c(4, 5.5))

cleanplots_save('- Figures/dmv-B1_b-task_pub.png', width = 10, height = 5.6)



######################################################
# 5 - Make groups easy to tell apart
######################################################
# 5.a - Overlay multiple densities for different groups
# Use both colors and line patterns so the five groups are easy to tell apart
degree_labels <- c("< High School", "HS Degree", "Junior College",
                   "College Degree", "Grad Degree")

ggplot(filter(gss, !is.na(degree)), aes(x = wages, color = degree, linetype = degree)) +
  geom_density(key_glyph = "path") +
  labs(x = "Hourly Wages", y = "Density", color = "", linetype = "",
       title = "[5.a] Kernel-Density Plots of Hourly Wages Based on Educational Attainment",
       subtitle = "Densities are group specific") +
  scale_color_cleanplots(labels = degree_labels) +
  scale_linetype_cleanplots(labels = degree_labels) +
  scale_x_continuous(breaks = seq(0, 70, 10))

cleanplots_save('- Figures/dmv-05_a-kdensity_groups.png', width = 10, height = 5.6)

# 5.b - Mean cognitive test score by year, separately for men and women
# position_dodge( ) offsets the groups so their confidence intervals do not overlap
dodge <- position_dodge(width = .5)

ggplot(filter(hrs_filtered, !is.na(cog)),
       aes(x = factor(year), y = cog, color = woman, group = woman)) +
  stat_summary(fun = mean, geom = "point", size = 2.5, position = dodge) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = .2, position = dodge) +
  labs(x = "Year", y = "Cognitive test score", color = "",
       title = "[5.b] Performance on a cognitive test over time, by gender",
       subtitle = "Means and 95% confidence intervals") +
  scale_y_continuous(breaks = seq(12, 18, 1)) + coord_cartesian(ylim = c(12, 18))

cleanplots_save('- Figures/dmv-05_b-dot_cog_gender.png', width = 10, height = 5.6)

# 5.c - Many groups: need to change marker shapes in addition to color
dodge <- position_dodge(width = .8)

ggplot(filter(hrs_filtered, !is.na(cog), !is.na(degree)),
       aes(x = factor(year), y = cog, color = degree, shape = degree, group = degree)) +
  stat_summary(fun = mean, geom = "point", size = 2, position = dodge) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar",
               width = 0.2, position = dodge) +
  labs(x = "Year",
       y = "Cognitive test score",
       color = "", shape = "",
       title = "[5.c] Performance on a cognitive test over time, by education",
       subtitle = "Means and 95% confidence intervals") +
  scale_shape_cleanplots() +
  scale_y_continuous(breaks = seq(10, 20, 2)) + coord_cartesian(ylim = c(10, 20))

cleanplots_save('- Figures/dmv-05_c-dot_cog_educ.png', width = 10, height = 5.6)

# 5.d & 5.e - Calculate experimental condition means
means_by_condition <- cgr %>%
  filter(ordcond == "Second Order") %>%
  droplevels() %>%
  group_by(cond) %>%
  summarise(mean_warmth     = mean(warmSS, na.rm = TRUE),
            mean_competence = mean(compSS, na.rm = TRUE))

# 5.d - Too many colors to understand (not recommended)
ggplot(means_by_condition, aes(x = mean_competence, y = mean_warmth, color = cond)) +
  geom_point(size = 3) +
  scale_color_hue() +    # a distinct color for each of the 26 groups
  labs(x = "Competence", y = "Warmth", color = "",
       title = "[5.d] Warmth and competence stereotypes of gender X racial-ethnic groups") +
  scale_x_continuous(breaks = seq(3, 7, 1), limits = c(3, 7)) +
  scale_y_continuous(breaks = seq(3, 7, 1), limits = c(3, 7))

cleanplots_save('- Figures/dmv-05_d-scatter_colors.png', width = 10, height = 5.6)

# 5.e - With so many groups, better to just directly label points
ggplot(means_by_condition, aes(x = mean_competence, y = mean_warmth, label = cond)) +
  geom_point(size = 3) +
  geom_text(vjust = -0.8, size = 3.5) +
  labs(x = "Competence", y = "Warmth",
       title = "[5.e] Warmth and competence stereotypes of gender X racial-ethnic groups") +
  scale_x_continuous(breaks = seq(3, 7, 1), limits = c(3, 7)) +
  scale_y_continuous(breaks = seq(3, 7, 1), limits = c(3, 7))

cleanplots_save('- Figures/dmv-05_e-scatter_labels.png', width = 10, height = 5.6)

# 5.f - Ordinal (viridis) palette for an ordered variable
ggplot(filter(hrs, !is.na(dzcount), !is.na(degree)),
       aes(x = degree, y = dzcount, fill = degree)) +
  stat_summary(fun = mean, geom = "bar", width = 0.65) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = 0.2) +
  labs(x = "Educational degree",
       y = "Count of chronic diseases",
       title = "[5.f] Average chronic disease count by educational attainment",
       subtitle = "Colors are from viridis palette") +
  theme(legend.position = "none") +
  scale_fill_viridis_d(direction = -1)

cleanplots_save('- Figures/dmv-05_f-color_viridis.png', width = 10, height = 5.6)



######################################################
# 6 - Choose axes that fit the data
######################################################
# Predicted wages by educational attainment (employed young adults)
ah4_emp <- filter(ah4, employed == "Yes", !is.na(educ))

quantile(ah4_emp$wages, c(.05, .10, .90, .95))

# 6.a - y-axis covers the observed range in data
ggplot(ah4_emp, aes(x = educ, y = wages)) +
  stat_summary(fun = mean, geom = "point", size = 3) +
  labs(x = "", y = "Hourly Wages in $",
       title = "[6.a] Predicted Hourly Wages Based on Educational Attainment",
       subtitle = "y-axis range = range of observed values in data") +
  scale_x_discrete(labels = scales::label_wrap(12)) +
  scale_y_continuous(breaks = seq(0, 500, 50), limits = c(0, 500))

cleanplots_save('- Figures/dmv-06_a-yaxis_range.png', width = 10, height = 5.6)

# 6.b - y-axis covers the 10th to 90th percentile of data
ggplot(ah4_emp, aes(x = educ, y = wages)) +
  stat_summary(fun = mean, geom = "point", size = 3) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = .2) +
  labs(x = "", y = "Hourly Wages in $",
       title = "[6.b] Predicted Hourly Wages Based on Educational Attainment",
       subtitle = "y-axis range = 10th to 90th percentile of observed values in data") +
  scale_x_discrete(labels = scales::label_wrap(12)) +
  scale_y_continuous(breaks = seq(5, 30, 5)) + coord_cartesian(ylim = c(5, 30))

cleanplots_save('- Figures/dmv-06_b-yaxis_10-90th.png', width = 10, height = 5.6)

# 6.c - y-axis covers the 5th to 95th percentile of data
ggplot(ah4_emp, aes(x = educ, y = wages)) +
  stat_summary(fun = mean, geom = "point", size = 3) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = .2) +
  labs(x = "", y = "Hourly Wages in $",
       title = "[6.c] Predicted Hourly Wages Based on Educational Attainment",
       subtitle = "y-axis range = 5th to 95th percentile of observed values in data") +
  scale_x_discrete(labels = scales::label_wrap(12)) +
  scale_y_continuous(breaks = seq(0, 40, 5)) + coord_cartesian(ylim = c(0, 40))

cleanplots_save('- Figures/dmv-06_c-yaxis_5-95th.png', width = 10, height = 5.6)



######################################################
# 7 - Design for your audience
######################################################
# Ex graph for font and theme examples
gss_emp <- droplevels(filter(gss, year >= 2000, employed == 1))

wage_int <- lm(wages ~ poly(age, 2, raw = TRUE) * woman + college + race, data = gss_emp)
fig7 <- plot_predictions(wage_int, condition = c("age", "woman")) +
  labs(x = "Age in Years", y = "Hourly Wages", color = "", fill = "",
       title = "[7.#] Predicted Hourly Wages Based on Age of Worker") +
  scale_x_continuous(breaks = seq(20, 90, 10)) +
  scale_y_continuous(breaks = seq(0, 30, 5)) + coord_cartesian(ylim = c(0, 30))

##############
## Fonts
##############
# Note: windowsFonts( ) or the extrafont package add more fonts to use
# https://cran.r-project.org/web/packages/extrafont/readme/README.html

# 7.a - Arial
fig7 + theme(text = element_text(family = "Arial")) +
  labs(title = "[7.a] Predicted Hourly Wages Based on Age of Worker",
       subtitle = "Font: Arial")

cleanplots_save('- Figures/dmv-07_a-font_arial.png', width = 10, height = 5.6)

# 7.b - Cambria
fig7 + theme(text = element_text(family = "Cambria")) +
  labs(title = "[7.b] Predicted Hourly Wages Based on Age of Worker",
       subtitle = "Font: Cambria")

cleanplots_save('- Figures/dmv-07_b-font_cambria.png', width = 10, height = 5.6)

##############
## Graphics themes
##############
# 7.c - ggplot2's default theme and colors
fig7 + theme_gray() + scale_color_hue() + scale_fill_hue() +
  labs(title = "[7.c] Predicted Hourly Wages Based on Age of Worker",
       subtitle = "Graphics theme: theme_gray (ggplot2 default)")

cleanplots_save('- Figures/dmv-07_c-theme_gray.png', width = 10, height = 5.6)

# 7.d - theme_minimal
fig7 + theme_minimal() + scale_color_hue() + scale_fill_hue() +
  labs(title = "[7.d] Predicted Hourly Wages Based on Age of Worker",
       subtitle = "Graphics theme: theme_minimal")

cleanplots_save('- Figures/dmv-07_d-theme_minimal.png', width = 10, height = 5.6)

# 7.e - cleanplots (the default after cleanplots_defaults())
fig7 +
  labs(title = "[7.e] Predicted Hourly Wages Based on Age of Worker",
       subtitle = "Graphics theme: cleanplots")

cleanplots_save('- Figures/dmv-07_e-theme_cleanplots.png', width = 10, height = 5.6)



######################################################
# 8 - Use graphs, not tables, for model results
######################################################

# b is a binary (0/1) group variable
intsim01$b <- factor(intsim01$b)
intsim02$b <- factor(intsim02$b)

############
## Ex 1: Linear Regression with Interaction ##
############
mod1a <- lm(y ~ b + c, data = intsim01)
mod1b <- lm(y ~ b * c, data = intsim01)
mod1c <- lm(y ~ b * c + x1, data = intsim01)
modelsummary(list(mod1a, mod1b, mod1c), stars = TRUE)

# 8.a - Plot the predictions
plot_predictions(mod1c, condition = c("c", "b")) +
  geom_rug(data = intsim01, mapping = aes(x = c), sides = "b", alpha = 0.3,
           inherit.aes = FALSE) +
  geom_hline(yintercept = 0) +
  labs(x = "c", y = "Predicted y", color = "b", fill = "b",
       title = "[8.a] Predictions from linear regression that includes b*c product term")

cleanplots_save('- Figures/dmv-08_a-preds_int_linear.png', width = 10, height = 5.6)

############
## Ex 2: Binary Logit with Interaction ##
############
mod2a <- glm(y ~ b + c, family = binomial, data = intsim02)
mod2b <- glm(y ~ b * c, family = binomial, data = intsim02)
mod2c <- glm(y ~ b * c + x1, family = binomial, data = intsim02)
modelsummary(list(mod2a, mod2b, mod2c), stars = TRUE)

# 8.b - Plot the predictions
plot_predictions(mod2c, condition = c("c", "b"), rug = TRUE) +
  labs(x = "c", y = "Predicted probability", color = "b", fill = "b",
       title = "[8.b] Predictions from binary logit model that includes b*c product term")

cleanplots_save('- Figures/dmv-08_b-preds_int_logit.png', width = 10, height = 5.6)

##############
## Coefficient plots
##############
# Subjective class standing is a 1 to 10 scale
ah4$subjclass <- as.numeric(ah4$subjclass)

# 8.c - Coefficients from a linear regression model
reg_sc <- lm(subjclass ~ woman + race3 + age + income + college + workstat, data = ah4)

modelplot(reg_sc, coef_omit = "Intercept") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray20") +
  scale_x_continuous(breaks = seq(-1, 1.5, .5)) +
  scale_y_discrete(limits = rev) +
  labs(title = "[8.c] Predictors of Subjective Class Standing - Linear Regression",
       caption = "Effects above zero indicate higher subjective class standing")

cleanplots_save('- Figures/dmv-08_c-coefplot.png', width = 10, height = 5.6)

# 8.d - Fit separate models for men and women
reg_men <- lm(subjclass ~ race3 + age + income + college + workstat,
              data = subset(ah4, woman == "Man"))
reg_wom <- lm(subjclass ~ race3 + age + income + college + workstat,
              data = subset(ah4, woman == "Woman"))

mp_gender <- modelplot(list("Men" = reg_men, "Women" = reg_wom),
                       coef_omit = "Intercept", draw = FALSE)

ggplot(mp_gender, aes(x = estimate, y = term, color = model)) +
  geom_linerange(aes(xmin = conf.low, xmax = conf.high), alpha = .5,
                 position = position_dodge(width = .5)) +
  geom_point(size = 2.5, position = position_dodge(width = .5)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray20") +
  scale_x_continuous(breaks = seq(-1, 1.5, .5)) +
  scale_y_discrete(limits = rev) +
  labs(x = "Coefficient estimates and 95% confidence intervals", y = "", color = "",
       title = "[8.d] Predictors of Subjective Class Standing - Linear Regression",
       subtitle = "Separate Models for Men and Women",
       caption = "Effects above zero indicate higher subjective class standing")

cleanplots_save('- Figures/dmv-08_d-coefplot_by_gender.png', width = 10, height = 5.6)

##############
## Coefficient plots of marginal effects
##############
# Bachelor's degree and the South as reference groups (as in Stata ex)
pew$educ   <- relevel(pew$educ, ref = "Bachelors Degree")
pew$region <- relevel(pew$region, ref = "South")

logit_trump <- glm(trump ~ woman + age + educ + religB + income + region,
                   family = binomial, data = pew)

# Average marginal effects (AMEs) for all predictors
ames <- avg_slopes(logit_trump)
ames

# Nominal predictors in the model: rename the estimates so each is unique
ames$term <- paste(ames$term, ames$contrast)

# 8.e - Coefficient plot of the AMEs
modelplot(ames) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray20") +
  scale_x_continuous(breaks = seq(-.4, .4, .1)) +
  labs(x = "Average marginal effect",
       title = "[8.e] Binary Logit: Average Marginal Effects of Support for Trump vs Clinton",
       caption = "Effects above zero indicate more support for Trump")

cleanplots_save('- Figures/dmv-08_e-ames.png', width = 10, height = 5.6)



######################################################
# BREAK 2 - Group task
######################################################
# Fit a model and make a quick graph. What does it show? How could it be better?
gss <- droplevels(read.dta("https://tdmize.github.io/data/data/gss.dta"))
reg_op <- lm(occprest ~ age + income + woman + college + race, data = gss)
modelplot(reg_op)

cleanplots_save('- Figures/dmv-B2_a-task.png', width = 10, height = 5.6)

# B2.b - A publication-quality version
# Show effects of the continuous IVs for a 2 standard deviation increase
gss_op <- filter(gss, !is.na(occprest), !is.na(age), !is.na(income), !is.na(woman),
                 !is.na(college), !is.na(race))
gss_op$age_2sd    <- gss_op$age / (2 * sd(gss_op$age))
gss_op$income_2sd <- gss_op$income / (2 * sd(gss_op$income))
reg_op2 <- lm(occprest ~ age_2sd + income_2sd + woman + college + race, data = gss_op)

modelplot(reg_op2, coef_omit = "Intercept",
          coef_rename = c("age_2sd" = "Age (+2 SD)", "income_2sd" = "Income (+2 SD)",
                          "womanWomen" = "Women",
                          "collegeCollege Degree" = "College degree",
                          "raceblack" = "Black", "raceother" = "Other race")) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray20") +
  scale_y_discrete(limits = rev) +
  labs(x = "Difference in occupational prestige",
       title = "[B2.b] Predictors of Occupational Prestige - Linear Regression",
       caption = "Age and income effects shown for a 2 standard deviation increase")

cleanplots_save('- Figures/dmv-B2_b-task_pub.png', width = 10, height = 5.6)



######################################################
# 9 - Show what the model predicts
######################################################
gss_emp <- droplevels(filter(gss, year >= 2000, employed == 1))

# Linear regression model with age and age-squared
wage_mod <- lm(wages ~ poly(age, 2, raw = TRUE) + woman + college + race, data = gss_emp)

# 9.a - Plot predictions for age
plot_predictions(wage_mod, condition = "age") +
  labs(x = "Age in Years", y = "Hourly Wages",
       title = "[9.a] Predicted Hourly Wages Based on Age of Worker") +
  scale_x_continuous(breaks = seq(20, 90, 10)) +
  scale_y_continuous(breaks = seq(0, 30, 5)) + coord_cartesian(ylim = c(0, 30))

cleanplots_save('- Figures/dmv-09_a-preds.png', width = 10, height = 5.6)

##############
## Adding distributional information
##############
# Allow the age effect to differ for men and women
wage_int <- lm(wages ~ poly(age, 2, raw = TRUE) * woman + college + race, data = gss_emp)

# 9.b - Add a histogram of age to the bottom of the plot
plot_predictions(wage_int, condition = c("age", "woman")) +
  geom_histogram(data = gss_emp, binwidth = 1, fill = NA, color = "gray70",
                 aes(x = age, y = after_stat(count / max(count) * 5)),
                 inherit.aes = FALSE) +
  labs(x = "Age in Years", y = "Hourly Wages", color = "", fill = "",
       title = "[9.b] Predicted Hourly Wages Based on Age of Worker") +
  scale_x_continuous(breaks = seq(20, 90, 10)) +
  scale_y_continuous(breaks = seq(0, 30, 5)) + coord_cartesian(ylim = c(0, 30))

cleanplots_save('- Figures/dmv-09_b-preds_hist.png', width = 10, height = 5.6)

# 9.c - Rug plot: "jitter" age so can better see where the data is; colors faded
dat_rug <- insight::get_data(wage_int)                          # estimation sample
dat_rug$age_j <- dat_rug$age + runif(nrow(dat_rug), -0.4, 0.4)  # jitter
dat_rug$rug_y <- ifelse(dat_rug$woman == "Men", 1.2, 0)         # men's rug above women's

plot_predictions(wage_int, condition = c("age", "woman")) +
  geom_point(data = dat_rug, aes(x = age_j, y = rug_y, color = woman), shape = "|",
             size = 3, alpha = 0.06, inherit.aes = FALSE, show.legend = FALSE) +
  labs(x = "Age in Years", y = "Hourly Wages", color = "", fill = "",
       title = "[9.c] Predicted Hourly Wages Based on Age of Worker",
       subtitle = "With rug plot to show distribution of age (jittered)") +
  scale_x_continuous(breaks = seq(20, 90, 10)) +
  scale_y_continuous(breaks = seq(0, 30, 5)) + coord_cartesian(ylim = c(0, 30))

cleanplots_save('- Figures/dmv-09_c-preds_rug.png', width = 10, height = 5.6)

##############
## Plots for nominal IVs
##############
# DV: same-sex relationships are always wrong (1) vs not (0)
cda_gss$samesexAW <- as.numeric(cda_gss$samesexop == "always wrong")

gss_rel <- cda_gss %>%
  filter(year >= 2000) %>%
  filter(!is.na(samesexAW), !is.na(reltrad), !is.na(woman), !is.na(college),
         !is.na(race3), !is.na(faminc), !is.na(age)) %>%
  droplevels()

logit_rel <- glm(samesexAW ~ reltrad + woman + college + race3 + faminc + age,
                 family = binomial, data = gss_rel)

# 9.d - The default plot for a nominal IV is a dot plot (which is good)
plot_predictions(logit_rel, condition = "reltrad") +
  labs(x = "", y = "Pr(Always Wrong)",
       title = "[9.d] Predicted Probability of Viewing Same-Sex Relationships As 'Always Wrong'",
       subtitle = "By Religious Affiliation") +
  scale_y_continuous(breaks = seq(0, 1, .2), limits = c(0, 1)) +
  scale_x_discrete(guide = guide_axis(angle = 45))

cleanplots_save('- Figures/dmv-09_d-preds_nominal.png', width = 10, height = 5.6)

# 9.e - DON'T DO THIS! Connected lines suggest a continuous IV, which this is not
pred_rel <- plot_predictions(logit_rel, condition = "reltrad", draw = FALSE)

ggplot(pred_rel, aes(x = reltrad, y = estimate, group = 1)) +
  geom_line() +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = .2) +
  labs(x = "", y = "Pr(Always Wrong)",
       title = "[9.e] Don't Do This: Do Not Connect Lines of Predictions for Nominal IVs",
       subtitle = "Connected lines suggest a continuous IV which this is not") +
  scale_y_continuous(breaks = seq(0, 1, .2), limits = c(0, 1)) +
  scale_x_discrete(guide = guide_axis(angle = 45))

cleanplots_save('- Figures/dmv-09_e-preds_nominal-BAD.png', width = 10, height = 5.6)

# 9.f - A bar chart is an equally good alternative
ggplot(pred_rel, aes(x = reltrad, y = estimate)) +
  geom_col(fill = cleanplots_colors("ltblue", bars = TRUE), width = .6) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = .2, color = "gray40") +
  labs(x = "", y = "Pr(Always Wrong)",
       title = "[9.f] Predicted Probability of Viewing Same-Sex Relationships As 'Always Wrong'",
       subtitle = "By Religious Affiliation") +
  scale_y_continuous(breaks = seq(0, 1, .2), limits = c(0, 1)) +
  scale_x_discrete(guide = guide_axis(angle = 45))

cleanplots_save('- Figures/dmv-09_f-preds_nominal_bar.png', width = 10, height = 5.6)

##############
## Confidence intervals and statistical significance
##############
# Simulated data: two groups (b = 0 vs b = 1) with a true difference of 5
# R and Stata draw different random numbers; this seed gives the same pattern as Stata's
set.seed(43940)
sim <- data.frame(b = factor(rep(c(0, 1), each = 500)))
sim$y10 <- 50 + 5 * (sim$b == 1) + rnorm(1000, 0, 10)
sim$y20 <- 50 + 5 * (sim$b == 1) + rnorm(1000, 0, 20)
sim$y25 <- 50 + 5 * (sim$b == 1) + rnorm(1000, 0, 25)
sim$y30 <- 50 + 5 * (sim$b == 1) + rnorm(1000, 0, 30)

# Plot predictions and CIs for the two groups; optionally show the test of the difference
ci_plot <- function(y, label, show_p = FALSE) {
  m <- lm(reformulate("b", y), data = sim)
  p <- avg_comparisons(m, variables = "b")$p.value
  ggplot(avg_predictions(m, variables = "b"), aes(x = b, y = estimate)) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = .1, color = "gray60") +
    scale_x_discrete(labels = c("b = 0", "b = 1")) +
    scale_y_continuous(breaks = seq(45, 60, 1)) + coord_cartesian(ylim = c(45, 60)) +
    labs(x = "", y = "y-hat",
         title = paste0("[", label, "] Predictions and 95% Confidence Intervals - Linear Regression Model"),
         subtitle = if (show_p) paste0("Group Difference (b0 vs b1) is significant: ",
                                       ifelse(p < .001, "p < 0.001", paste("p =", round(p, 3))),
                                       " (two-tailed test)"))
}

# Without the significance tests: which differences are significant?
# 9.g - Error term has SD of 30
ci_plot("y30", "9.g")
cleanplots_save('- Figures/dmv-09_g-CIs_y30.png', width = 10, height = 5.6)

# 9.h - Error term has SD of 20
ci_plot("y20", "9.h")
cleanplots_save('- Figures/dmv-09_h-CIs_y20.png', width = 10, height = 5.6)

# 9.i - Error term has SD of 25
ci_plot("y25", "9.i")
cleanplots_save('- Figures/dmv-09_i-CIs_y25.png', width = 10, height = 5.6)

# With the significance tests
# 9.j - Error term has SD of 30
ci_plot("y30", "9.j", show_p = TRUE)
cleanplots_save('- Figures/dmv-09_j-CIs_y30_p.png', width = 10, height = 5.6)

# 9.k - Error term has SD of 20
ci_plot("y20", "9.k", show_p = TRUE)
cleanplots_save('- Figures/dmv-09_k-CIs_y20_p.png', width = 10, height = 5.6)

# 9.l - Error term has SD of 25
ci_plot("y25", "9.l", show_p = TRUE)
cleanplots_save('- Figures/dmv-09_l-CIs_y25_p.png', width = 10, height = 5.6)

# 9.m - Add the significance test of the difference to the graph itself
m25 <- lm(y25 ~ b, data = sim)
p25 <- avg_comparisons(m25, variables = "b")$p.value
ci_plot("y25", "9.m") +
  annotate("text", x = 1.5, y = 53, label = paste0("diff p = ", round(p25, 3)))

cleanplots_save('- Figures/dmv-09_m-CIs_y25_text.png', width = 10, height = 5.6)



######################################################
# 10 - Don't assume linearity
######################################################

##############
## Scatterplots
##############
# 10.a - Basic scatterplot doesn't work because of overlapping data points
ggplot(hrs, aes(x = age, y = dzcount)) +
  geom_point() +
  labs(x = "Age",
       y = "Number of chronic diseases",
       title = "[10.a] Relationship between number of chronic diseases and age") +
  scale_x_continuous(breaks = seq(20, 100, 10))

cleanplots_save('- Figures/dmv-10_a-scatterplot.png', width = 10, height = 5.6)

# 10.b - Jitter (random noise) points to prevent overlap
ggplot(hrs, aes(x = age, y = dzcount)) +
  geom_jitter(height = .25, width = .25) +
  labs(x = "Age",
       y = "Number of chronic diseases",
       title = "[10.b] Relationship between number of chronic diseases and age",
       subtitle = "Data points have been jittered to prevent overlap") +
  scale_x_continuous(breaks = seq(20, 100, 10))

cleanplots_save('- Figures/dmv-10_b-scatterplot-jitter.png', width = 10, height = 5.6)

# 10.c - Binned scatterplot: mean of y within 20 equal-sized bins of x
hrs_bins <- hrs %>%
  filter(!is.na(dzcount), !is.na(age)) %>%
  mutate(age_bin = ntile(age, 20)) %>%
  group_by(age_bin) %>%
  summarise(age = mean(age), dzcount = mean(dzcount))

ggplot(hrs_bins, aes(x = age, y = dzcount)) +
  geom_point(size = 3) +
  labs(x = "Age",
       y = "Number of chronic diseases",
       title = "[10.c] Binned scatterplot for number of chronic diseases by age",
       subtitle = "Each point is the mean in one of 20 equal-sized age groups") +
  scale_x_continuous(breaks = seq(20, 100, 10))

cleanplots_save('- Figures/dmv-10_c-binscatter.png', width = 10, height = 5.6)

##############
## Smoothed trend lines
##############
# 10.d - Linear regression line overlaid on scatterplot
ggplot(hrs, aes(x = age, y = dzcount)) +
  geom_jitter(height = .25, width = .25, color = "gray75") +
  geom_smooth(method = "lm") +
  labs(x = "Age",
       y = "Number of chronic diseases",
       title = "[10.d] Relationship between number of chronic diseases and age",
       subtitle = "With linear trend line") +
  scale_x_continuous(breaks = seq(20, 100, 10))

cleanplots_save('- Figures/dmv-10_d-scatterplot-linear_fit.png', width = 10, height = 5.6)

# 10.e - Quadratic regression line (x and x^2) overlaid on scatterplot
ggplot(hrs, aes(x = age, y = dzcount)) +
  geom_jitter(height = .25, width = .25, color = "gray75") +
  geom_smooth(method = "lm", formula = y ~ poly(x, 2)) +
  labs(x = "Age",
       y = "Number of chronic diseases",
       title = "[10.e] Relationship between number of chronic diseases and age",
       subtitle = "With quadratic trend line") +
  scale_x_continuous(breaks = seq(20, 100, 10))

cleanplots_save('- Figures/dmv-10_e-scatterplot-quadratic_fit.png', width = 10, height = 5.6)

# 10.f - Lowess smoothed fit line (2022 wave only)
ggplot(filter(hrs, year == 2022), aes(x = age, y = dzcount)) +
  geom_jitter(height = .25, width = .25, color = "gray75") +
  geom_smooth(method = "loess", se = FALSE, span = .4) +
  labs(x = "Age",
       y = "Number of chronic diseases",
       title = "[10.f] Relationship between number of chronic diseases and age",
       subtitle = "With lowess trend line (span = 0.4)") +
  scale_x_continuous(breaks = seq(20, 100, 10))

cleanplots_save('- Figures/dmv-10_f-scatterplot-lowess_fit.png', width = 10, height = 5.6)

######################################################
# Appendix - Model specification: continuous and ordinal IVs as nominal
######################################################
##############
## Treating a continuous variable as nominal
##############
# 10.g - Number of social roles entered as nominal (factor)
reg_roles_nom <- lm(masterySS ~ factor(role) + age + income + race + exercisSS,
                    data = cda_ah4)

plot_predictions(reg_roles_nom, condition = "role") +
  labs(x = "Number of Social Roles", y = "Mastery",
       title = "[10.g] Predicted mastery levels based on # of social roles held")

cleanplots_save('- Figures/dmv-10_g-roles_nominal.png', width = 10, height = 5.6)

# 10.h - Compare to roles and roles^2 (quadratic) specification
reg_roles_sq <- lm(masterySS ~ poly(role, 2, raw = TRUE) + age + income + race + exercisSS,
                   data = cda_ah4)

pred_roles_nom <- plot_predictions(reg_roles_nom, condition = "role", draw = FALSE)
pred_roles_nom$role <- as.numeric(as.character(pred_roles_nom$role))

plot_predictions(reg_roles_sq, condition = "role") +
  aes(color = "Roles^2 Model", fill = "Roles^2 Model") +
  geom_pointrange(data = pred_roles_nom,
                  aes(x = role, y = estimate, ymin = conf.low, ymax = conf.high,
                      color = "Categorical Model"), inherit.aes = FALSE) +
  labs(x = "Number of Social Roles", y = "Mastery", color = NULL, fill = NULL,
       title = "[10.h] Comparison of Predictions for Various Functional Forms of Roles") +
  scale_x_continuous(breaks = 0:10) +
  scale_color_manual(values = unname(cleanplots_colors("red", "ltblue"))) +
  scale_fill_manual(values = unname(cleanplots_colors("ltblue", bars = TRUE))) +
  guides(fill = "none")

cleanplots_save('- Figures/dmv-10_h-roles_overlay.png', width = 10, height = 5.6)

##############
## Ordinal predictors: continuous or nominal specification?
##############
anes_mod <- anes %>%
  filter(!is.na(vote_trump), !is.na(age), !is.na(hhincome), !is.na(woman), !is.na(lgb),
         !is.na(race4), !is.na(educ), !is.na(relimport), !is.na(wrongtrack)) %>%
  droplevels()

# 10.i - Importance of religion entered as nominal (factor)
logit_rel_nom <- glm(vote_trump ~ educ + relimport + age + hhincome + woman +
                       lgb + race4 + wrongtrack,
                     family = binomial, data = anes_mod)

plot_predictions(logit_rel_nom, condition = "relimport") +
  labs(x = "Importance of religion", y = "Pr(support Trump)",
       title = "[10.i] Pr(support Trump) by importance of religion -- Nominal specification") +
  scale_x_discrete(labels = c("E. Important", "V. Important", "Mod. Important",
                              "Little Important", "Not Important"))

cleanplots_save('- Figures/dmv-10_i-relimport_nominal.png', width = 10, height = 5.6)

# 10.j - Compare to importance of religion entered as continuous (numeric)
anes_mod$relimportC <- as.numeric(anes_mod$relimport)

logit_rel_con <- glm(vote_trump ~ educ + relimportC + age + hhincome + woman +
                       lgb + race4 + wrongtrack,
                     family = binomial, data = anes_mod)

pred_rel_nom <- plot_predictions(logit_rel_nom, condition = "relimport", draw = FALSE)

plot_predictions(logit_rel_con, condition = "relimportC") +
  geom_pointrange(data = pred_rel_nom,
                  aes(x = as.numeric(relimport), y = estimate,
                      ymin = conf.low, ymax = conf.high),
                  color = cleanplots_colors("red"), inherit.aes = FALSE) +
  scale_x_continuous(breaks = 1:5, expand = expansion(mult = .08),
                     labels = c("E. Important", "V. Important", "Mod. Important",
                                "Little Important", "Not Important")) +
  labs(x = "Importance of religion", y = "Pr(support Trump)",
       title = "[10.j] Pr(support Trump) by importance of religion - comparing IV specifications",
       subtitle = "Continuous specification (line) vs nominal specification (red dots)")

cleanplots_save('- Figures/dmv-10_j-relimport_overlay.png', width = 10, height = 5.6)



# end of file
