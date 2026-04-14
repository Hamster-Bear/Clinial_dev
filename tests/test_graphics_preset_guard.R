library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- if (length(script_path) > 0 && nzchar(script_path)) {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (basename(wd) == "tests") normalizePath(file.path(wd, ".."), winslash = "/", mustWork = TRUE) else wd
}

graphics_module_path <- file.path(project_root, "modules", "statistical_graphics.R")
task_history_module_path <- file.path(project_root, "modules", "task_history.R")
auth_path <- file.path(project_root, "modules", "common", "auth.R")
sql_path <- file.path(project_root, "postgres", "init.sql")

graphics_text <- paste(readLines(graphics_module_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
task_history_text <- paste(readLines(task_history_module_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
auth_text <- paste(readLines(auth_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
sql_text <- paste(readLines(sql_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

test_that("统计图形总路由接入任务历史保存与加载入口", {
  expect_match(graphics_text, "任务历史")
  expect_match(graphics_text, "source\\(\"modules/task_history\\.R\"\\)")
  expect_match(graphics_text, "task_history_ui\\(")
  expect_match(graphics_text, "task_history_server\\(")
  expect_match(graphics_text, "module_handler_apply_state")
  expect_false(grepl("showNotification\\(paste0\\(\"保存预设失败: \", conditionMessage\\(e\\)\\)", graphics_text))
})

test_that("共享 task_history 模块承载任务历史 UI 与保存逻辑", {
  expect_match(task_history_text, "task_history_ui <- function")
  expect_match(task_history_text, "task_history_server <- function")
  expect_match(task_history_text, "service_save_analysis_state\\(")
  expect_match(task_history_text, "service_get_analysis_state\\(")
  expect_match(task_history_text, "service_delete_analysis_state\\(")
  expect_match(task_history_text, "task_history_operation_user_message")
  expect_match(task_history_text, "task_note")
  expect_match(task_history_text, "delete_task")
  expect_match(task_history_text, "图形参数未选择时系统会按空值/默认值保存，不应因此失败")
})

test_that("图形子模块统一使用完整快照保存，并保留复杂字段回填逻辑", {
  module_paths <- c(
    file.path(project_root, "modules", "statistical_graphics", "survival_analysis.R"),
    file.path(project_root, "modules", "statistical_graphics", "forest_plot.R"),
    file.path(project_root, "modules", "statistical_graphics", "spider_plot.R"),
    file.path(project_root, "modules", "statistical_graphics", "swimmer_plot.R"),
    file.path(project_root, "modules", "statistical_graphics", "boxplot.R"),
    file.path(project_root, "modules", "statistical_graphics", "heatmap.R"),
    file.path(project_root, "modules", "statistical_graphics", "correlation_matrix.R"),
    file.path(project_root, "modules", "statistical_graphics", "combo_plot.R"),
    file.path(project_root, "modules", "statistical_graphics", "waterfall_plot.R")
  )
  for (module_path in module_paths) {
    module_text <- paste(readLines(module_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    expect_match(module_text, "graphics_build_task_state\\(", info = basename(module_path))
  }

  survival_text <- paste(readLines(module_paths[[1]], warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  spider_text <- paste(readLines(module_paths[[3]], warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  swimmer_text <- paste(readLines(module_paths[[4]], warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_match(survival_text, "graphics_restore_task_input_state\\(")
  expect_match(survival_text, "facet_value")
  expect_match(spider_text, "graphics_restore_task_input_state\\(")
  expect_match(swimmer_text, "event_ui_state\\(extra_state\\$event_mappings\\)")
})

test_that("analysis_states 同时写入运行时建表与初始化 SQL", {
  expect_match(auth_text, "CREATE TABLE IF NOT EXISTS analysis_states")
  expect_match(sql_text, "CREATE TABLE IF NOT EXISTS analysis_states")
  expect_match(auth_text, "state_note TEXT")
  expect_match(sql_text, "state_note TEXT")
  expect_match(auth_text, "idx_analysis_states_user_scope")
  expect_match(sql_text, "idx_analysis_states_user_scope")
})

test_that("analysis_states service 对个人任务使用 NULL workspace SQL 分支", {
  account_service_path <- file.path(project_root, "modules", "common", "account_service.R")
  account_text <- paste(readLines(account_service_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_match(account_text, "service_build_analysis_state_insert_spec")
  expect_match(account_text, "VALUES \\(\\$1, \\$2, NULL, \\$3, \\$4, \\$5, \\$6, \\$7, NOW\\(\\), NOW\\(\\)\\)")
  expect_match(account_text, "service_delete_analysis_state")
  expect_match(account_text, "match_workspace = TRUE")
})
