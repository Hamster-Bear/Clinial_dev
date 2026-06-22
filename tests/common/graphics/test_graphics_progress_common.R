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

source_utf8 <- function(path) {
  Sys.setlocale("LC_CTYPE", "English_United States.65001")
  eval(parse(text = readLines(path, encoding = "UTF-8", warn = FALSE)), envir = .GlobalEnv)
}

source_utf8(file.path("..", "modules", "common", "graphics", "graphics_common.R"))

test_that("graphics_progress_text 正确格式化阶段与百分比", {
  msg <- graphics_progress_text("生存分析", detail = "模型拟合", value = 0.55)
  expect_match(msg, "生存分析正在生成图形：模型拟合")
  expect_match(msg, "\\(55%\\)")
})

test_that("graphics_progress_text 百分比自动截断到 0-100", {
  msg_low <- graphics_progress_text("生存分析", detail = "初始化", value = -0.2)
  msg_high <- graphics_progress_text("生存分析", detail = "完成", value = 1.5)
  expect_match(msg_low, "\\(0%\\)")
  expect_match(msg_high, "\\(100%\\)")
})

test_that("graphics_user_safe_error_message 返回面向用户的友好提示", {
  msg <- graphics_user_safe_error_message("泳道图")
  expect_equal(msg, "泳道图生成图形失败，请检查当前参数或数据后重试。")
})

