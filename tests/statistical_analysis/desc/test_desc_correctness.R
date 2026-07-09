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

Sys.setlocale("LC_CTYPE", "Chinese_China.utf8")
project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))
library(testthat)
library(shiny)

source(file.path("..", "modules", "common", "export", "table_export.R"))
source(file.path("..", "modules", "statistical_analysis", "desc.R"))

test_that("描述性统计分类百分比、连续统计量和配置总计列可手算复核", {
  dat <- data.frame(
    id = c("01", "02", "03", "04", "05", "06"),
    arm = factor(c("A", "A", "A", "B", "B", "B")),
    sex = factor(c("F", "M", "F", "M", "M", NA)),
    age = c(10, 20, NA, 30, 40, 50),
    stringsAsFactors = FALSE
  )

  res <- perform_desc_analysis(
    data = dat,
    variables = c("sex", "age"),
    col_group_var = "arm",
    row_group_var = "无",
    total_cols_count = 1,
    total_cols_settings = list(list(name = "All Arms", groups = c("A", "B"))),
    decimals = 1,
    auto_decimals = FALSE,
    id_var = "id"
  )
  raw <- as.data.frame(res$table[["_data"]], stringsAsFactors = FALSE)

  pick <- function(var, stat, col) {
    row <- raw[raw$Variable == var & raw$Statistics == stat, , drop = FALSE]
    expect_equal(nrow(row), 1)
    as.character(row[[col]])
  }

  expect_equal(pick("sex", "F", "A"), "2 (66.7%)")
  expect_equal(pick("sex", "M", "B"), "2 (66.7%)")
  expect_equal(pick("sex", "缺失", "B"), "1 (33.3%)")
  expect_equal(pick("sex", "F", "All Arms"), "2 (33.3%)")
  expect_equal(pick("sex", "缺失", "All Arms"), "1 (16.7%)")

  expect_equal(pick("age", "n", "A"), "2")
  expect_equal(pick("age", "n", "B"), "3")
  expect_equal(pick("age", "n", "All Arms"), "5")
  expect_equal(pick("age", "Mean (SD)", "A"), "15.0 (7.1)")
  expect_equal(pick("age", "Mean (SD)", "B"), "40.0 (10.0)")
  expect_equal(pick("age", "Mean (SD)", "All Arms"), "30.0 (15.8)")
  expect_equal(pick("age", "Q1, Q3", "All Arms"), "20.0, 40.0")
  expect_equal(pick("age", "Min, Max", "All Arms"), "10.0, 50.0")
})

test_that("描述性统计拒绝分析变量与分组变量重复", {
  dat <- data.frame(
    arm = factor(c("A", "A", "B", "B")),
    age = c(10, 20, 30, 40)
  )

  expect_error(
    perform_desc_analysis(
      data = dat,
      variables = c("age", "arm"),
      col_group_var = "arm",
      row_group_var = "无",
      total_cols_count = 0,
      total_cols_settings = list(),
      decimals = 1,
      auto_decimals = FALSE
    ),
    "分析变量不能与分组变量重复"
  )
})

test_that("描述性统计自动小数位支持科学计数法小量数值", {
  dat <- data.frame(
    lab = c(1e-4, 2e-4, 3e-4)
  )

  res <- perform_desc_analysis(
    data = dat,
    variables = "lab",
    col_group_var = "无",
    row_group_var = "无",
    total_cols_count = 0,
    total_cols_settings = list(),
    decimals = 1,
    auto_decimals = TRUE
  )
  raw <- as.data.frame(res$table[["_data"]], stringsAsFactors = FALSE)
  pick <- function(stat) {
    row <- raw[raw$Variable == "lab" & raw$Statistics == stat, , drop = FALSE]
    expect_equal(nrow(row), 1)
    as.character(row$Total)
  }

  expect_equal(pick("Mean (SD)"), "0.00020 (0.000100)")
  expect_equal(pick("Median"), "0.00020")
  expect_equal(pick("Q1, Q3"), "0.00015, 0.00025")
  expect_equal(pick("Min, Max"), "0.0001, 0.0003")
})
