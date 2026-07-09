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
source(file.path(project_root, "modules", "common", "analysis", "analysis_shared.R"))

# ---- get_levels_all ----

test_that("get_levels_all 返回 factor levels", {
  x <- factor(c("a", "b", "c"))
  expect_equal(get_levels_all(x), c("a", "b", "c"))
})

test_that("get_levels_all 返回 character unique 值（去 NA）", {
  x <- c("x", "y", NA, "x")
  expect_equal(get_levels_all(x), c("x", "y"))
})

# ---- normalize_optional_var ----

test_that("normalize_optional_var NULL 返回 NULL", {
  expect_null(normalize_optional_var(NULL))
})

test_that("normalize_optional_var 空串返回 NULL", {
  expect_null(normalize_optional_var(""))
})

test_that("normalize_optional_var None 返回 NULL", {
  expect_null(normalize_optional_var("None"))
})

test_that("normalize_optional_var 无 返回 NULL", {
  expect_null(normalize_optional_var("无"))
})

test_that("normalize_optional_var 有效值返回 trimmed", {
  expect_equal(normalize_optional_var("  AGE  "), "AGE")
})

# ---- validate_regression_inputs ----

test_that("validate_regression_inputs 正常输入通过", {
  df <- data.frame(y = 1:10, x1 = rnorm(10), x2 = rnorm(10))
  expect_true(validate_regression_inputs(df, "y", c("x1", "x2")))
})

test_that("validate_regression_inputs 响应变量不存在时报错", {
  df <- data.frame(x1 = 1:5)
  expect_error(validate_regression_inputs(df, "y", "x1"), "响应变量.*不存在")
})

test_that("validate_regression_inputs 预测变量不存在时报错", {
  df <- data.frame(y = 1:5)
  expect_error(validate_regression_inputs(df, "y", "x1"), "预测变量不存在")
})

test_that("validate_regression_inputs 响应变量同时作为预测变量时报错", {
  df <- data.frame(y = 1:5, x1 = rnorm(5))
  expect_error(validate_regression_inputs(df, "y", c("y", "x1")), "响应变量不能同时作为预测变量")
})

test_that("validate_regression_inputs 预测变量与亚组变量重复时报错", {
  df <- data.frame(y = 1:10, x1 = rnorm(10), grp = rep(c("A", "B"), 5))
  expect_error(validate_regression_inputs(df, "y", c("x1", "grp"), split_var = "grp"), "重复")
})

test_that("validate_regression_inputs 亚组变量与分组变量相同时报错", {
  df <- data.frame(y = 1:10, x1 = rnorm(10), grp = rep(c("A", "B"), 5))
  expect_error(validate_regression_inputs(df, "y", "x1", split_var = "grp", facet_var = "grp"), "不能相同")
})

# ---- get_regression_candidate_predictors ----

test_that("get_regression_candidate_predictors 排除指定变量", {
  df <- data.frame(a = 1, b = 2, c = 3, d = 4)
  result <- get_regression_candidate_predictors(df, "a", "b", "c")
  expect_equal(result, "d")
})

test_that("get_regression_candidate_predictors 无排除时返回全部", {
  df <- data.frame(a = 1, b = 2)
  result <- get_regression_candidate_predictors(df)
  expect_equal(result, c("a", "b"))
})

# ---- prepare_predictor_reference_levels ----

test_that("prepare_predictor_reference_levels 设置正确的参考水平", {
  df <- data.frame(
    trt = factor(c("A", "B", "C", "A", "B")),
    age = c(50, 60, 70, 55, 65)
  )
  result <- prepare_predictor_reference_levels(df, c("trt", "age"), reference_map = c(trt = "B"))
  expect_equal(result$pred_ref_level[["trt"]], "B")
  expect_true(result$pred_is_cat[["trt"]])
  expect_false(result$pred_is_cat[["age"]])
  expect_equal(levels(result$data$trt)[1], "B")
})

# ---- regression_norm_text ----

test_that("regression_norm_text 标准化文本", {
  expect_equal(regression_norm_text("  Hello  "), "hello")
  expect_equal(regression_norm_text("ABC"), "abc")
})

# ---- regression_extract_n_cols ----

test_that("regression_extract_n_cols 提取 N 列", {
  df <- data.frame(check.names = FALSE, "总体__N" = 100, DrugA__N = 50, "统计值" = "1.20")
  result <- regression_extract_n_cols(df)
  expect_equal(result, c("总体__N", "DrugA__N"))
})

test_that("regression_extract_n_cols 无 N 列时返回空", {
  df <- data.frame(x = 1, y = 2)
  result <- regression_extract_n_cols(df)
  expect_equal(result, character(0))
})

# ---- get_interaction_p_value ----

test_that("get_interaction_p_value 查找存在的 key", {
  int_map <- c("AGE||DrugB||__ALL__" = "<0.05")
  result <- get_interaction_p_value(int_map, "AGE", "DrugB", "__ALL__")
  expect_equal(result, "<0.05")
})

test_that("get_interaction_p_value 不存在的 key 返回 NA", {
  int_map <- character(0)
  result <- get_interaction_p_value(int_map, "AGE", "DrugB")
  expect_equal(result, "NA")
})
