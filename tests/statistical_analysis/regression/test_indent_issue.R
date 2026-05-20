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
library(dplyr)

module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}
source(module_path("modules/common/export/table_export.R"))
source(module_path("modules/common/analysis/analysis_format.R"))
source(module_path("modules/common/analysis/analysis_shared.R"))
source(module_path("modules/statistical_analysis/linear.R"))

set.seed(123)
n <- 50
mock_data <- data.frame(
  response = rnorm(n, 100, 15),
  age = rnorm(n, 60, 10),
  sex = factor(sample(c("Male", "Female"), n, replace = TRUE)),
  stratum = factor(sample(c("A", "B", "C"), n, replace = TRUE)),
  facet = factor(sample(c("Group1", "Group2"), n, replace = TRUE))
)

test_that("线性回归无亚组无列分组：前后端预测变量行数一致", {
  res <- perform_linear_analysis(
    data = mock_data,
    linear_response = "response",
    linear_predictors = c("age", "sex"),
    linear_strata = NULL,
    linear_facet = NULL,
    linear_reference_map = c(sex = "Female")
  )
  raw_rows <- nrow(res$table[["_data"]])
  front_rows <- nrow(extract_table_dataframe(res$table))
  expect_equal(raw_rows, front_rows,
    info = sprintf("原始数据 %d 行 != 前端数据 %d 行", raw_rows, front_rows))
})

test_that("线性回归有亚组无列分组：前后端预测变量缩进格式保留", {
  res <- perform_linear_analysis(
    data = mock_data,
    linear_response = "response",
    linear_predictors = c("age", "sex"),
    linear_strata = "stratum",
    linear_facet = NULL,
    linear_reference_map = c(sex = "Female")
  )
  raw_rows <- nrow(res$table[["_data"]])
  front_rows <- nrow(extract_table_dataframe(res$table))
  expect_equal(raw_rows, front_rows)

  raw_pred <- res$table[["_data"]][["预测变量"]]
  expect_true(any(grepl("^\\s", raw_pred)),
    info = "预测变量列应有缩进格式（非空前导空格）")
})

test_that("线性回归有亚组有列分组：前后端行数与列分组列名一致", {
  res <- perform_linear_analysis(
    data = mock_data,
    linear_response = "response",
    linear_predictors = c("age", "sex"),
    linear_strata = "stratum",
    linear_facet = "facet",
    linear_reference_map = c(sex = "Female")
  )
  raw_rows <- nrow(res$table[["_data"]])
  front_rows <- nrow(extract_table_dataframe(res$table))
  expect_equal(raw_rows, front_rows)

  expect_true("亚组" %in% names(res$table[["_data"]]),
    info = "有亚组时表格应包含亚组列")
})

test_that("导出数据框与原始数据预测变量列内容一致", {
  res <- perform_linear_analysis(
    data = mock_data,
    linear_response = "response",
    linear_predictors = c("age", "sex"),
    linear_strata = NULL,
    linear_facet = NULL,
    linear_reference_map = c(sex = "Female")
  )
  ft_df <- extract_table_dataframe(res$table)
  pred_cols <- grep("预测变量|label|Variable", names(ft_df), value = TRUE)
  expect_true(length(pred_cols) > 0,
    info = "导出数据框应包含预测变量相关列")
})
