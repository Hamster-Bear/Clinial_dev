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
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

stat_analysis_text <- read_utf8("modules", "statistical_analysis.R")
if (!nzchar(stat_analysis_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("发现应移除内容: %s", label), call. = FALSE)
  }
}

expect_contains(stat_analysis_text, "app_card_dependencies\\(\\)", "统计分析总入口加载公共卡片依赖")
expect_contains(stat_analysis_text, "source\\(\"modules/common/entry_copy.R\"\\)", "统计分析总入口加载入口层共享文案")
expect_contains(stat_analysis_text, "copy <- ENTRY_COPY\\$statistical_analysis", "统计分析总入口读取共享文案")
expect_contains(stat_analysis_text, "app_card_box\\(", "统计分析总入口使用公共卡片 helper")
expect_contains(stat_analysis_text, "app_card_note\\(", "统计分析总入口使用公共说明块")
expect_contains(stat_analysis_text, "app_result_panel\\(", "统计分析总入口使用公共结果面板")
expect_contains(stat_analysis_text, "title = copy\\$filter\\$title", "统计分析总入口全局数据筛选卡片")
expect_contains(stat_analysis_text, "title = copy\\$method\\$title", "统计分析总入口统计方法卡片")
expect_contains(stat_analysis_text, "title = copy\\$params\\$title", "统计分析总入口参数卡片")
expect_contains(stat_analysis_text, "title = copy\\$result\\$title", "统计分析总入口结果卡片")
expect_contains(stat_analysis_text, "tabPanel\\(\\s*\"统计表格\"", "统计分析总入口保留统计表格页签")
expect_contains(stat_analysis_text, "tabPanel\\(\\s*\"统计报告\"", "统计分析总入口保留统计报告页签")
expect_contains(stat_analysis_text, "tabPanel\\(\\s*\"可复现代码\"", "统计分析总入口保留可复现代码页签")
expect_contains(stat_analysis_text, "downloadButton\\(ns\\(\"dl_table\"\\)", "统计分析总入口保留导出按钮")
expect_contains(stat_analysis_text, "data_filter_ui\\(ns\\(\"global_filter\"\\)\\)", "统计分析总入口保留全局筛选模块")
expect_contains(stat_analysis_text, "uiOutput\\(ns\\(\"stat_params_ui\"\\)\\)", "统计分析总入口保留动态参数输出")
expect_not_contains(stat_analysis_text, "\\bbox\\(", "统计分析总入口不再直接使用原生 box helper")

cat("Statistical analysis layout guard passed.\n")

