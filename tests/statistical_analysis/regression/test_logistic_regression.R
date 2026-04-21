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
library(shiny)
library(dplyr)
logistic_module <- if (file.exists("modules/statistical_analysis/logistic.R")) {
  "modules/statistical_analysis/logistic.R"
} else {
  file.path("..", "modules", "statistical_analysis", "logistic.R")
}
source(logistic_module)

set.seed(20260312)

build_logistic_data <- function() {
  n <- 240
  trt <- factor(sample(c("A", "B"), n, replace = TRUE))
  sex <- factor(sample(c("男", "女"), n, replace = TRUE))
  site <- factor(sample(c("中心1", "中心2", "中心3"), n, replace = TRUE))
  age <- rnorm(n, 56, 10)
  bmi <- rnorm(n, 24, 3.5)
  lp <- -2 + 0.04 * age + 0.12 * bmi + ifelse(trt == "B", 0.4, 0) + ifelse(sex == "男", 0.2, 0)
  p <- 1 / (1 + exp(-lp))
  y <- rbinom(n, 1, p)
  data.frame(
    Y = y,
    TRT = trt,
    SEX = sex,
    SITE = site,
    AGE = age,
    BMI = bmi,
    stringsAsFactors = TRUE
  )
}

assert_gt_tbl <- function(x, scenario) {
  if (!is.list(x) || is.null(x$table) || !inherits(x$table, "gt_tbl")) {
    stop(paste0("[", scenario, "] 输出不是包含 gt_tbl 的列表"))
  }
}

run_case <- function(df, scenario, response, predictors, strata, facet) {
  out <- perform_logistic_analysis(
    data = df,
    logistic_response = response,
    logistic_predictors = predictors,
    logistic_strata = strata,
    logistic_facet = facet
  )
  assert_gt_tbl(out, scenario)
  tbl <- out$table[["_data"]]
  if (is.null(tbl) || nrow(tbl) == 0) {
    stop(paste0("[", scenario, "] 输出数据为空"))
  }
  message("[PASS] ", scenario, " rows=", nrow(tbl), " cols=", ncol(tbl))
}

df <- build_logistic_data()

run_case(
  df = df,
  scenario = "无分层无分组",
  response = "Y",
  predictors = c("AGE", "BMI", "TRT", "SEX"),
  strata = "None",
  facet = "None"
)

run_case(
  df = df,
  scenario = "仅列分组",
  response = "Y",
  predictors = c("AGE", "BMI", "SEX"),
  strata = "None",
  facet = "TRT"
)

run_case(
  df = df,
  scenario = "仅行分组",
  response = "Y",
  predictors = c("AGE", "BMI", "TRT"),
  strata = "SEX",
  facet = "None"
)

run_case(
  df = df,
  scenario = "行列分组",
  response = "Y",
  predictors = c("AGE", "BMI"),
  strata = "SEX",
  facet = "TRT"
)

message("逻辑回归全场景测试完成")

