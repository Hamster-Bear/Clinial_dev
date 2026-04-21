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
expect_contains <- function(text, pattern, label, fixed = FALSE) {
  matched <- if (fixed) {
    grepl(pattern, text, fixed = TRUE)
  } else {
    grepl(pattern, text, perl = TRUE)
  }
  if (!isTRUE(matched)) {
    stop(sprintf("%s 缺少预期内容: %s", label, pattern), call. = FALSE)
  }
}

read_utf8 <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

app_text <- read_utf8("app.R")
ui_shell_text <- read_utf8("modules/common/ui_shell.R")
data_prep_text <- read_utf8("modules/data_preparation.R")

expect_contains(app_text, 'source\\("modules/common/ui_shell.R"\\)', "app.R 加载公共 UI 壳")
expect_contains(ui_shell_text, "app_card_dependencies <- function\\(", "公共 UI 壳依赖注入 helper")
expect_contains(ui_shell_text, "app_card_box <- function\\(", "公共 UI 壳卡片 helper")
expect_contains(ui_shell_text, "app_card_note <- function\\(", "公共 UI 壳说明 helper")
expect_contains(ui_shell_text, "app_card_panel <- function\\(", "公共 UI 壳信息面板 helper")
expect_contains(ui_shell_text, "app_stat_card <- function\\(", "公共 UI 壳摘要卡 helper")
expect_contains(data_prep_text, "app_card_dependencies\\(\\)", "数据预备模块加载公共卡片依赖")
expect_contains(data_prep_text, "app_card_box\\(", "数据预备模块使用公共卡片 helper")
expect_contains(data_prep_text, 'title = "数据加载"', "数据预备模块数据加载总卡片")
expect_contains(data_prep_text, 'tabPanel\\(\\s*"本地上传"', "数据预备模块本地上传页签")
expect_contains(data_prep_text, 'tabPanel\\(\\s*"数据库数据集加载"', "数据预备模块数据库数据集页签")
expect_contains(data_prep_text, 'title = "变量与筛选控制"', "数据预备模块变量与筛选控制合并卡片")
expect_contains(data_prep_text, 'title = "高级筛选"', "数据预备模块高级筛选卡片")
expect_contains(data_prep_text, 'title = "数据预览"', "数据预备模块数据预览卡片")
expect_contains(data_prep_text, 'title = "变量信息卡片"', "数据预备模块变量信息卡片")
expect_contains(data_prep_text, "filter_input_cache <- reactiveVal\\(list\\(\\)\\)", "数据预备模块筛选输入缓存")
expect_contains(data_prep_text, "build_filter_ui_state <- function\\(", "数据预备模块筛选 UI 状态构建")
expect_contains(data_prep_text, "capture_filter_state <- function\\(", "数据预备模块筛选状态缓存")
expect_contains(data_prep_text, "app_stat_card\\(", "数据预备模块摘要卡使用公共摘要卡 helper")
expect_contains(data_prep_text, "filter_stats_panel", "数据预备模块筛选统计信息面板")
expect_contains(data_prep_text, "app_card_note\\(", "数据预备模块使用公共说明块")

cat("Data preparation card UI guard passed.\n")

