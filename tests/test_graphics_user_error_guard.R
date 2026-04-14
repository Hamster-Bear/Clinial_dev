library(testthat)

test_that("图形模块页面提示不直接回显程序级异常文本", {
  target_files <- c(
    "modules/statistical_graphics.R",
    "modules/statistical_graphics/survival_analysis.R",
    "modules/statistical_graphics/spider_plot.R",
    "modules/statistical_graphics/swimmer_plot.R",
    "modules/statistical_graphics/waterfall_plot.R",
    "modules/common/graphics_common.R"
  )

  for (target in target_files) {
    content <- paste(readLines(file.path("..", target), encoding = "UTF-8"), collapse = "\n")
    expect_false(
      grepl("showNotification\\([^\\n]*e\\$message", content),
      info = sprintf("%s 仍在页面通知中直接显示 e$message。", target)
    )
    expect_false(
      grepl("showNotification\\([^\\n]*conditionMessage\\(e\\)", content),
      info = sprintf("%s 仍在页面通知中直接显示 conditionMessage(e)。", target)
    )
  }
})
