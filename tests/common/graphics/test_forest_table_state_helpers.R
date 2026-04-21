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

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

helper_path <- file.path(project_root, "modules", "common", "graphics", "forest_table_state_helpers.R")
source(helper_path, local = TRUE)

test_that("forest_normalize_selected_columns 将 list/NULL 统一为字符向量", {
  expect_equal(forest_normalize_selected_columns(NULL), character(0))
  expect_equal(
    forest_normalize_selected_columns(list("A", c("B", "A"), "", NA_character_)),
    c("A", "B")
  )
  expect_equal(
    forest_normalize_selected_columns(c("X", "Y", "X")),
    c("X", "Y")
  )
})

test_that("forest_normalize_selected_columns 产物可安全进入排序比较", {
  lhs <- forest_normalize_selected_columns(list("AVAL", "ARM"))
  rhs <- forest_normalize_selected_columns(c("ARM", "AVAL"))

  expect_no_error(sort(lhs))
  expect_no_error(sort(rhs))
  expect_identical(sort(lhs), sort(rhs))
})

test_that("forest_can_restore_mapping_state 仅在预处理映射列齐备时消费历史快照", {
  extra_state <- list(
    subgroup_col = "grp",
    study_col = "arm",
    estimate_col = "hr",
    lower_col = "lcl",
    upper_col = "ucl"
  )

  expect_true(forest_can_restore_mapping_state(
    mode = "precalculated",
    extra_state = extra_state,
    available_cols = c("grp", "arm", "hr", "lcl", "ucl", "note")
  ))

  expect_false(forest_can_restore_mapping_state(
    mode = "precalculated",
    extra_state = extra_state,
    available_cols = c("grp", "arm", "hr", "note")
  ))

  expect_true(forest_can_restore_mapping_state(
    mode = "raw_data",
    extra_state = extra_state,
    available_cols = c("AVAL", "CNSR")
  ))
})

test_that("forest_build_mapping_restore_plan 优先恢复保存的列映射并过滤协变量", {
  plan <- forest_build_mapping_restore_plan(
    available_cols = c("grp", "arm", "hr", "lcl", "ucl", "OS_time", "OS_status", "AGE"),
    current_state = list(
      subgroup_col = "grp",
      study_col = "arm",
      estimate_col = "hr",
      lower_col = "lcl",
      upper_col = "ucl",
      time_col = "OS_time",
      status_col = "OS_status",
      outcome_col = NULL,
      covariates = c("AGE", "MISSING")
    ),
    extra_state = list(
      subgroup_col = "grp",
      study_col = "arm",
      estimate_col = "hr",
      lower_col = "lcl",
      upper_col = "ucl",
      time_col = "OS_time",
      status_col = "OS_status",
      covariates = c("AGE", "UNKNOWN")
    ),
    mode = "precalculated"
  )

  expect_true(plan$ready)
  expect_identical(plan$subgroup_col, "grp")
  expect_identical(plan$study_col, "arm")
  expect_identical(plan$estimate_col, "hr")
  expect_identical(plan$lower_col, "lcl")
  expect_identical(plan$upper_col, "ucl")
  expect_identical(plan$time_col, "OS_time")
  expect_identical(plan$status_col, "OS_status")
  expect_identical(plan$covariates, "AGE")
})



