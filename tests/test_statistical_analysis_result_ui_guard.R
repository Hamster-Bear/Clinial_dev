args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

library(shiny)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

ui_shell_text <- read_utf8("modules", "common", "ui_shell.R")
stat_text <- read_utf8("modules", "statistical_analysis.R")
if (!nzchar(ui_shell_text) || !nzchar(stat_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(ui_shell_text, "app_result_panel <- function", "ui_shell 提供结果区 panel helper")
expect_contains(ui_shell_text, "app_result_empty <- function", "ui_shell 提供结果区空状态 helper")
expect_contains(ui_shell_text, "\\.app-result-panel", "ui_shell 提供结果区 panel 样式")
expect_contains(ui_shell_text, "\\.app-result-panel__empty", "ui_shell 提供结果区空状态样式")

expect_contains(stat_text, "app_result_panel\\(", "统计分析结果区使用结果 panel helper")
expect_contains(stat_text, "title = \"统计表格结果\"", "统计分析结果区保留统计表格结果容器")
expect_contains(stat_text, "title = \"统计报告说明\"", "统计分析结果区保留统计报告容器")
expect_contains(stat_text, "title = \"可复现代码\"", "统计分析结果区保留可复现代码容器")
expect_contains(stat_text, "title = \"导出配置\"", "统计分析结果区保留导出配置容器")
expect_contains(stat_text, "运行分析后将在此显示统计表格结果。", "统计分析结果区保留表格空状态")
expect_contains(stat_text, "运行分析后将在此显示统计报告和关键解释。", "统计分析结果区保留报告空状态")
expect_contains(stat_text, "运行分析后将在此显示可复现代码。", "统计分析结果区保留代码空状态")
expect_contains(stat_text, "app_result_empty\\(", "统计分析结果区使用统一空状态 helper")

module_path <- function(p) file.path(project_root, p)
source(module_path(file.path("modules", "common", "ui_shell.R")))
panel_ui <- app_result_panel(title = "结果标题", note = "结果说明", tone = "success", app_result_empty("暂无结果"))
empty_ui <- app_result_empty("暂无结果")
if (!inherits(panel_ui, "shiny.tag")) stop("app_result_panel 未返回 shiny.tag", call. = FALSE)
if (!inherits(empty_ui, "shiny.tag")) stop("app_result_empty 未返回 shiny.tag", call. = FALSE)

cat("Statistical analysis result UI guard passed.\n")
