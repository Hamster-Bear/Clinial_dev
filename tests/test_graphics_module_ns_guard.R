library(testthat)

test_that("使用 renderUI + namespaced output 的主要图形模块必须显式定义 session ns", {
  target_files <- c(
    "modules/statistical_graphics/spider_plot.R",
    "modules/statistical_graphics/waterfall_plot.R",
    "modules/statistical_graphics/swimmer_plot.R"
  )

  for (target in target_files) {
    content <- paste(readLines(file.path("..", target), encoding = "UTF-8"), collapse = "\n")
    expect_match(
      content,
      "session\\$ns",
      info = sprintf("%s 缺少 `ns <- session$ns`，renderUI 内部 namespaced output 可能报错。", target)
    )
  }
})
