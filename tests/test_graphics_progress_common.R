library(testthat)

source(file.path("..", "modules", "common", "graphics_common.R"))

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
