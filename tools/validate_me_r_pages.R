# Check the R example pages for ME inequality and Total ME against the
# published (Stata) results in Mize and Han (2025). Run in R:
#   source("tools/validate_me_r_pages.R")

library(haven)           # Read Stata data
library(marginaleffects) # Marginal effects and hypotheses
library(nnet)            # Multinomial logit
library(MASS)            # Negative binomial regression
library(suest)           # Combine models

source("https://raw.githubusercontent.com/tdmize/Rfunctions/main/ME_helper_functions.R")

near <- function(x, target, tol) abs(x - target) < tol
gss0 <- read_dta("https://tdmize.github.io/data/data/cda_gss.dta")

# Example 4.1 --------------------------------------------------------------
vars <- c("wages", "race4", "age", "woman")
gss <- gss0[gss0$year == 2021, ]
gss <- gss[complete.cases(gss[vars]), vars]
gss[c("race4", "woman")] <- lapply(gss[c("race4", "woman")], as_factor)
wagemod <- lm(wages ~ race4 + age + woman, data = gss)
weights <- meineq_weights(wagemod, race4)
wmean <- function(x) weighted.mean(x, weights)
w <- avg_comparisons(wagemod, variables = list(race4 = "pairwise"), hypothesis = ~ I(wmean(abs(x))))
u <- avg_comparisons(wagemod, variables = list(race4 = "pairwise"), hypothesis = ~ I(mean(abs(x))))
stopifnot(near(w$estimate, 4.904, .01), near(w$std.error, .860, .01),
          near(u$estimate, 5.788, .01), near(u$std.error, 1.042, .01))

# Example 4.2.b ------------------------------------------------------------
vars <- c("conserv", "race4", "woman", "class", "age")
gss <- gss0[gss0$year == 2021, ]
gss <- gss[complete.cases(gss[vars]), vars]
fvars <- c("conserv", "race4", "woman", "class")
gss[fvars] <- lapply(gss[fvars], as_factor)
gss <- droplevels(gss)
conmod <- glm(conserv ~ woman + race4 + class, family = binomial("logit"), data = gss)
w_woman <- meineq_weights(conmod, woman)
w_race <- meineq_weights(conmod, race4)
w_class <- meineq_weights(conmod, class)
a <- avg_comparisons(conmod, variables = list(woman = "pairwise"), hypothesis = ~ I(weighted.mean(abs(x), w_woman)))
b <- avg_comparisons(conmod, variables = list(race4 = "pairwise"), hypothesis = ~ I(weighted.mean(abs(x), w_race)))
d <- avg_comparisons(conmod, variables = list(class = "pairwise"), hypothesis = ~ I(weighted.mean(abs(x), w_class)))
stopifnot(near(a$estimate, .070, .002), near(a$std.error, .016, .002),
          near(b$estimate, .108, .002), near(b$std.error, .013, .002),
          near(d$estimate, .012, .002), near(d$std.error, .017, .002))

# Example 4.3.b ------------------------------------------------------------
hrs <- read_dta("https://tdmize.github.io/data/data/cda_hrs.dta")
vars <- c("iadl", "race4cat", "collegeB", "wealth_w", "income_w")
hrs <- hrs[complete.cases(hrs[vars]), vars]
hrs[c("race4cat", "collegeB")] <- lapply(hrs[c("race4cat", "collegeB")], as_factor)
basemod <- glm.nb(iadl ~ race4cat, data = hrs)
medmod <- glm.nb(iadl ~ race4cat + collegeB + wealth_w + income_w, data = hrs)
fit <- suest(basemod, medmod, model_names = c("Base", "Mediators"))
weights <- meineq_weights(basemod, race4cat)
meineq <- function(x) {
  est <- sapply(split(x$estimate, x$group), function(e) weighted.mean(abs(e), weights))
  data.frame(term = names(est), estimate = est)
}
ineq <- avg_comparisons(fit, variables = list(race4cat = "pairwise"), newdata = hrs, hypothesis = meineq)
dif <- hypotheses(ineq, hypothesis = difference ~ revpairwise)
stopifnot(near(ineq$estimate, c(.046, .038), .002), near(ineq$std.error, c(.012, .011), .002),
          near(dif$estimate, .009, .002), near(dif$std.error, .022, .002))

# Example 4.3.a ------------------------------------------------------------
vars <- c("spkhomo", "reltrad", "age", "woman", "year")
gss <- gss0[complete.cases(gss0[vars]), vars]
gss[c("spkhomo", "reltrad", "woman")] <- lapply(gss[c("spkhomo", "reltrad", "woman")], as_factor)
premod <- glm(spkhomo ~ reltrad + age + woman, family = binomial("logit"), data = gss, subset = year < 1980)
postmod <- glm(spkhomo ~ reltrad + age + woman, family = binomial("logit"), data = gss, subset = year >= 2010)
fit <- suest(premod, postmod, model_names = c("Before 1980", "2010 and later"))
meineq <- function(x) {
  groups <- unique(x$group)
  est <- sapply(groups, function(g) mean(abs(x$estimate[x$group == g])))
  data.frame(term = groups, estimate = est)
}
ineq <- avg_comparisons(fit, variables = list(reltrad = "pairwise"),
                        newdata = suest_newdata(fit), hypothesis = meineq)
dif <- hypotheses(ineq, hypothesis = difference ~ revpairwise)
stopifnot(near(ineq$estimate, c(.156, .072), .002), near(ineq$std.error, c(.011, .007), .002),
          near(dif$estimate, .083, .002), near(dif$std.error, .013, .002))

# Examples 5.2.c and 5.3 -----------------------------------------------------
vars <- c("healthR", "race4", "age", "woman", "parent", "married", "faminc", "degree")
gss <- gss0[gss0$year >= 2000 & gss0$year <= 2021, ]
gss <- gss[complete.cases(gss[vars]), vars]
fvars <- c("healthR", "race4", "woman", "parent", "married", "degree")
gss[fvars] <- lapply(gss[fvars], as_factor)
healthmod <- multinom(healthR ~ race4 + age + woman + parent + married + faminc + degree,
                      data = gss, trace = FALSE)
tme <- avg_comparisons(healthmod,
  variables = list(age = "sd", married = "reference", parent = "reference"),
  hypothesis = ~ I(sum(abs(x)) / 2) | term)
est <- setNames(tme$estimate, tme$term); se <- setNames(tme$std.error, tme$term)
stopifnot(near(est[["age"]], .051, .003), near(se[["age"]], .003, .002),
          near(est[["married"]], .031, .003), near(se[["married"]], .007, .002),
          near(est[["parent"]], .027, .003), near(se[["parent"]], .009, .002))
race <- avg_comparisons(healthmod, variables = list(race4 = "pairwise"),
  hypothesis = ~ I(sum(abs(x)) / 2) | contrast) |>
  hypotheses(hypothesis = meineq_weights(healthmod, race4))
degree <- avg_comparisons(healthmod, variables = list(degree = "pairwise"),
  hypothesis = ~ I(sum(abs(x)) / 2) | contrast) |>
  hypotheses(hypothesis = meineq_weights(healthmod, degree))
stopifnot(near(race$estimate, .047, .002), near(race$std.error, .007, .002),
          near(degree$estimate, .116, .002), near(degree$std.error, .006, .002))

# Example 5.2.e ------------------------------------------------------------
vars <- c("healthR", "college", "race4", "age", "woman", "parent", "married", "faminc")
gss <- gss0[gss0$year >= 2000 & gss0$year <= 2021, ]
gss <- gss[complete.cases(gss[vars]), vars]
fvars <- c("healthR", "college", "race4", "woman", "parent", "married")
gss[fvars] <- lapply(gss[fvars], as_factor)
basemod <- multinom(healthR ~ college + race4 + age + woman + parent + married, data = gss, trace = FALSE)
medmod <- multinom(healthR ~ college + race4 + age + woman + parent + married + faminc, data = gss, trace = FALSE)
fit <- suest(basemod, medmod, model_names = c("Base", "Income"))
totalme <- function(x) {
  model <- sub("::.*", "", x$group)
  est <- tapply(abs(x$estimate), model, sum)[unique(model)] / 2
  data.frame(term = names(est), estimate = as.numeric(est))
}
tme <- avg_comparisons(fit, variables = list(college = "reference"), newdata = gss, hypothesis = totalme)
dif <- hypotheses(tme, hypothesis = difference ~ revpairwise)
stopifnot(near(tme$estimate, c(.159, .118), .002), near(tme$std.error, c(.006, .007), .002),
          near(dif$estimate, .041, .002), near(dif$std.error, .003, .002))

cat("PASS: all seven R examples match the published (Stata) results.\n")
