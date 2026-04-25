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

frontend_copy_targets <- c(
  file.path("modules", "common", "data_filter.R"),
  file.path("modules", "task_history.R"),
  file.path("modules", "statistical_analysis.R"),
  file.path("modules", "statistical_graphics.R"),
  file.path("modules", "tables.R"),
  file.path("modules", "exploratory_analysis.R"),
  file.path("modules", "statistical_analysis", "anova.R"),
  file.path("modules", "statistical_analysis", "chisq.R"),
  file.path("modules", "statistical_analysis", "cox.R"),
  file.path("modules", "statistical_analysis", "desc.R"),
  file.path("modules", "statistical_analysis", "linear.R"),
  file.path("modules", "statistical_analysis", "logistic.R"),
  file.path("modules", "statistical_graphics", "boxplot.R"),
  file.path("modules", "statistical_graphics", "combo_plot.R"),
  file.path("modules", "statistical_graphics", "forest_plot.R"),
  file.path("modules", "statistical_graphics", "spider_plot.R"),
  file.path("modules", "statistical_graphics", "survival_analysis.R"),
  file.path("modules", "statistical_graphics", "swimmer_plot.R"),
  file.path("modules", "statistical_graphics", "waterfall_plot.R")
)

forbidden_patterns <- c(
  "本轮只统一",
  "继续保留",
  "当前统一",
  "继续沿用",
  "后续如补充"
)

test_that("前端用户文案不得暴露开发阶段口径", {
  for (relative_path in frontend_copy_targets) {
    content <- read_utf8(relative_path)
    for (pattern in forbidden_patterns) {
      expect_false(
        grepl(pattern, content, perl = TRUE),
        info = sprintf("%s 仍包含开发向前端文案: %s", relative_path, pattern)
      )
    }
  }
})
