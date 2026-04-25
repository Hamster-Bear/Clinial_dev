args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = TRUE)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

tables_text <- read_utf8("modules", "tables.R")
if (!nzchar(tables_text)) return(invisible(NULL))

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

expect_contains(tables_text, "source\\(\"modules/common/ui_shell.R\"\\)", "Tables 总入口加载公共 UI 壳")
expect_contains(tables_text, "source\\(\"modules/common/entry_copy.R\"\\)", "Tables 总入口加载入口层共享文案")
expect_contains(tables_text, "copy <- ENTRY_COPY\\$tables", "Tables 总入口读取共享文案")
expect_contains(tables_text, "data_filter_ui\\(ns\\(\"global_filter\"\\)\\)", "Tables 总入口直接复用全局筛选卡")
expect_contains(tables_text, "app_card_box\\(", "Tables 总入口使用公共卡片 helper")
expect_contains(tables_text, "title = copy\\$params\\$title", "Tables 总入口保留参数设置卡")
expect_contains(tables_text, "title = copy\\$result\\$title", "Tables 总入口保留结果卡")
expect_contains(tables_text, "app_result_panel\\(", "Tables 总入口使用结果 panel")
expect_contains(tables_text, "tabPanel\\(\\s*\"表格结果\"", "Tables 总入口保留表格结果页签")
expect_contains(tables_text, "tabPanel\\(\\s*\"R代码\"", "Tables 总入口保留代码页签")
expect_contains(tables_text, "downloadButton\\(ns\\(\"table_download\"\\)", "Tables 总入口保留导出按钮")
expect_contains(tables_text, "uiOutput\\(ns\\(\"dm_params_ui\"\\)\\)", "Tables 总入口保留动态参数输出")
expect_not_contains(tables_text, "(?<!app_card_)box\\([\\s\\S]*title = \"预设图表参数设置\"", "Tables 总入口不再用裸 box 包裹参数卡")
expect_not_contains(tables_text, "(?<!app_card_)box\\([\\s\\S]*title = \"预设图表结果\"", "Tables 总入口不再用裸 box 包裹结果卡")

cat("Tables layout guard passed.\n")
