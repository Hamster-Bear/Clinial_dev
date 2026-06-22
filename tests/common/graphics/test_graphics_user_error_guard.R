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

test_that("图形模块页面提示不直接回显程序级异常文本", {
  target_files <- c(
    "modules/statistical_graphics.R",
    "modules/statistical_graphics/survival_analysis.R",
    "modules/statistical_graphics/spider_plot.R",
    "modules/statistical_graphics/swimmer_plot.R",
    "modules/statistical_graphics/waterfall_plot.R",
    "modules/common/graphics/graphics_common.R"
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

