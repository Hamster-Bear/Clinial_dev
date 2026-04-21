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

swimmer_text <- read_utf8("modules", "statistical_graphics", "swimmer_plot.R")
if (!nzchar(swimmer_text)) return(invisible(NULL))

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

expect_contains(swimmer_text, "source\\(\"modules/common/ui_shell.R\"\\)|source\\(file.path\\(\"\\.\\.\", \"modules\", \"common\", \"ui_shell.R\"\\)\\)", "泳道图加载公共 UI 壳")
expect_contains(swimmer_text, "app_card_box\\(", "泳道图外层使用公共卡片 helper")
expect_contains(swimmer_text, "title = \"数据与变量\"", "泳道图保留数据与变量顶层卡")
expect_contains(swimmer_text, "title = \"图形与样式\"", "泳道图保留图形与样式顶层卡")
expect_contains(swimmer_text, "title = \"输出与导出\"", "泳道图保留输出与导出顶层卡")
expect_contains(swimmer_text, "title = \"结果区\"", "泳道图保留结果区顶层卡")
expect_contains(swimmer_text, "graphics_output_action_bar_ui\\(", "泳道图结果区保留动作条")
expect_contains(swimmer_text, "tabPanel\\(\\s*\"静态图\"", "泳道图保留静态图页签")
expect_contains(swimmer_text, "tabPanel\\(\\s*\"交互图\"", "泳道图保留交互图页签")
expect_contains(swimmer_text, "tabPanel\\(\\s*\"数据\"", "泳道图保留数据页签")
expect_contains(swimmer_text, "DTOutput\\(ns\\(\"lane_table\"\\)\\)", "泳道图保留泳道数据输出")
expect_contains(swimmer_text, "DTOutput\\(ns\\(\"event_table\"\\)\\)", "泳道图保留事件数据输出")
expect_contains(swimmer_text, "DTOutput\\(ns\\(\"track_table\"\\)\\)", "泳道图保留分组轨道数据输出")
expect_contains(swimmer_text, "graphics_dynamic_mapping_rows_panel_ui\\(", "泳道图保留事件映射动态控件")
expect_contains(swimmer_text, "graphics_time_axis_panel_ui\\(", "泳道图保留时间轴控件")
expect_not_contains(swimmer_text, "(?<!app_card_)box\\([\\s\\S]*title = \"泳道图参数配置\"", "泳道图外层不再用裸 box 包裹参数配置")
expect_not_contains(swimmer_text, "\\bwellPanel\\(", "泳道图外层不再使用裸 wellPanel")

cat("Swimmer layout guard passed.\n")
