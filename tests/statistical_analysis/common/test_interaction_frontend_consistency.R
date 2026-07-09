test_find_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- sub(file_arg, "", args[grep(file_arg, args)])
  script_path <- if (length(script_path) > 0) script_path[[1]] else ""
  start_candidates <- unique(c(
    if (nzchar(script_path)) dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)) else character(0),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  ))

  for (candidate in start_candidates) {
    current <- candidate
    repeat {
      if (file.exists(file.path(current, "app.R")) &&
          dir.exists(file.path(current, "modules")) &&
          dir.exists(file.path(current, "tests"))) {
        return(normalizePath(current, winslash = "/", mustWork = TRUE))
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }

  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))
library(testthat)

module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}

source(module_path("modules/statistical_analysis/logistic.R"))
source(module_path("modules/statistical_analysis/linear.R"))
source(module_path("modules/statistical_analysis/cox.R"))
source(module_path("modules/common/export/table_export.R"))

align_compare_df <- function(df) {
  x <- as.data.frame(df, stringsAsFactors = FALSE)
  if ("N" %in% names(x)) names(x)[names(x) == "N"] <- "event/N"
  if ("n" %in% names(x)) names(x)[names(x) == "n"] <- "event/N"
  if ("统计值" %in% names(x)) names(x)[names(x) == "统计值"] <- "效应值"
  if ("OR (95% CI)" %in% names(x)) names(x)[names(x) == "OR (95% CI)"] <- "效应值"
  if ("Beta (95% CI)" %in% names(x)) names(x)[names(x) == "Beta (95% CI)"] <- "效应值"
  if ("HR (95% CI)" %in% names(x)) names(x)[names(x) == "HR (95% CI)"] <- "效应值"
  if ("P for interaction" %in% names(x)) names(x)[names(x) == "P for interaction"] <- "亚组差异P值"
  x
}

compare_front_spec <- function(tbl) {
  front <- align_compare_df(as.data.frame(tbl[["_data"]], stringsAsFactors = FALSE))
  spec <- align_compare_df(as.data.frame(extract_table_dataframe(tbl), stringsAsFactors = FALSE))
  keys <- intersect(names(front), names(spec))
  front <- front[, keys, drop = FALSE]
  spec <- spec[, keys, drop = FALSE]
  list(front = front, spec = spec)
}

test_that("logistic 交互效应前后端列一致", {
  dat <- data.frame(
    event = sample(c(0, 1), 200, TRUE),
    sex = factor(sample(c("M", "F"), 200, TRUE)),
    treat = factor(sample(c("A", "B"), 200, TRUE)),
    stringsAsFactors = FALSE
  )
  res <- perform_logistic_analysis(
    data = dat,
    logistic_response = "event",
    logistic_predictors = c("treat"),
    logistic_strata = "sex",
    logistic_event_value = "1"
  )
  cmp <- compare_front_spec(res$table)
  expect_identical(cmp$front, cmp$spec)
  expect_true(any(grepl("P for interaction|亚组差异P值", names(cmp$front))))
})

test_that("linear 交互效应前后端列一致", {
  dat <- data.frame(
    y = rnorm(200),
    sex = factor(sample(c("M", "F"), 200, TRUE)),
    x = rnorm(200),
    stringsAsFactors = FALSE
  )
  res <- perform_linear_analysis(
    data = dat,
    linear_response = "y",
    linear_predictors = c("x"),
    linear_strata = "sex"
  )
  cmp <- compare_front_spec(res$table)
  expect_identical(cmp$front, cmp$spec)
})

test_that("cox 交互效应前后端列一致", {
  dat <- data.frame(
    time = rexp(200, 0.1),
    status = sample(c(0, 1), 200, TRUE),
    sex = factor(sample(c("M", "F"), 200, TRUE)),
    age = rnorm(200, 60, 8),
    stringsAsFactors = FALSE
  )
  res <- perform_cox_analysis(
    data = dat,
    cox_time = "time",
    cox_status = "status",
    cox_covariates = c("age"),
    cox_strata = "sex"
  )
  cmp <- compare_front_spec(res$table)
  expect_identical(cmp$front, cmp$spec)
})

test_that("无分组时交互效应以独立列展示", {
  dat <- data.frame(
    event = sample(c(0, 1), 200, TRUE),
    sex = factor(sample(c("M", "F"), 200, TRUE)),
    treat = factor(sample(c("A", "B"), 200, TRUE)),
    stringsAsFactors = FALSE
  )
  res <- perform_logistic_analysis(
    data = dat,
    logistic_response = "event",
    logistic_predictors = c("treat"),
    logistic_strata = "sex",
    logistic_event_value = "1"
  )
  front <- as.data.frame(res$table[["_data"]], stringsAsFactors = FALSE)
  expect_true(any(grepl("P for interaction|亚组差异P值", names(front))))
})

