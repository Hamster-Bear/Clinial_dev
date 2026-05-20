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

guide_text <- paste(
  readLines(file.path(project_root, "docs", "main", "PROJECT_GUIDE.md"), encoding = "UTF-8", warn = FALSE),
  collapse = "\n"
)

forbidden_patterns <- c(
  "当前实际已接入",
  "当前已落地",
  "现已完成真实文件迁移",
  "第九轮已落地",
  "已按统一模板回正",
  "\\[已落地\\]",
  "\\[已落地增强中\\]",
  "\\[已落地首期\\]",
  "\\| 已完成 \\|",
  "已完成 schema 桥接",
  "已开始接入"
)

test_that("PROJECT_GUIDE 不应继续保留状态型过程口径", {
  for (pattern in forbidden_patterns) {
    expect_false(
      grepl(pattern, guide_text, perl = TRUE),
      info = sprintf("PROJECT_GUIDE 仍包含状态型过程口径: %s", pattern)
    )
  }
})
