args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", "..", ".."), winslash = "/", mustWork = TRUE)

library(shiny)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

data_filter_text <- read_utf8("modules", "common", "data", "data_filter.R")
if (!nzchar(data_filter_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(data_filter_text, "source\\(\"modules/common/ui_shell.R\"\\)", "data_filter 可独立加载公共 UI 壳")
expect_contains(data_filter_text, "app_card_box\\(", "data_filter 使用公共卡片 helper")
expect_contains(data_filter_text, "app_card_note\\(", "data_filter 使用公共说明块")
expect_contains(data_filter_text, "app_card_panel\\(", "data_filter 使用公共信息面板")
expect_contains(data_filter_text, "title = \"数据筛选 \\(可选\\)\"", "data_filter 保留数据筛选标题")
expect_contains(data_filter_text, "collapsed = TRUE", "data_filter 默认折叠")
expect_contains(data_filter_text, "selectizeInput\\(", "data_filter 保留变量选择输入")
expect_contains(data_filter_text, "actionButton\\(\\s*ns\\(\"apply_filters\"\\)", "data_filter 保留应用筛选按钮")
expect_contains(data_filter_text, "actionButton\\(\\s*ns\\(\"reset_filters\"\\)", "data_filter 保留重置筛选按钮")
expect_contains(data_filter_text, "verbatimTextOutput\\(ns\\(\"filter_stats\"\\)", "data_filter 保留筛选统计输出")
expect_contains(data_filter_text, "uiOutput\\(ns\\(\"filter_controls\"\\)\\)", "data_filter 保留动态筛选控件输出")
expect_contains(data_filter_text, "filter-card-item", "data_filter 使用统一筛选条件卡片样式")

source(file.path(project_root, "modules", "common", "data", "data_metadata.R"))
source(file.path(project_root, "modules", "common", "ui_shell.R"))
source(file.path(project_root, "modules", "common", "data", "data_filter.R"))

ui <- data_filter_ui("global_filter")
if (!inherits(ui, "shiny.tag.list")) stop("data_filter_ui 未返回 shiny.tag.list", call. = FALSE)

cat("Data filter card UI guard passed.\n")
