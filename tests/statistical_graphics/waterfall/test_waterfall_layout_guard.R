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

waterfall_text <- read_utf8("modules", "statistical_graphics", "waterfall_plot.R")
if (!nzchar(waterfall_text)) return(invisible(NULL))

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

expect_contains(waterfall_text, "source\\(\"modules/common/ui_shell.R\"\\)|source\\(file.path\\(\"\\.\\.\", \"modules\", \"common\", \"ui_shell.R\"\\)\\)", "瀑布图加载公共 UI 壳")
expect_contains(waterfall_text, "app_card_box\\(", "瀑布图外层使用公共卡片 helper")
expect_contains(waterfall_text, "title = \"数据与变量\"", "瀑布图保留数据与变量顶层卡")
expect_contains(waterfall_text, "title = \"图形与样式\"", "瀑布图保留图形与样式顶层卡")
expect_contains(waterfall_text, "title = \"输出与导出\"", "瀑布图保留输出与导出顶层卡")
expect_contains(waterfall_text, "title = \"结果区\"", "瀑布图保留结果区顶层卡")
expect_contains(waterfall_text, "graphics_output_action_bar_ui\\(", "瀑布图结果区保留动作条")
expect_contains(waterfall_text, "tabPanel\\(\\s*\"静态图\"", "瀑布图保留静态图页签")
expect_contains(waterfall_text, "tabPanel\\(\\s*\"交互图\"", "瀑布图保留交互图页签")
expect_contains(waterfall_text, "tabPanel\\(\\s*\"数据\"", "瀑布图保留数据页签")
expect_contains(waterfall_text, "DTOutput\\(ns\\(\"data_table\"\\)\\)", "瀑布图保留瀑布数据输出")
expect_contains(waterfall_text, "DTOutput\\(ns\\(\"track_table\"\\)\\)", "瀑布图保留分组轨道数据输出")
expect_contains(waterfall_text, "graphics_reference_threshold_panel_ui\\(", "瀑布图保留参考线与阈值控件")
expect_contains(waterfall_text, "graphics_column_mapping_panel_ui\\(", "瀑布图保留列映射控件")
expect_not_contains(waterfall_text, "(?<!app_card_)box\\([\\s\\S]*title = \"瀑布图参数配置\"", "瀑布图外层不再用裸 box 包裹参数配置")
expect_not_contains(waterfall_text, "\\bwellPanel\\(", "瀑布图外层不再使用裸 wellPanel")

cat("Waterfall layout guard passed.\n")
