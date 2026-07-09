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
library(testthat)

ensure_test_utf8_locale <- function() {
  for (loc in c("Chinese_China.utf8", "English_United States.65001", "en_US.UTF-8", "C.UTF-8")) {
    try(Sys.setlocale("LC_CTYPE", loc), silent = TRUE)
    if (isTRUE(l10n_info()[["UTF-8"]])) return(invisible(TRUE))
  }
  invisible(FALSE)
}

ensure_test_utf8_locale()
source(file.path(project_root, "modules", "common", "export", "table_export.R"))
source(file.path(project_root, "modules", "common", "analysis", "analysis_format.R"))

emdash <- intToUtf8(8212)

# ---- format_p_value_regression ----

test_that("format_p_value_regression 极小 P 值返回 <0.001", {
  expect_equal(format_p_value_regression(0.0001), "<0.001")
})

test_that("format_p_value_regression 极大 P 值返回 >0.99", {
  expect_equal(format_p_value_regression(0.999), ">0.99")
})

test_that("format_p_value_regression 正常值保留三位小数", {
  expect_equal(format_p_value_regression(0.025), "0.025")
})

test_that("format_p_value_regression NA 返回占位符", {
  expect_equal(format_p_value_regression(NA), emdash)
})

test_that("format_p_value_regression 字符串 NA 返回占位符", {
  expect_equal(format_p_value_regression("NA"), emdash)
})

# ---- format_regression_stat ----

test_that("format_regression_stat 正常格式化", {
  result <- format_regression_stat(1.5, 1.1, 2.0)
  expect_equal(result, "1.50 (1.10, 2.00)")
})

test_that("format_regression_stat NA estimate 返回占位符", {
  expect_equal(format_regression_stat(NA, 1.1, 2.0), emdash)
})

test_that("format_regression_stat NA CI 返回部分格式", {
  result <- format_regression_stat(1.5, NA, NA)
  expect_equal(result, paste0("1.50 (", emdash, ", ", emdash, ")"))
})

test_that("format_regression_stat 字符串输入正确转换", {
  result <- format_regression_stat("2.345", "1.234", "3.456")
  expect_equal(result, "2.35 (1.23, 3.46)")
})

# ---- build_repro_code_template ----

test_that("build_repro_code_template 步骤拼接正确", {
  steps <- list(
    list(title = "加载数据", lines = c("library(dplyr)", "df <- read.csv('data.csv')")),
    list(title = "运行分析", lines = "result <- lm(y ~ x, data = df)")
  )
  code <- build_repro_code_template(steps)
  expect_true(grepl("# 1) 加载数据", code, fixed = TRUE))
  expect_true(grepl("# 2) 运行分析", code, fixed = TRUE))
  expect_true(grepl("library(dplyr)", code, fixed = TRUE))
  expect_true(grepl("result <- lm", code, fixed = TRUE))
})

test_that("build_repro_code_template 空步骤返回空字符串", {
  result <- build_repro_code_template(list())
  expect_equal(result, "")
})

test_that("build_repro_code_template 无 title 时使用 Step N", {
  steps <- list(list(lines = "x <- 1"))
  code <- build_repro_code_template(steps)
  expect_true(grepl("# 1) Step 1", code, fixed = TRUE))
})

test_that("build_repro_code_template 无 lines 时不报错", {
  steps <- list(list(title = "空步骤"))
  code <- build_repro_code_template(steps)
  expect_true(grepl("# 1) 空步骤", code, fixed = TRUE))
})
