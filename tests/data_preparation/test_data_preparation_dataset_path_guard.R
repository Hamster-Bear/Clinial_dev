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

source(file.path("..", "modules", "common", "data", "data_metadata.R"), local = TRUE)
source(file.path("..", "modules", "data_preparation.R"), local = TRUE)

test_that("data_preparation_build_fallback_dataset_path 在根目录数据集场景不报错", {
  ds_row <- data.frame(
    id = "ds_123",
    workspace_id = "ws_456",
    stringsAsFactors = FALSE
  )

  expect_equal(
    data_preparation_build_fallback_dataset_path("/app/data_storage", ds_row),
    file.path("/app/data_storage", "ws_456", "ds_123.rds")
  )
})

test_that("data_preparation_build_fallback_dataset_path 在子目录数据集场景保留 folder_id", {
  ds_row <- data.frame(
    id = "ds_123",
    workspace_id = "ws_456",
    folder_id = "fd_789",
    stringsAsFactors = FALSE
  )

  expect_equal(
    data_preparation_build_fallback_dataset_path("/app/data_storage", ds_row),
    file.path("/app/data_storage", "ws_456", "fd_789", "ds_123.rds")
  )
})
