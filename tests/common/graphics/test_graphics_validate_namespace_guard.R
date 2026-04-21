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

test_that("图形模块在渲染链路中显式使用 shiny::validate / shiny::need", {
  target_files <- c(
    "modules/statistical_graphics/survival_analysis.R",
    "modules/statistical_graphics/swimmer_plot.R",
    "modules/statistical_graphics/spider_plot.R",
    "modules/statistical_graphics/boxplot.R",
    "modules/statistical_graphics/heatmap.R",
    "modules/statistical_graphics/correlation_matrix.R",
    "modules/statistical_graphics/waterfall_plot.R"
  )

  for (target in target_files) {
    content <- paste(readLines(file.path("..", target), encoding = "UTF-8"), collapse = "\n")
    expect_false(
      grepl("(?<!shiny::)validate\\(", content, perl = TRUE),
      info = sprintf("%s 存在未加命名空间的 validate()，运行时可能调用到错误的同名函数。", target)
    )
    expect_false(
      grepl("(?<!shiny::)need\\(", content, perl = TRUE),
      info = sprintf("%s 存在未加命名空间的 need()，应统一显式绑定 shiny::need。", target)
    )
  }
})

