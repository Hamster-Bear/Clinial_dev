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

source(file.path("..", "modules", "common", "data_metadata.R"))

test_that("metadata_attach_to_data 同步有效标签与类型元数据", {
  df <- data.frame(
    age = c("10", "20", "30"),
    arm = c("A", "B", "A"),
    stringsAsFactors = FALSE
  )
  attr(df$age, "label") <- "原始年龄"
  out <- metadata_attach_to_data(
    df,
    type_overrides = c(age = "numeric"),
    label_overrides = c(age = "年龄", arm = "治疗组")
  )
  meta <- attr(out, "hamster_var_meta")
  expect_true(is.data.frame(meta))
  expect_equal(meta$type[meta$var_name == "age"], "numeric")
  expect_equal(meta$label[meta$var_name == "age"], "年龄")
  expect_equal(attr(out$arm, "label"), "治疗组")
})

test_that("metadata_build_column_choices 使用有效标签", {
  df <- data.frame(x = 1:2, y = c("A", "B"))
  out <- metadata_attach_to_data(df, label_overrides = c(y = "分组"))
  choices <- metadata_build_column_choices(out)
  expect_true(any(grepl("y \\| 分组", names(choices), fixed = FALSE)))
})

test_that("metadata_get_var_type 优先使用元数据中的有效类型", {
  df <- data.frame(dt = c("2024-01-01", "2024-01-02"), stringsAsFactors = FALSE)
  out <- metadata_attach_to_data(df, type_overrides = c(dt = "date"))
  expect_equal(metadata_get_var_type("dt", out$dt, data = out), "date")
  coerced <- metadata_coerce_var_data(out$dt, metadata_get_var_type("dt", out$dt, data = out))
  expect_s3_class(coerced, "Date")
})

