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

source_utf8(file.path("modules", "common", "graphics", "graphics_repro.R"))

test_that("组合图可复现代码使用真实映射和动态图层状态", {
  repro_code <- generate_graphics_repro_code(
    "combo",
    state = list(
      main_x_var = "visit",
      main_y_var = "value",
      group_var = "arm",
      facet_var = "site",
      plot_types = c("scatter", "line"),
      method = "overlay",
      scatter_size = 3.5,
      scatter_alpha = 0.4,
      scatter_jitter = TRUE,
      line_width = 1.8,
      line_type = "dashed",
      line_smooth = FALSE
    )
  )

  expect_no_match(repro_code, "aes\\(1, 1\\)")
  expect_match(repro_code, 'x_var <- "visit"', fixed = TRUE)
  expect_match(repro_code, 'y_var <- "value"', fixed = TRUE)
  expect_match(repro_code, 'group_var <- "arm"', fixed = TRUE)
  expect_match(repro_code, 'facet_var <- "site"', fixed = TRUE)
  expect_match(repro_code, "x = .data[[x_var]]", fixed = TRUE)
  expect_match(repro_code, "color = .data[[group_var]]", fixed = TRUE)
  expect_match(repro_code, "facet_wrap", fixed = TRUE)
  expect_match(repro_code, "scatter_size <- 3.5", fixed = TRUE)
  expect_match(repro_code, "line_width <- 1.8", fixed = TRUE)
  expect_match(repro_code, "linewidth = line_width", fixed = TRUE)

  repro_env <- new.env(parent = globalenv())
  repro_env$data <- data.frame(
    visit = rep(1:3, times = 4),
    value = c(1, 2, 3, 2, 3, 4, 1.5, 2.5, 3.5, 2.5, 3.5, 4.5),
    arm = factor(rep(c("A", "B"), each = 6)),
    site = factor(rep(c("S1", "S2"), each = 3, times = 2))
  )

  pdf_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(pdf_file)
  on.exit(grDevices::dev.off(), add = TRUE)
  capture.output(suppressWarnings(eval(parse(text = repro_code), envir = repro_env)))

  expect_s3_class(repro_env$p, "ggplot")
  expect_equal(length(repro_env$p$layers), 2)
  expect_equal(repro_env$p$layers[[1]]$aes_params$size, 3.5)
  expect_equal(repro_env$p$layers[[1]]$aes_params$alpha, 0.4)
  expect_equal(repro_env$p$layers[[2]]$aes_params$linewidth, 1.8)
  expect_equal(repro_env$p$layers[[2]]$aes_params$linetype, "dashed")
  expect_s3_class(repro_env$p$facet, "FacetWrap")
})
