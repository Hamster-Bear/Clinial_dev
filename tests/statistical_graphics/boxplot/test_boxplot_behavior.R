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
setwd(project_root)

library(testthat)

source_utf8 <- function(path) {
  eval(parse(text = readLines(path, encoding = "UTF-8", warn = FALSE)), envir = .GlobalEnv)
}

source_utf8(file.path("modules", "common", "graphics", "graphics_common.R"))
source_utf8(file.path("modules", "statistical_graphics", "boxplot.R"))

test_that("箱线图样式控件进入 ggplot 绘图对象", {
  plot_data <- data.frame(
    grp = factor(rep(c("A", "B"), each = 4)),
    y = c(1, 2, 3, 12, 4, 5, 6, 18)
  )

  params <- list(
    boxplot_x = "grp",
    boxplot_y = "y",
    plot_title = "Styled boxplot",
    plot_xlab = "",
    plot_ylab = "",
    plot_palette = "lancet",
    line_size = 1.4,
    line_type = "dashed",
    point_size = 2.2
  )

  p <- boxplot_build_plot(plot_data, params)

  expect_s3_class(p, "ggplot")
  expect_match(rlang::quo_text(p$mapping$fill), "grp", fixed = TRUE)
  expect_equal(p$layers[[1]]$aes_params$linewidth, 1.4)
  expect_equal(p$layers[[1]]$aes_params$linetype, "dashed")
  expect_equal(p$layers[[1]]$geom_params$outlier_gp$size, 2.2)
  expect_false(is.null(p$scales$get_scales("fill")))
  expect_warning(ggplot2::ggplot_build(p), NA)
})

test_that("箱线图可复现代码包含样式状态", {
  repro_code <- generate_graphics_repro_code(
    "boxplot",
    state = list(
      x_var = "grp",
      y_var = "y",
      plot_title = "Styled boxplot",
      plot_xlab = "Group",
      plot_ylab = "Value",
      plot_palette = "jama",
      line_size = 1.4,
      line_type = "dashed",
      point_size = 2.2
    )
  )

  expect_match(repro_code, 'plot_palette <- "jama"', fixed = TRUE)
  expect_match(repro_code, "fill = .data[[x_var]]", fixed = TRUE)
  expect_match(repro_code, "linewidth = line_size", fixed = TRUE)
  expect_match(repro_code, "linetype = line_type", fixed = TRUE)
  expect_match(repro_code, "outlier.size = point_size", fixed = TRUE)
  expect_match(repro_code, "ggsci::scale_fill_jama()", fixed = TRUE)

  repro_env <- new.env(parent = globalenv())
  repro_env$data <- data.frame(
    grp = factor(rep(c("A", "B"), each = 4)),
    y = c(1, 2, 3, 12, 4, 5, 6, 18)
  )
  capture.output(suppressWarnings(eval(parse(text = repro_code), envir = repro_env)))

  expect_s3_class(repro_env$p, "ggplot")
  expect_equal(repro_env$p$layers[[1]]$aes_params$linewidth, 1.4)
  expect_equal(repro_env$p$layers[[1]]$aes_params$linetype, "dashed")
  expect_equal(repro_env$p$layers[[1]]$geom_params$outlier_gp$size, 2.2)
  expect_false(is.null(repro_env$p$scales$get_scales("fill")))
})
