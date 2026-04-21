args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", "..", ".."), winslash = "/", mustWork = TRUE)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

graphics_text <- read_utf8("modules", "statistical_graphics.R")
if (!nzchar(graphics_text)) return(invisible(NULL))

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

expect_contains(graphics_text, "source\\(\"modules/common/ui_shell.R\"\\)", "统计图形总入口加载公共 UI 壳")
expect_contains(graphics_text, "data_filter_ui\\(ns\\(\"global_filter\"\\)\\)", "统计图形总入口直接复用全局筛选卡")
expect_contains(graphics_text, "task_history_ui\\(", "统计图形总入口直接复用任务历史卡")
expect_contains(graphics_text, "app_card_box\\(", "统计图形总入口使用公共卡片 helper")
expect_contains(graphics_text, "title = \"统计图形类型选择\"", "统计图形总入口保留类型选择卡")
expect_contains(graphics_text, "title = \"可复现代码\"", "统计图形总入口保留可复现代码卡")
expect_contains(graphics_text, "app_result_panel\\(", "统计图形总入口可复现代码使用结果 panel")
expect_contains(graphics_text, "switch\\(input\\$fig_type", "统计图形总入口保留子模块切换逻辑")
expect_not_contains(graphics_text, "(?<!app_card_)box\\([\\s\\S]*title = \"统计图形类型选择\"", "统计图形总入口不再用裸 box 包裹类型选择卡")
expect_not_contains(graphics_text, "(?<!app_card_)box\\([\\s\\S]*title = \"可复现代码\"", "统计图形总入口不再用裸 box 包裹可复现代码卡")

cat("Statistical graphics layout guard passed.\n")
