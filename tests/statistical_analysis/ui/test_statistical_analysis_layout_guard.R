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
      if (file.exists(file.path(current, "app.R")) && dir.exists(file.path(current, "modules")) && dir.exists(file.path(current, "tests"))) {
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
  if (!grepl(pattern, text, perl = TRUE)) stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
}
# 基础结构
expect_contains(stat_analysis_text, "app_card_dependencies\\(\\)", "加载公共卡片依赖")
expect_contains(stat_analysis_text, "copy <- ENTRY_COPY\\$statistical_analysis", "读取共享文案")
expect_contains(stat_analysis_text, "app_card_box\\(", "使用公共卡片 helper")
expect_contains(stat_analysis_text, "app_result_panel\\(", "使用公共结果面板")
# 左右排布：左侧方法选择+参数设置，右侧结果区
expect_contains(stat_analysis_text, "data_filter_ui\\(ns\\(\"global_filter\"\\)\\)", "保留全局筛选模块")
expect_contains(stat_analysis_text, "title = copy\\$method\\$title", "方法选择卡片")
expect_contains(stat_analysis_text, "title = copy\\$params\\$title", "参数卡片")
expect_contains(stat_analysis_text, "title = copy\\$result\\$title", "结果卡片")
expect_contains(stat_analysis_text, "uiOutput\\(ns\\(\"stat_params_ui\"\\)\\)", "动态参数输出")
expect_contains(stat_analysis_text, "filtered_data\\(\\)", "检查数据可用性")
expect_contains(stat_analysis_text, "请先上传数据并完成筛选", "数据未加载占位提示")
# 结果区
expect_contains(stat_analysis_text, "tabPanel\\(\\s*\"统计表格\"", "保留统计表格页签")
expect_contains(stat_analysis_text, "tabPanel\\(\\s*\"统计报告\"", "保留统计报告页签")
expect_contains(stat_analysis_text, "tabPanel\\(\\s*\"可复现代码\"", "保留可复现代码页签")
expect_contains(stat_analysis_text, "downloadButton\\(ns\\(\"dl_table\"\\)", "保留导出按钮")
# 任务历史
expect_contains(stat_analysis_text, "task_history_ui", "保留任务历史 UI")
expect_contains(stat_analysis_text, "task_history_server", "保留任务历史 Server")
cat("Statistical analysis layout guard passed.\n")
