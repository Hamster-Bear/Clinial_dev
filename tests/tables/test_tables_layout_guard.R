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
  if (!grepl(pattern, text, perl = TRUE)) stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
}

expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) stop(sprintf("发现应移除内容: %s", label), call. = FALSE)
}

# 基础结构
expect_contains(tables_text, "source\\(\"modules/common/ui_shell.R\"\\)", "加载公共 UI 壳")
expect_contains(tables_text, "source\\(\"modules/common/entry_copy.R\"\\)", "加载入口层共享文案")
expect_contains(tables_text, "copy <- ENTRY_COPY\\$tables", "读取共享文案")
expect_contains(tables_text, "data_filter_ui\\(ns\\(\"global_filter\"\\)\\)", "保留全局筛选卡")
# 卡片布局
expect_contains(tables_text, "app_card_box\\(", "使用公共卡片 helper")
expect_contains(tables_text, "title = copy\\$method\\$title", "方法选择卡片")
expect_contains(tables_text, "title = copy\\$params\\$title", "参数卡片")
expect_contains(tables_text, "app_card_note\\(", "使用公共说明 helper")
# 结果区
expect_contains(tables_text, "title = copy\\$result\\$title", "保留结果卡")
expect_contains(tables_text, "app_result_panel\\(", "使用结果 panel")
expect_contains(tables_text, "tabPanel\\(\\s*\"表格结果\"", "保留表格结果页签")
expect_contains(tables_text, "tabPanel\\(\\s*\"R代码\"", "保留代码页签")
expect_contains(tables_text, "downloadButton\\(ns\\(\"table_download\"\\)", "保留导出按钮")
expect_contains(tables_text, "uiOutput\\(ns\\(\"dm_params_ui\"\\)\\)", "保留动态参数输出")
# 任务历史
expect_contains(tables_text, "task_history_ui", "保留任务历史 UI")

cat("Tables layout guard passed.\n")
