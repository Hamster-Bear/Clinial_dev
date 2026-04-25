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

read_utf8 <- function(relative_path) {
  file_path <- file.path(project_root, relative_path)
  if (!file.exists(file_path)) {
    stop(sprintf("测试目标文件不存在: %s", relative_path), call. = FALSE)
  }
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

target_files <- c(
  "README.md",
  "PROJECT_GUIDE.md",
  "DEPLOYMENT_GUIDE.md"
)

forbidden_patterns <- c(
  "当前显式提供",
  "当前已改为更明显的",
  "当前已抽成独立模块",
  "当前已提供管理员操作入口",
  "继续看到 workspace 协作权限管理卡"
)

test_that("核心文档中的认证与管理员说明不应保留进度口径", {
  for (relative_path in target_files) {
    content <- read_utf8(relative_path)
    for (pattern in forbidden_patterns) {
      expect_false(
        grepl(pattern, content, perl = TRUE),
        info = sprintf("%s 仍包含灰区进度口径: %s", relative_path, pattern)
      )
    }
  }
})
