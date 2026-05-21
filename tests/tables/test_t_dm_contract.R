# t_dm 合同测试 — perform_t_dm_analysis() 和 generate_t_dm_code()
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
source(file.path(project_root, "modules", "tables", "t_dm.R"))

test_data <- data.frame(
  USUBJID = paste0("SUBJ-", sprintf("%02d", 1:20)),
  AGE = round(rnorm(20, 55, 12)),
  SEX = factor(rep(c("M", "F"), 10)),
  TRT01P = factor(rep(c("Active", "Placebo"), each = 10)),
  RACE = factor(rep(c("White", "Asian", "Black", "Other"), 5)),
  stringsAsFactors = FALSE
)

test_that("perform_t_dm_analysis returns gt_tbl with valid input", {
  result <- perform_t_dm_analysis(test_data, variables = c("AGE", "SEX"))
  expect_s3_class(result, "gt_tbl")
})

test_that("perform_t_dm_analysis with by_var returns gt_tbl", {
  result <- perform_t_dm_analysis(test_data, variables = c("AGE", "SEX"),
                                  by_var = "TRT01P")
  expect_s3_class(result, "gt_tbl")
})

test_that("perform_t_dm_analysis errors on invalid input", {
  expect_error(
    perform_t_dm_analysis(NULL, variables = c("AGE"))
  )
})

test_that("perform_t_dm_analysis detects non-existent variables", {
  expect_error(
    perform_t_dm_analysis(test_data, variables = c("NONEXISTENT")),
    "不存在"
  )
})

test_that("generate_t_dm_code produces non-placeholder output", {
  code <- generate_t_dm_code(c("AGE", "SEX"), by_var = "TRT01P",
                              table_title = "Test Table",
                              table_footnote = "Test footnote")
  expect_false(grepl("代码生成功能待完善", code, fixed = TRUE))
  expect_true(grepl("library(gtsummary)", code, fixed = TRUE))
  expect_true(grepl("perform_t_dm_analysis", code, fixed = TRUE))
  expect_true(grepl("AGE", code, fixed = TRUE))
  expect_true(grepl("Test Table", code, fixed = TRUE))
})

test_that("generate_t_dm_code includes total_cols_settings when provided", {
  settings <- list(list(name = "Total", groups = c("Active", "Placebo")))
  code <- generate_t_dm_code(c("AGE"), by_var = "TRT01P",
                              total_cols_settings = settings)
  expect_true(grepl("total_cols_settings", code, fixed = TRUE))
  expect_true(grepl("Total", code, fixed = TRUE))
})

test_that("generate_t_dm_code handles NULL by_var", {
  code <- generate_t_dm_code(c("AGE", "SEX"), by_var = NULL)
  expect_true(grepl("by_var", code, fixed = TRUE))
})
