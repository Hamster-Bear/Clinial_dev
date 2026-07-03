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

survival_text <- read_utf8("modules", "statistical_graphics", "survival_analysis.R")
if (!nzchar(survival_text)) return(invisible(NULL))

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

expect_contains(survival_text, "source\\(\"modules/common/ui_shell.R\"\\)|source\\(file.path\\(\"\\.\\.\", \"modules\", \"common\", \"ui_shell.R\"\\)\\)", "生存分析加载公共 UI 壳")
expect_contains(survival_text, "app_card_box\\(", "生存分析外层使用公共卡片 helper")
expect_contains(survival_text, "title = \"数据与变量\"", "生存分析保留数据与变量顶层卡")
expect_contains(survival_text, "title = \"图形与样式\"", "生存分析保留图形与样式顶层卡")
expect_contains(survival_text, "title = \"输出与导出\"", "生存分析保留输出与导出顶层卡")
expect_contains(survival_text, "title = \"结果区\"", "生存分析保留结果区顶层卡")
expect_contains(survival_text, "graphics_output_action_bar_ui\\(", "生存分析结果区保留动作条")
expect_contains(survival_text, "tabPanel\\(\\s*\"静态图\"", "生存分析保留静态图页签")
expect_contains(survival_text, "tabPanel\\(\\s*\"交互图\"", "生存分析保留交互图页签")
expect_contains(survival_text, "tabPanel\\(\\s*\"数据\"", "生存分析保留数据页签")
expect_contains(survival_text, "tabPanel\\(\\s*\"可复现代码\"", "生存分析结果区新增可复现代码页签")
expect_contains(survival_text, "DTOutput\\(ns\\(\"km_data_table\"\\)\\)", "生存分析保留结果数据表输出")
expect_contains(survival_text, "uiOutput\\(ns\\(\"survival_report\"\\)\\)", "生存分析保留统计报告输出")
expect_contains(survival_text, "do.call\\(\\s*tabsetPanel", "生存分析保留图形与样式内部页签结构")
expect_not_contains(survival_text, "(?<!app_card_)box\\([\\s\\S]*title = \"生存分析参数配置\"", "生存分析外层不再用裸 box 包裹参数配置")
expect_not_contains(survival_text, "\\bwellPanel\\(", "生存分析外层不再使用裸 wellPanel")

cat("Survival layout guard passed.\n")
