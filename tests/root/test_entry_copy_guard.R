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

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

entry_copy_text <- read_utf8("modules", "common", "entry_copy.R")
stat_analysis_text <- read_utf8("modules", "statistical_analysis.R")
stat_graphics_text <- read_utf8("modules", "statistical_graphics.R")
tables_text <- read_utf8("modules", "tables.R")
exploratory_text <- read_utf8("modules", "exploratory_analysis.R")

expect_contains(entry_copy_text, "ENTRY_COPY <- list", "入口层共享文案对象")
expect_contains(entry_copy_text, "entry_copy_get <- function", "入口层共享文案读取 helper")
expect_contains(entry_copy_text, "statistical_analysis = list", "统计分析入口共享文案")
expect_contains(entry_copy_text, "statistical_graphics = list", "统计图形入口共享文案")
expect_contains(entry_copy_text, "tables = list", "Tables 入口共享文案")
expect_contains(entry_copy_text, "exploratory_analysis = list", "探索分析入口共享文案")

expect_contains(stat_analysis_text, "source\\(\"modules/common/entry_copy.R\"\\)", "统计分析入口加载共享文案 helper")
expect_contains(stat_analysis_text, "copy <- ENTRY_COPY\\$statistical_analysis", "统计分析入口读取共享文案")
expect_contains(stat_graphics_text, "source\\(\"modules/common/entry_copy.R\"\\)", "统计图形入口加载共享文案 helper")
expect_contains(stat_graphics_text, "copy <- ENTRY_COPY\\$statistical_graphics", "统计图形入口读取共享文案")
expect_contains(tables_text, "source\\(\"modules/common/entry_copy.R\"\\)", "Tables 入口加载共享文案 helper")
expect_contains(tables_text, "copy <- ENTRY_COPY\\$tables", "Tables 入口读取共享文案")
expect_contains(exploratory_text, "source\\(\"modules/common/entry_copy.R\"\\)", "探索分析入口加载共享文案 helper")
expect_contains(exploratory_text, "copy <- ENTRY_COPY\\$exploratory_analysis", "探索分析入口读取共享文案")

cat("Entry copy guard passed.\n")
