test_find_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- sub(file_arg, "", args[grep(file_arg, args)])
  script_path <- if (length(script_path) > 0) script_path[[1]] else ""
  start_candidates <- unique(c(
    if (nzchar(script_path)) dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)) else character(0),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  ))

  for (candidate in start_candidates) {
    current <- candidate
    repeat {
      if (file.exists(file.path(current, "app.R")) &&
          dir.exists(file.path(current, "modules")) &&
          dir.exists(file.path(current, "tests"))) {
        return(normalizePath(current, winslash = "/", mustWork = TRUE))
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }

  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

exploratory_text <- read_utf8("modules", "exploratory_analysis.R")
if (!nzchar(exploratory_text)) return(invisible(NULL))

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

expect_contains(exploratory_text, "source\\(\"modules/common/ui_shell.R\"\\)", "探索分析总入口加载公共 UI 壳")
expect_contains(exploratory_text, "app_card_box\\(", "探索分析总入口使用公共卡片 helper")
expect_contains(exploratory_text, "title = \"变量托盘\"", "探索分析总入口保留变量托盘卡")
expect_contains(exploratory_text, "title = \"图形控制器\"", "探索分析总入口保留图形控制器卡")
expect_contains(exploratory_text, "title = \"图形输出\"", "探索分析总入口保留图形输出卡")
expect_contains(exploratory_text, "app_card_note\\(", "探索分析总入口使用公共说明块")
expect_contains(exploratory_text, "app_card_panel\\(", "探索分析总入口使用公共分组面板")
expect_contains(exploratory_text, "app_result_panel\\(", "探索分析总入口结果区使用结果 panel")
expect_contains(exploratory_text, "uiOutput\\(ns\\(\"variable_tray\"\\)\\)", "探索分析总入口保留变量托盘输出")
expect_contains(exploratory_text, "selectizeInput\\(ns\\(\"plot_type_exp\"", "探索分析总入口保留图形类型选择")
expect_contains(exploratory_text, "plotly::plotlyOutput\\(ns\\(\"exploratory_plot\"", "探索分析总入口保留 Plotly 输出")
expect_contains(exploratory_text, "observeEvent\\(input\\$reset_mapping", "探索分析总入口保留重置映射逻辑")
expect_not_contains(exploratory_text, "(?<!app_card_)box\\([\\s\\S]*title = \"变量托盘\"", "探索分析总入口不再用裸 box 包裹变量托盘")
expect_not_contains(exploratory_text, "(?<!app_card_)box\\([\\s\\S]*title = \"图形控制器\"", "探索分析总入口不再用裸 box 包裹图形控制器")
expect_not_contains(exploratory_text, "(?<!app_card_)box\\([\\s\\S]*title = \"图形输出\"", "探索分析总入口不再用裸 box 包裹图形输出")

cat("Exploratory analysis layout guard passed.\n")
