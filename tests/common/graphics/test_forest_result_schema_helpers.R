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

source(file.path(project_root, "modules", "common", "export", "table_export.R"), local = TRUE)
source(file.path(project_root, "modules", "common", "graphics", "forest_result_schema_helpers.R"), local = TRUE)

test_that("森林图 raw-data 分析结果复用 AMA P 值格式", {
  out <- forest_finalize_analysis_results(list(data.frame(
    Variable = c("A", "B", "C", "D"),
    Level = "Continuous",
    Estimate = 1,
    Lower = 0.8,
    Upper = 1.2,
    P_Value = c(0.0004, 0.025, 0.995, NA),
    N = 10,
    Events = 3,
    stringsAsFactors = FALSE
  )))

  expect_equal(out$P_Value_Raw, c(0.0004, 0.025, 0.995, NA))
  expect_equal(out$P_Value_Str, c("<0.001", "0.025", ">0.99", "—"))
})
