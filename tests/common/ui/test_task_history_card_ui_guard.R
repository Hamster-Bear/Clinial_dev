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

task_history_text <- read_utf8("modules", "task_history.R")
if (!nzchar(task_history_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(task_history_text, "source\\(\"modules/common/ui_shell.R\"\\)", "task_history 可独立加载公共 UI 壳")
expect_contains(task_history_text, "app_card_box\\(", "task_history 使用公共卡片 helper")
expect_contains(task_history_text, "app_card_note\\(", "task_history 使用公共说明块")
expect_contains(task_history_text, "app_card_panel\\(", "task_history 使用公共信息面板")
expect_contains(task_history_text, "title = title", "task_history 保留动态标题")
expect_contains(task_history_text, "collapsed = TRUE", "task_history 默认折叠")
expect_contains(task_history_text, "textInput\\(ns\\(\"task_name\"\\)", "task_history 保留任务名称输入")
expect_contains(task_history_text, "uiOutput\\(ns\\(\"task_choice_ui\"\\)\\)", "task_history 保留任务选择输出")
expect_contains(task_history_text, "actionButton\\(ns\\(\"save_task\"\\)", "task_history 保留保存任务按钮")
expect_contains(task_history_text, "actionButton\\(ns\\(\"load_task\"\\)", "task_history 保留加载任务按钮")
expect_contains(task_history_text, "actionButton\\(ns\\(\"delete_task\"\\)", "task_history 保留删除任务按钮")
expect_contains(task_history_text, "DT::dataTableOutput\\(ns\\(\"task_history_table\"\\)\\)", "task_history 保留任务历史表格")
expect_contains(task_history_text, "task-history-toolbar", "task_history 使用统一操作区样式")

source(file.path(project_root, "modules", "common", "ui_shell.R"))
source(file.path(project_root, "modules", "task_history.R"))

ui <- task_history_ui("task_history")
if (!inherits(ui, "shiny.tag.list")) stop("task_history_ui 未返回 shiny.tag.list", call. = FALSE)

cat("Task history card UI guard passed.\n")
