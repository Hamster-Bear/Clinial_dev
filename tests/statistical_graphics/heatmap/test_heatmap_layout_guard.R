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

library(testthat)

source_text <- paste(readLines(file.path(project_root, "modules", "statistical_graphics", "heatmap.R"),
  encoding = "UTF-8", warn = FALSE), collapse = "\n")

test_that("热图模块使用统一三卡外层结构", {
  expect_true(grepl('"数据与变量"', source_text, fixed = TRUE),
    info = "缺少'数据与变量'卡片")
  expect_true(grepl('"图形与样式"', source_text, fixed = TRUE),
    info = "缺少'图形与样式'卡片")
  expect_true(grepl('"输出与导出"', source_text, fixed = TRUE),
    info = "缺少'输出与导出'卡片")
})

test_that("热图模块包含结果区动作条和结果页签", {
  expect_true(grepl("graphics_output_action_bar_ui", source_text, fixed = TRUE),
    info = "缺少 graphics_output_action_bar_ui 调用")
  expect_true(grepl('"静态图"', source_text, fixed = TRUE),
    info = "缺少'静态图'结果页签")
  expect_true(grepl('"交互图"', source_text, fixed = TRUE),
    info = "缺少'交互图'结果页签")
  expect_true(grepl('"数据"', source_text, fixed = TRUE),
    info = "缺少'数据'结果页签")
})

test_that("热图模块不包含已废弃的裸 box 或 wellPanel 包装", {
  expect_false(grepl("box\\(\\s*title\\s*=", source_text, perl = TRUE),
    info = "不应包含裸 box() 包装")
  expect_false(grepl("wellPanel\\(", source_text, fixed = TRUE),
    info = "不应包含裸 wellPanel() 包装")
})

test_that("热图模块包含 task_history state/apply_state 契约", {
  expect_true(grepl("state = reactive", source_text, fixed = TRUE),
    info = "缺少 state reactive")
  expect_true(grepl("apply_state <- function", source_text, fixed = TRUE),
    info = "缺少 apply_state 函数")
  expect_true(grepl("graphics_build_task_state", source_text, fixed = TRUE),
    info = "缺少 graphics_build_task_state 调用")
  expect_true(grepl("graphics_restore_task_input_state", source_text, fixed = TRUE),
    info = "缺少 graphics_restore_task_input_state 调用")
})
