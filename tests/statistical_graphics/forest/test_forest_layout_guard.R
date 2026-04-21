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

forest_text <- read_utf8("modules", "statistical_graphics", "forest_plot.R")
if (!nzchar(forest_text)) return(invisible(NULL))

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

expect_contains(forest_text, "source\\(\"modules/common/ui_shell.R\"\\)|source\\(file.path\\(\"\\.\\.\", \"modules\", \"common\", \"ui_shell.R\"\\)\\)", "森林图加载公共 UI 壳")
expect_contains(forest_text, "app_card_box\\(", "森林图外层使用公共卡片 helper")
expect_contains(forest_text, "title = \"数据与变量\"", "森林图保留数据与变量顶层卡")
expect_contains(forest_text, "title = \"图形与样式\"", "森林图保留图形与样式顶层卡")
expect_contains(forest_text, "title = \"输出与导出\"", "森林图保留输出与导出顶层卡")
expect_contains(forest_text, "title = \"结果区\"", "森林图保留结果区顶层卡")
expect_contains(forest_text, "graphics_output_action_bar_ui\\(", "森林图结果区保留动作条")
expect_contains(forest_text, "tabPanel\\(\\s*\"静态图\"", "森林图保留静态图页签")
expect_contains(forest_text, "tabPanel\\(\\s*\"交互图\"", "森林图保留交互图页签")
expect_contains(forest_text, "tabPanel\\(\\s*\"数据\"", "森林图保留数据页签")
expect_contains(forest_text, "DTOutput\\(ns\\(\"data_preview\"\\)\\)", "森林图保留数据预览输出")
expect_contains(forest_text, "uiOutput\\(ns\\(\"analysis_report_ui\"\\)\\)", "森林图保留统计报告输出")
expect_contains(forest_text, "precalculated", "森林图保留预处理数据模式")
expect_contains(forest_text, "raw_data", "森林图保留原始数据模式")
expect_not_contains(forest_text, "(?<!app_card_)box\\([\\s\\S]*title = \"森林图参数配置\"", "森林图外层不再用裸 box 包裹参数配置")
expect_not_contains(forest_text, "\\bwellPanel\\(", "森林图外层不再使用裸 wellPanel")

cat("Forest layout guard passed.\n")
