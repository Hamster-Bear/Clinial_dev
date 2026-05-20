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
  file.path("modules", "common", "data", "data_filter.R"),
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

copy_guard_json <- file.path(project_root, "inst", "copy_guard_patterns.json")
if (!file.exists(copy_guard_json)) {
  stop("copy_guard_patterns.json 不存在: ", copy_guard_json, call. = FALSE)
}
copy_guard_data <- jsonlite::fromJSON(copy_guard_json, simplifyVector = TRUE)
forbidden_patterns <- copy_guard_data$categories$frontend_dev_jargon$patterns

test_that("前端 copy 守卫 JSON 已加载且覆盖通用开发阶段词汇", {
  expect_true(length(forbidden_patterns) >= 10,
    info = sprintf("forbidden_patterns 数量异常: %d (预期 >= 10)", length(forbidden_patterns)))

  generic_patterns <- c("开发阶段", "内部使用", "暂定", "后续可", "暂时")

  for (pattern in generic_patterns) {
    expect_true(
      any(grepl(pattern, forbidden_patterns, fixed = TRUE)),
      info = sprintf("forbidden_patterns 尚未覆盖通用词汇: %s", pattern)
    )
  }
})

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
