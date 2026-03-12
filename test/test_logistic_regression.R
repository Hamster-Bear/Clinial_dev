library(shiny)
library(dplyr)
source("modules/statistical_analysis/logistic.R")

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
