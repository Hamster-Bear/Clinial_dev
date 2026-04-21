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
source(module_path("modules/statistical_analysis/cox.R"))
source(module_path("modules/statistical_analysis/linear.R"))

extract_ratio_column <- function(tbl) {
  raw <- as.data.frame(tbl[["_data"]], stringsAsFactors = FALSE)
  n_cols <- grep("(^N$|__N$|Event/N$|__Event/N$|event/N$|__event/N$)", names(raw), value = TRUE)
  box <- as.data.frame(tbl[["_boxhead"]], stringsAsFactors = FALSE)
  label_map <- stats::setNames(as.list(rep("", length(n_cols))), n_cols)
  for (cn in n_cols) {
    if (cn %in% box$var) label_map[[cn]] <- as.character(box$column_label[match(cn, box$var)])
  }
  list(raw = raw, n_cols = n_cols, label_map = label_map)
}

test_that("logistic 在亚组场景下 event/N 按亚组切片计算", {
  dat <- data.frame(
    event = c(rep(1, 10), rep(0, 10)),
    sex = factor(c(rep("M", 10), rep("F", 10))),
    gender = factor(rep(c("Female", "Male"), 10)),
    stringsAsFactors = FALSE
  )
  res <- perform_logistic_analysis(
    data = dat,
    logistic_response = "event",
    logistic_predictors = c("gender"),
    logistic_strata = "sex",
    logistic_event_value = "1"
  )
  ext <- extract_ratio_column(res$table)
  expect_true(length(ext$n_cols) > 0)
  expect_true(any(vapply(ext$label_map, function(z) identical(z, "Event/N") || identical(z, "event/N"), logical(1))))
  vals <- unique(unlist(lapply(ext$n_cols, function(cn) ext$raw[[cn]][nzchar(ext$raw[[cn]])]), use.names = FALSE))
  expect_true("10/10" %in% vals)
  expect_true("0/10" %in% vals)
})

test_that("cox 在亚组场景下 event/N 按亚组切片计算", {
  dat <- data.frame(
    time = rexp(20, 0.1),
    status = c(rep(1, 8), rep(0, 2), rep(1, 2), rep(0, 8)),
    sex = factor(c(rep("M", 10), rep("F", 10))),
    age = rnorm(20, 60, 8),
    stringsAsFactors = FALSE
  )
  res <- perform_cox_analysis(
    data = dat,
    cox_time = "time",
    cox_status = "status",
    cox_covariates = c("age"),
    cox_strata = "sex"
  )
  ext <- extract_ratio_column(res$table)
  expect_true(length(ext$n_cols) > 0)
  expect_true(any(vapply(ext$label_map, function(z) identical(z, "Event/N"), logical(1))))
  vals <- unique(unlist(lapply(ext$n_cols, function(cn) ext$raw[[cn]][nzchar(ext$raw[[cn]])]), use.names = FALSE))
  expect_true("8/10" %in% vals)
  expect_true("2/10" %in% vals)
})

test_that("linear 在亚组场景下 event/N 按亚组切片计算", {
  dat <- data.frame(
    y = c(rnorm(10), rep(NA_real_, 2), rnorm(8)),
    sex = factor(c(rep("M", 10), rep("F", 10))),
    x = rnorm(20),
    stringsAsFactors = FALSE
  )
  res <- perform_linear_analysis(
    data = dat,
    linear_response = "y",
    linear_predictors = c("x"),
    linear_strata = "sex"
  )
  ext <- extract_ratio_column(res$table)
  expect_true(length(ext$n_cols) > 0)
  expect_true(any(vapply(ext$label_map, function(z) identical(z, "Event/N"), logical(1))))
  vals <- unique(unlist(lapply(ext$n_cols, function(cn) ext$raw[[cn]][nzchar(ext$raw[[cn]])]), use.names = FALSE))
  expect_true(any(grepl("^10/10$", vals)))
  expect_true(any(grepl("^8/8$", vals)))
})

test_that("cox 在分组+亚组场景下 event/N 按上下文切片计算", {
  sex <- factor(rep(c("M", "F"), each = 20))
  arm <- factor(rep(c("A", "B"), 20))
  dat <- data.frame(
    time = rexp(40, 0.1),
    status = ifelse(sex == "M" & arm == "A", 1, ifelse(sex == "F" & arm == "B", 1, 0)),
    sex = sex,
    arm = arm,
    age = rnorm(40, 60, 8),
    stringsAsFactors = FALSE
  )
  res <- perform_cox_analysis(
    data = dat,
    cox_time = "time",
    cox_status = "status",
    cox_covariates = c("age"),
    cox_strata = "sex",
    cox_facet = "arm"
  )
  ext <- extract_ratio_column(res$table)
  expect_true(length(ext$n_cols) > 0)
  expect_true(any(vapply(ext$label_map, function(z) identical(z, "Event/N"), logical(1))))
  vals <- unique(unlist(lapply(ext$n_cols, function(cn) ext$raw[[cn]][nzchar(ext$raw[[cn]])]), use.names = FALSE))
  expect_true(all(grepl("^[0-9]+/[0-9]+$", vals)))
  expect_true("10/10" %in% vals)
  expect_true("0/10" %in% vals)
})

