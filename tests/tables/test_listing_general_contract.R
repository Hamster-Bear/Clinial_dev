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

skip_if_not_installed("rlistings")
skip_if_not_installed("r2rtf")

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()


source(file.path(project_root, "modules", "tables", "listing_general.R"), local = TRUE)

test_that("normalize_listing_columns 会过滤失效列并保留有效列", {
  df <- data.frame(USUBJID = "01", SITEID = "1001", AVAL = 3.14)
  normalized <- normalize_listing_columns(
    data = df,
    key_cols = c("USUBJID", "MISSING_KEY"),
    disp_cols = c("AVAL", "MISSING_DISP")
  )

  expect_equal(normalized$key_cols, "USUBJID")
  expect_equal(normalized$disp_cols, "AVAL")
  expect_setequal(normalized$missing_cols, c("MISSING_KEY", "MISSING_DISP"))
})

test_that("perform_listing_general_analysis 在存在有效展示列时忽略失效列", {
  df <- data.frame(USUBJID = c("01", "02"), SITEID = c("1001", "1002"), AVAL = c(1.2, 3.4))
  expect_error(
    perform_listing_general_analysis(
      data = df,
      key_cols = c("USUBJID", "MISSING_KEY"),
      disp_cols = c("AVAL", "MISSING_DISP")
    ),
    NA
  )
})

test_that("export_listing_general_rtf 在展示列全部失效时给出友好错误", {
  df <- data.frame(USUBJID = c("01", "02"), SITEID = c("1001", "1002"), AVAL = c(1.2, 3.4))
  tmp <- tempfile(fileext = ".rtf")
  expect_error(
    export_listing_general_rtf(
      data = df,
      key_cols = c("USUBJID"),
      disp_cols = c("MISSING_DISP"),
      file = tmp
    ),
    "当前导出列与数据不匹配，请重新选择变量后重试。"
  )
})

