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

combo_text <- read_utf8("modules", "statistical_graphics", "combo_plot.R")
if (!nzchar(combo_text)) return(invisible(NULL))

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

expect_contains(combo_text, "source\\(\"modules/common/ui_shell.R\"\\)|source\\(file.path\\(\"\\.\\.\", \"modules\", \"common\", \"ui_shell.R\"\\)\\)", "组合图加载公共 UI 壳")
expect_contains(combo_text, "app_card_box\\(", "组合图外层使用公共卡片 helper")
expect_contains(combo_text, "title = \"数据与变量\"", "组合图保留数据与变量顶层卡")
expect_contains(combo_text, "title = \"图形与样式\"", "组合图保留图形与样式顶层卡")
expect_contains(combo_text, "title = \"输出与导出\"", "组合图保留输出与导出顶层卡")
expect_contains(combo_text, "title = \"结果区\"", "组合图保留结果区顶层卡")
expect_contains(combo_text, "graphics_output_action_bar_ui\\(", "组合图结果区保留动作条")
expect_contains(combo_text, "tabPanel\\(\\s*\"静态图\"", "组合图保留静态图页签")
expect_contains(combo_text, "tabPanel\\(\\s*\"交互图\"", "组合图保留交互图页签")
expect_contains(combo_text, "tabPanel\\(\\s*\"数据\"", "组合图保留数据页签")
expect_contains(combo_text, "plotOutput\\(ns\\(\"static_plot\"\\), height = \"700px\"\\)", "组合图保留静态图输出")
expect_contains(combo_text, "uiOutput\\(ns\\(\"interactive_plot_ui\"\\)\\)", "组合图保留交互图输出")
expect_contains(combo_text, "DTOutput\\(ns\\(\"combo_data_table\"\\)\\)", "组合图保留结果数据输出")
expect_contains(combo_text, "uiOutput\\(ns\\(\"dynamic_plot_settings\"\\)\\)", "组合图保留动态图层样式控件")
expect_not_contains(combo_text, "(?<!app_card_)box\\([\\s\\S]*title = \"组合图形参数配置\"", "组合图外层不再用裸 box 包裹参数配置")
expect_not_contains(combo_text, "\\bwellPanel\\(", "组合图外层不再使用裸 wellPanel")

cat("Combo layout guard passed.\n")
