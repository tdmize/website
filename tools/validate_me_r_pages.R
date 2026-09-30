# Check the R example pages for ME inequality and Total ME against the
# published (Stata) results in Mize and Han (2025). Run in R:
#   source("tools/validate_me_r_pages.R")

library(haven)           # Read Stata data
library(marginaleffects) # Marginal effects and hypotheses
library(nnet)            # Multinomial logit

source("https://raw.githubusercontent.com/tdmize/Rfunctions/main/ME_helper_functions.R")

gss0 <- read_dta("https://tdmize.github.io/data/data/cda_gss.dta")

# Example 4.1: ME inequality (software/meinequality_r/examples/summary-measure)
vars <- c("wages", "race4", "age", "woman")
gss <- gss0[gss0$year == 2021, ]
gss <- gss[complete.cases(gss[vars]), vars]
gss[c("race4", "woman")] <- lapply(gss[c("race4", "woman")], as_factor)

wagemod <- lm(wages ~ race4 + age + woman, data = gss)
weights <- meineq_weights(wagemod, race4)
wmean <- function(x) weighted.mean(x, weights)

weighted <- avg_comparisons(wagemod,
  variables = list(race4 = "pairwise"),
  hypothesis = ~ I(wmean(abs(x))))
unweighted <- avg_comparisons(wagemod,
  variables = list(race4 = "pairwise"),
  hypothesis = ~ I(mean(abs(x))))

stopifnot(
  nobs(wagemod) == 1714,
  abs(weighted$estimate - 4.904) < .01,   abs(weighted$std.error - .860) < .01,
  abs(unweighted$estimate - 5.788) < .01, abs(unweighted$std.error - 1.042) < .01
)

# Example 5.2.c: Total ME (software/totalme_r/examples/single-model)
vars <- c("healthR", "race4", "age", "woman", "parent", "married", "faminc", "degree")
gss <- gss0[gss0$year >= 2000 & gss0$year <= 2021, ]
gss <- gss[complete.cases(gss[vars]), vars]
fvars <- c("healthR", "race4", "woman", "parent", "married", "degree")
gss[fvars] <- lapply(gss[fvars], as_factor)

healthmod <- multinom(healthR ~ race4 + age + woman + parent +
  married + faminc + degree, data = gss, trace = FALSE)

tme <- avg_comparisons(healthmod,
  variables = list(age = "sd", married = "reference", parent = "reference"),
  hypothesis = ~ I(sum(abs(x)) / 2) | term)
est <- setNames(tme$estimate, tme$term)
se <- setNames(tme$std.error, tme$term)

stopifnot(
  nrow(gss) == 19292,
  abs(est["age"] - .051) < .003,     abs(se["age"] - .003) < .002,
  abs(est["married"] - .031) < .003, abs(se["married"] - .007) < .002,
  abs(est["parent"] - .027) < .003,  abs(se["parent"] - .009) < .002
)

# Example 5.3: weighted Total ME inequality (software/totalme_r overview)
race <- avg_comparisons(healthmod,
  variables = list(race4 = "pairwise"),
  hypothesis = ~ I(sum(abs(x)) / 2) | contrast) |>
  hypotheses(hypothesis = meineq_weights(healthmod, race4))
degree <- avg_comparisons(healthmod,
  variables = list(degree = "pairwise"),
  hypothesis = ~ I(sum(abs(x)) / 2) | contrast) |>
  hypotheses(hypothesis = meineq_weights(healthmod, degree))

stopifnot(
  abs(race$estimate - .047) < .002,   abs(race$std.error - .007) < .002,
  abs(degree$estimate - .116) < .002, abs(degree$std.error - .006) < .002
)

cat("PASS: the R pages match the published (Stata) results.\n")
