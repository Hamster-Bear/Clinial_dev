library(testthat)
library(shiny)
library(survival)
library(broom)

source("modules/statistical_analysis/cox.R")
source("modules/statistical_analysis/logistic.R")
source("modules/statistical_analysis/linear.R")

set.seed(20260324)
n <- 1200
sex <- factor(sample(c("M", "F"), n, replace = TRUE), levels = c("M", "F"))
arm <- factor(sample(c("A", "B"), n, replace = TRUE), levels = c("A", "B"))
x <- rnorm(n)
lp_logit <- -0.2 + 0.7 * x + 0.3 * as.integer(sex == "F") - 0.25 * as.integer(arm == "B") + 0.4 * x * as.integer(sex == "F")
y <- rbinom(n, 1, plogis(lp_logit))
lp_lin <- 1.5 + 0.9 * x + 0.5 * as.integer(sex == "F") - 0.3 * as.integer(arm == "B") + 0.2 * x * as.integer(sex == "F")
z <- lp_lin + rnorm(n, sd = 1.0)
haz <- exp(-2.8 + 0.6 * x + 0.2 * as.integer(sex == "F") + 0.2 * x * as.integer(sex == "F"))
t_event <- rexp(n, rate = haz)
t_cens <- rexp(n, rate = 0.08)
time <- pmin(t_event, t_cens)
status <- as.integer(t_event <= t_cens)

dat <- data.frame(
  time = time,
  status = status,
  y = y,
  z = z,
  x = x,
  sex = sex,
  arm = arm
)

dat_alpha <- dat
dat_alpha$sex <- factor(as.character(dat$sex))

fmt_num <- function(x, digits = 4) {
  sub("\\.?0+$", "", sprintf(paste0("%.", digits, "f"), as.numeric(x)))
}

fmt_ci <- function(est, low, high) {
  est <- as.numeric(est)
  low <- as.numeric(low)
  high <- as.numeric(high)
  if (is.na(est)) return("NA")
  if (any(is.na(c(low, high)))) return(fmt_num(est, 4))
  paste0(fmt_num(est, 4), " (", fmt_num(low, 4), ", ", fmt_num(high, 4), ")")
}

get_gt_data <- function(res) {
  expect_true(is.list(res))
  expect_true(!is.null(res$table))
  expect_true(inherits(res$table, "gt_tbl"))
  res$table[["_data"]]
}

clean_subgroup <- function(x) {
  trimws(gsub("\u00A0", "", as.character(x), fixed = TRUE))
}

find_interaction_p <- function(tidy_df, pred = "x", split_var = "sex", level = "F") {
  idx <- which(
    grepl(":", tidy_df$term, fixed = TRUE) &
      grepl(pred, tidy_df$term, fixed = TRUE) &
      grepl(split_var, tidy_df$term, fixed = TRUE) &
      grepl(level, tidy_df$term, fixed = TRUE)
  )
  if (length(idx) == 0) return("NA")
  format_p_value_regression(tidy_df$p.value[idx[1]])
}

check_common_custom_row <- function(df, subgroup_level, facet = NULL) {
  base_idx <- df$预测变量 == "x" & clean_subgroup(df$亚组) == subgroup_level
  if ("统计值" %in% names(df)) {
    keep_idx <- as.character(df$统计值) != "Reference"
  } else {
    stat_cols <- grep("__统计值$", names(df), value = TRUE)
    keep_idx <- rep(FALSE, nrow(df))
    if (length(stat_cols) > 0) {
      keep_idx <- apply(df[, stat_cols, drop = FALSE], 1, function(v) any(as.character(v) != "Reference"))
    }
  }
  row <- df[base_idx & keep_idx, , drop = FALSE]
  expect_equal(nrow(row), 1)
  row[1, , drop = FALSE]
}

test_that("Logistic 全场景公式验算通过", {
  fit_all <- glm(y ~ x, data = dat, family = binomial())
  td_all <- broom::tidy(fit_all, conf.int = TRUE, exponentiate = TRUE)
  td_x <- td_all[td_all$term == "x", , drop = FALSE]

  r_none <- perform_logistic_analysis(dat, "y", c("x"), "None", "None", "1", NULL)
  d_none <- get_gt_data(r_none)
  row_none <- d_none[d_none$term == "x", , drop = FALSE]
  expect_equal(as.numeric(row_none$estimate), as.numeric(td_x$estimate), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$conf.low), as.numeric(td_x$conf.low), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$conf.high), as.numeric(td_x$conf.high), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$p.value), as.numeric(td_x$p.value), tolerance = 1e-10)

  r_facet <- perform_logistic_analysis(dat, "y", c("x"), "None", "arm", "1", NULL)
  d_facet <- get_gt_data(r_facet)
  row_facet <- d_facet[d_facet$variable == "x" & d_facet$row_type == "label", , drop = FALSE]
  facet_vals <- unique(dat$arm)
  facet_vals <- facet_vals[!is.na(facet_vals)]
  for (i in seq_along(facet_vals)) {
    sub <- dat[dat$arm == facet_vals[i], , drop = FALSE]
    td <- broom::tidy(glm(y ~ x, data = sub, family = binomial()), conf.int = TRUE, exponentiate = TRUE)
    td <- td[td$term == "x", , drop = FALSE]
    expect_equal(as.numeric(row_facet[[paste0("estimate_", i)]]), as.numeric(td$estimate), tolerance = 1e-10)
    expect_equal(as.numeric(row_facet[[paste0("conf.low_", i)]]), as.numeric(td$conf.low), tolerance = 1e-10)
    expect_equal(as.numeric(row_facet[[paste0("conf.high_", i)]]), as.numeric(td$conf.high), tolerance = 1e-10)
    expect_equal(as.numeric(row_facet[[paste0("p.value_", i)]]), as.numeric(td$p.value), tolerance = 1e-10)
  }

  r_split <- perform_logistic_analysis(dat, "y", c("x"), "sex", "None", "1", NULL)
  d_split <- get_gt_data(r_split)
  fit_int_split <- broom::tidy(glm(y ~ x + sex + x:sex, data = dat, family = binomial()))
  for (lv in c("M", "F")) {
    sub <- dat[dat$sex == lv, , drop = FALSE]
    fit <- glm(y ~ x, data = sub, family = binomial())
    td <- broom::tidy(fit)
    td_x <- td[td$term == "x", , drop = FALSE]
    beta <- as.numeric(td_x$estimate)
    se <- as.numeric(td_x$std.error)
    est <- exp(beta)
    low <- exp(beta - 1.96 * se)
    high <- exp(beta + 1.96 * se)
    row <- check_common_custom_row(d_split, lv)
    expect_equal(as.character(row$统计值), fmt_ci(est, low, high))
    expect_equal(as.character(row$P值), format_p_value_regression(td_x$p.value))
    n_expected <- sum(complete.cases(sub[, c("y", "x"), drop = FALSE]))
    expect_equal(as.integer(row$N), as.integer(n_expected))
    if (lv == "M") {
      expect_equal(as.character(row$亚组差异P值), "")
    } else {
      expect_equal(as.character(row$亚组差异P值), find_interaction_p(fit_int_split, "x", "sex", "F"))
    }
  }

  r_both <- perform_logistic_analysis(dat, "y", c("x"), "sex", "arm", "1", NULL)
  d_both <- get_gt_data(r_both)
  for (lv in c("M", "F")) {
    for (fv in c("A", "B")) {
      sub <- dat[dat$sex == lv & dat$arm == fv, , drop = FALSE]
      fit <- glm(y ~ x, data = sub, family = binomial())
      td <- broom::tidy(fit)
      td_x <- td[td$term == "x", , drop = FALSE]
      beta <- as.numeric(td_x$estimate)
      se <- as.numeric(td_x$std.error)
      est <- exp(beta)
      low <- exp(beta - 1.96 * se)
      high <- exp(beta + 1.96 * se)
      row <- check_common_custom_row(d_both, lv)
      expect_equal(as.character(row[[paste0(fv, "__统计值")]]), fmt_ci(est, low, high))
      expect_equal(as.character(row[[paste0(fv, "__P值")]]), format_p_value_regression(td_x$p.value))
      n_expected <- sum(complete.cases(sub[, c("y", "x"), drop = FALSE]))
      expect_equal(as.integer(row[[paste0(fv, "__N")]]), as.integer(n_expected))
      if (lv == "M") {
        expect_equal(as.character(row[[paste0(fv, "__亚组差异P值")]]), "")
      } else {
        fit_int <- broom::tidy(glm(y ~ x + sex + x:sex, data = dat[dat$arm == fv, , drop = FALSE], family = binomial()))
        expect_equal(as.character(row[[paste0(fv, "__亚组差异P值")]]), find_interaction_p(fit_int, "x", "sex", "F"))
      }
    }
  }
})

test_that("Logistic 亚组差异P值在默认字母水平下不应全部为NA", {
  r_split <- perform_logistic_analysis(dat_alpha, "y", c("x"), "sex", "None", "1", NULL)
  d_split <- get_gt_data(r_split)
  row_f <- d_split[d_split$预测变量 == "x" & clean_subgroup(d_split$亚组) == "F", , drop = FALSE]
  expect_equal(nrow(row_f), 1)
  expect_true(as.character(row_f$亚组差异P值) != "NA")

  r_both <- perform_logistic_analysis(dat_alpha, "y", c("x"), "sex", "arm", "1", NULL)
  d_both <- get_gt_data(r_both)
  row_f2 <- d_both[d_both$预测变量 == "x" & clean_subgroup(d_both$亚组) == "F", , drop = FALSE]
  expect_equal(nrow(row_f2), 1)
  expect_true(all(as.character(row_f2[, c("A__亚组差异P值", "B__亚组差异P值")]) != "NA"))
})

test_that("分类变量展示应明确比较与参考组", {
  set.seed(2026)
  n2 <- 400
  d2 <- data.frame(
    time = rexp(n2, 0.1),
    status = rbinom(n2, 1, 0.6),
    y = rbinom(n2, 1, 0.5),
    z = rnorm(n2),
    sex = factor(sample(c("M", "F"), n2, TRUE), levels = c("M", "F")),
    trt = factor(sample(c("PBO", "DRUG"), n2, TRUE), levels = c("DRUG", "PBO"))
  )
  rl <- perform_logistic_analysis(d2, "y", c("trt"), "sex", "None", "1", NULL)
  rc <- perform_cox_analysis(d2, "time", "status", c("trt"), "sex", "None", "1", NULL)
  rn <- perform_linear_analysis(d2, "z", c("trt"), "sex", "None", NULL)
  dl <- get_gt_data(rl)
  dc <- get_gt_data(rc)
  dn <- get_gt_data(rn)
  expect_true(any(grepl("PBO vs DRUG", dl$预测变量, fixed = TRUE)))
  expect_true(any(grepl("PBO vs DRUG", dc$预测变量, fixed = TRUE)))
  expect_true(any(grepl("PBO vs DRUG", dn$预测变量, fixed = TRUE)))
  expect_true(any(grepl("分类变量参考组：trt=DRUG", rl$model_notes, fixed = TRUE)))
  expect_true(any(grepl("分类变量参考组：trt=DRUG", rc$model_notes, fixed = TRUE)))
  expect_true(any(grepl("分类变量参考组：trt=DRUG", rn$model_notes, fixed = TRUE)))
})

test_that("分类变量应包含Reference占位行与可配置参考组", {
  set.seed(3030)
  n3 <- 350
  d3 <- data.frame(
    y = rbinom(n3, 1, 0.5),
    z = rnorm(n3),
    time = rexp(n3, 0.12),
    status = rbinom(n3, 1, 0.6),
    sex = factor(sample(c("M", "F"), n3, TRUE), levels = c("M", "F")),
    trt = factor(sample(c("PBO", "DRUG"), n3, TRUE), levels = c("DRUG", "PBO"))
  )
  ref_map <- c(trt = "PBO")
  rl <- perform_logistic_analysis(d3, "y", c("trt"), "sex", "None", "1", NULL, ref_map)
  rc <- perform_cox_analysis(d3, "time", "status", c("trt"), "sex", "None", "1", NULL, ref_map)
  rn <- perform_linear_analysis(d3, "z", c("trt"), "sex", "None", NULL, ref_map)
  dl <- get_gt_data(rl)
  dc <- get_gt_data(rc)
  dn <- get_gt_data(rn)
  expect_true(any(dl$统计值 == "Reference"))
  expect_true(any(dc$统计值 == "Reference"))
  expect_true(any(dn$统计值 == "Reference"))
  expect_true(any(grepl("trt=PBO", rl$model_notes, fixed = TRUE)))
  expect_true(any(grepl("trt=PBO", rc$model_notes, fixed = TRUE)))
  expect_true(any(grepl("trt=PBO", rn$model_notes, fixed = TRUE)))
})

test_that("Linear 全场景公式验算通过", {
  fit_all <- lm(z ~ x, data = dat)
  td_all <- broom::tidy(fit_all, conf.int = TRUE)
  td_x <- td_all[td_all$term == "x", , drop = FALSE]

  r_none <- perform_linear_analysis(dat, "z", c("x"), "None", "None", NULL)
  d_none <- get_gt_data(r_none)
  row_none <- d_none[d_none$term == "x", , drop = FALSE]
  expect_equal(as.numeric(row_none$estimate), as.numeric(td_x$estimate), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$conf.low), as.numeric(td_x$conf.low), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$conf.high), as.numeric(td_x$conf.high), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$p.value), as.numeric(td_x$p.value), tolerance = 1e-10)

  r_facet <- perform_linear_analysis(dat, "z", c("x"), "None", "arm", NULL)
  d_facet <- get_gt_data(r_facet)
  row_facet <- d_facet[d_facet$variable == "x" & d_facet$row_type == "label", , drop = FALSE]
  facet_vals <- unique(dat$arm)
  facet_vals <- facet_vals[!is.na(facet_vals)]
  for (i in seq_along(facet_vals)) {
    sub <- dat[dat$arm == facet_vals[i], , drop = FALSE]
    td <- broom::tidy(lm(z ~ x, data = sub), conf.int = TRUE)
    td <- td[td$term == "x", , drop = FALSE]
    expect_equal(as.numeric(row_facet[[paste0("estimate_", i)]]), as.numeric(td$estimate), tolerance = 1e-10)
    expect_equal(as.numeric(row_facet[[paste0("conf.low_", i)]]), as.numeric(td$conf.low), tolerance = 1e-10)
    expect_equal(as.numeric(row_facet[[paste0("conf.high_", i)]]), as.numeric(td$conf.high), tolerance = 1e-10)
    expect_equal(as.numeric(row_facet[[paste0("p.value_", i)]]), as.numeric(td$p.value), tolerance = 1e-10)
  }

  r_split <- perform_linear_analysis(dat, "z", c("x"), "sex", "None", NULL)
  d_split <- get_gt_data(r_split)
  fit_int_split <- broom::tidy(lm(z ~ x + sex + x:sex, data = dat))
  for (lv in c("M", "F")) {
    sub <- dat[dat$sex == lv, , drop = FALSE]
    td_x <- broom::tidy(lm(z ~ x, data = sub), conf.int = TRUE)
    td_x <- td_x[td_x$term == "x", , drop = FALSE]
    row <- check_common_custom_row(d_split, lv)
    expect_equal(as.character(row$统计值), fmt_ci(td_x$estimate, td_x$conf.low, td_x$conf.high))
    expect_equal(as.character(row$P值), format_p_value_regression(td_x$p.value))
    n_expected <- sum(complete.cases(sub[, c("z", "x"), drop = FALSE]))
    expect_equal(as.integer(row$N), as.integer(n_expected))
    if (lv == "M") {
      expect_equal(as.character(row$亚组差异P值), "")
    } else {
      expect_equal(as.character(row$亚组差异P值), find_interaction_p(fit_int_split, "x", "sex", "F"))
    }
  }

  r_both <- perform_linear_analysis(dat, "z", c("x"), "sex", "arm", NULL)
  d_both <- get_gt_data(r_both)
  for (lv in c("M", "F")) {
    for (fv in c("A", "B")) {
      sub <- dat[dat$sex == lv & dat$arm == fv, , drop = FALSE]
      td_x <- broom::tidy(lm(z ~ x, data = sub), conf.int = TRUE)
      td_x <- td_x[td_x$term == "x", , drop = FALSE]
      row <- check_common_custom_row(d_both, lv)
      expect_equal(as.character(row[[paste0(fv, "__统计值")]]), fmt_ci(td_x$estimate, td_x$conf.low, td_x$conf.high))
      expect_equal(as.character(row[[paste0(fv, "__P值")]]), format_p_value_regression(td_x$p.value))
      n_expected <- sum(complete.cases(sub[, c("z", "x"), drop = FALSE]))
      expect_equal(as.integer(row[[paste0(fv, "__N")]]), as.integer(n_expected))
      if (lv == "M") {
        expect_equal(as.character(row[[paste0(fv, "__亚组差异P值")]]), "")
      } else {
        fit_int <- broom::tidy(lm(z ~ x + sex + x:sex, data = dat[dat$arm == fv, , drop = FALSE]))
        expect_equal(as.character(row[[paste0(fv, "__亚组差异P值")]]), find_interaction_p(fit_int, "x", "sex", "F"))
      }
    }
  }
})

test_that("Cox 全场景公式验算通过", {
  fit_all <- survival::coxph(survival::Surv(time, status) ~ x, data = dat)
  td_all <- broom::tidy(fit_all, conf.int = TRUE, exponentiate = TRUE)
  td_x <- td_all[td_all$term == "x", , drop = FALSE]

  r_none <- perform_cox_analysis(dat, "time", "status", c("x"), "None", "None", "1", NULL)
  d_none <- get_gt_data(r_none)
  row_none <- d_none[d_none$term == "x", , drop = FALSE]
  expect_equal(as.numeric(row_none$estimate), as.numeric(td_x$estimate), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$conf.low), as.numeric(td_x$conf.low), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$conf.high), as.numeric(td_x$conf.high), tolerance = 1e-10)
  expect_equal(as.numeric(row_none$p.value), as.numeric(td_x$p.value), tolerance = 1e-10)

  r_facet <- perform_cox_analysis(dat, "time", "status", c("x"), "None", "arm", "1", NULL)
  d_facet <- get_gt_data(r_facet)
  row_facet <- d_facet[d_facet$预测变量 == "x" & clean_subgroup(d_facet$亚组) == "总体", , drop = FALSE]
  expect_equal(nrow(row_facet), 1)
  for (fv in c("A", "B")) {
    sub <- dat[dat$arm == fv, , drop = FALSE]
    td <- broom::tidy(survival::coxph(survival::Surv(time, status) ~ x, data = sub), conf.int = TRUE, exponentiate = TRUE)
    td <- td[td$term == "x", , drop = FALSE]
    expect_equal(as.character(row_facet[[paste0(fv, "__统计值")]]), fmt_ci(td$estimate, td$conf.low, td$conf.high))
    expect_equal(as.character(row_facet[[paste0(fv, "__P值")]]), format_p_value_regression(td$p.value))
    n_expected <- sum(complete.cases(sub[, c("time", "status", "x"), drop = FALSE]))
    expect_equal(as.integer(row_facet[[paste0(fv, "__N")]]), as.integer(n_expected))
  }

  r_split <- perform_cox_analysis(dat, "time", "status", c("x"), "sex", "None", "1", NULL)
  d_split <- get_gt_data(r_split)
  fit_int_split <- broom::tidy(survival::coxph(survival::Surv(time, status) ~ x + sex + x:sex, data = dat))
  for (lv in c("M", "F")) {
    sub <- dat[dat$sex == lv, , drop = FALSE]
    td_x <- broom::tidy(survival::coxph(survival::Surv(time, status) ~ x, data = sub), conf.int = TRUE, exponentiate = TRUE)
    td_x <- td_x[td_x$term == "x", , drop = FALSE]
    row <- check_common_custom_row(d_split, lv)
    expect_equal(as.character(row$统计值), fmt_ci(td_x$estimate, td_x$conf.low, td_x$conf.high))
    expect_equal(as.character(row$P值), format_p_value_regression(td_x$p.value))
    n_expected <- sum(complete.cases(sub[, c("time", "status", "x"), drop = FALSE]))
    expect_equal(as.integer(row$N), as.integer(n_expected))
    if (lv == "M") {
      expect_equal(as.character(row$亚组差异P值), "")
    } else {
      expect_equal(as.character(row$亚组差异P值), find_interaction_p(fit_int_split, "x", "sex", "F"))
    }
  }

  r_both <- perform_cox_analysis(dat, "time", "status", c("x"), "sex", "arm", "1", NULL)
  d_both <- get_gt_data(r_both)
  for (lv in c("M", "F")) {
    for (fv in c("A", "B")) {
      sub <- dat[dat$sex == lv & dat$arm == fv, , drop = FALSE]
      td_x <- broom::tidy(survival::coxph(survival::Surv(time, status) ~ x, data = sub), conf.int = TRUE, exponentiate = TRUE)
      td_x <- td_x[td_x$term == "x", , drop = FALSE]
      row <- check_common_custom_row(d_both, lv)
      expect_equal(as.character(row[[paste0(fv, "__统计值")]]), fmt_ci(td_x$estimate, td_x$conf.low, td_x$conf.high))
      expect_equal(as.character(row[[paste0(fv, "__P值")]]), format_p_value_regression(td_x$p.value))
      n_expected <- sum(complete.cases(sub[, c("time", "status", "x"), drop = FALSE]))
      expect_equal(as.integer(row[[paste0(fv, "__N")]]), as.integer(n_expected))
      if (lv == "M") {
        expect_equal(as.character(row[[paste0(fv, "__亚组差异P值")]]), "")
      } else {
        fit_int <- broom::tidy(survival::coxph(survival::Surv(time, status) ~ x + sex + x:sex, data = dat[dat$arm == fv, , drop = FALSE]))
        expect_equal(as.character(row[[paste0(fv, "__亚组差异P值")]]), find_interaction_p(fit_int, "x", "sex", "F"))
      }
    }
  }
})

cat("Regression formula validation tests passed\n")
