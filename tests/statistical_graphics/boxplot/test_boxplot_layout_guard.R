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

boxplot_text <- read_utf8("modules", "statistical_graphics", "boxplot.R")
if (!nzchar(boxplot_text)) return(invisible(NULL))

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

expect_contains(boxplot_text, "source\\(\"modules/common/ui_shell.R\"\\)|source\\(file.path\\(\"\\.\\.\", \"modules\", \"common\", \"ui_shell.R\"\\)\\)", "箱线图加载公共 UI 壳")
expect_contains(boxplot_text, "app_card_box\\(", "箱线图外层使用公共卡片 helper")
expect_contains(boxplot_text, "title = \"数据与变量\"", "箱线图保留数据与变量顶层卡")
expect_contains(boxplot_text, "title = \"图形与样式\"", "箱线图保留图形与样式顶层卡")
expect_contains(boxplot_text, "title = \"输出与导出\"", "箱线图保留输出与导出顶层卡")
expect_contains(boxplot_text, "title = \"结果区\"", "箱线图保留结果区顶层卡")
expect_contains(boxplot_text, "graphics_output_action_bar_ui\\(", "箱线图结果区保留动作条")
expect_contains(boxplot_text, "tabPanel\\(\\s*\"静态图\"", "箱线图保留静态图页签")
expect_contains(boxplot_text, "tabPanel\\(\\s*\"交互图\"", "箱线图保留交互图页签")
expect_contains(boxplot_text, "tabPanel\\(\\s*\"数据\"", "箱线图保留数据页签")
expect_contains(boxplot_text, "tabPanel\\(\\s*\"可复现代码\"", "箱线图结果区新增可复现代码页签")
expect_contains(boxplot_text, "plotOutput\\(ns\\(\"static_plot\"\\), height = \"600px\"\\)", "箱线图保留静态图输出")
expect_contains(boxplot_text, "plotly::plotlyOutput\\(ns\\(\"interactive_plot\"\\), height = \"600px\"\\)", "箱线图保留交互图输出")
expect_contains(boxplot_text, "DTOutput\\(ns\\(\"data_table\"\\)\\)", "箱线图保留数据表输出")
expect_contains(boxplot_text, "selectizeInput\\(ns\\(\"boxplot_x\"\\)", "箱线图保留 X 轴映射控件")
expect_contains(boxplot_text, "selectizeInput\\(ns\\(\"boxplot_y\"\\)", "箱线图保留 Y 轴映射控件")
expect_not_contains(boxplot_text, "(?<!app_card_)box\\([\\s\\S]*title = \"箱线图参数配置\"", "箱线图外层不再用裸 box 包裹参数配置")
expect_not_contains(boxplot_text, "\\bwellPanel\\(", "箱线图外层不再使用裸 wellPanel")

cat("Boxplot layout guard passed.\n")
