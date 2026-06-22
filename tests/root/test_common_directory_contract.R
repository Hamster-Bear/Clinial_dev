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

root_dir <- normalizePath(file.path(".."), winslash = "/", mustWork = TRUE)

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

test_that("modules/common 根层只保留跨域入口例外", {
  common_root <- file.path(root_dir, "modules", "common")
  root_files <- sort(basename(list.files(common_root, pattern = "\\.R$", full.names = TRUE)))
  expect_equal(root_files, sort(c("entry_copy.R", "ui_shell.R")))
})

test_that("可归类共享文件已经下沉到五类子目录", {
  expect_true(file.exists(file.path(root_dir, "modules", "common", "graphics", "graphics_common.R")))
  expect_true(file.exists(file.path(root_dir, "modules", "common", "graphics", "graphics_repro.R")))
  expect_true(file.exists(file.path(root_dir, "modules", "common", "graphics", "graphics_export_copy.R")))
  expect_true(file.exists(file.path(root_dir, "modules", "common", "graphics", "graphics_result_copy.R")))
  expect_true(file.exists(file.path(root_dir, "modules", "common", "analysis", "stat_analysis_submodule_copy.R")))
  expect_true(file.exists(file.path(root_dir, "modules", "common", "data", "storage_backend.R")))
})

test_that("PROJECT_GUIDE 记录 common 根层例外边界", {
  guide_text <- read_text(file.path(root_dir, "docs", "main", "PROJECT_GUIDE.md"))
  expect_match(guide_text, "根层只保留 `entry_copy.R` 与 `ui_shell.R`", fixed = TRUE)
  expect_match(guide_text, "新增共享逻辑必须进入 auth/data/analysis/graphics/export", fixed = TRUE)
})
