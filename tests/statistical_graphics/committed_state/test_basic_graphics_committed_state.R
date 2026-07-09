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
library(shiny)

source_utf8 <- function(path) {
  Sys.setlocale("LC_CTYPE", "English_United States.65001")
  eval(parse(text = readLines(path, encoding = "UTF-8", warn = FALSE)), envir = .GlobalEnv)
}

test_that("statistical graphics modules parse under default R locale", {
  module_files <- sort(Sys.glob(file.path("..", "modules", "statistical_graphics", "*.R")))
  module_files <- c(file.path("..", "modules", "statistical_graphics.R"), module_files)
  for (module_file in module_files) {
    expect_error(parse(file = module_file), NA, info = normalizePath(module_file, winslash = "/", mustWork = FALSE))
  }
})

source_utf8(file.path("..", "modules", "common", "graphics", "graphics_common.R"))
source_utf8(file.path("..", "modules", "statistical_graphics", "boxplot.R"))
source_utf8(file.path("..", "modules", "statistical_graphics", "heatmap.R"))
source_utf8(file.path("..", "modules", "statistical_graphics", "correlation_matrix.R"))
source_utf8(file.path("..", "modules", "statistical_graphics", "combo_plot.R"))

basic_graphics_data <- function() {
  data.frame(
    grp = factor(c("A", "A", "B", "B", "C", "C")),
    y = c(1, 2, 3, 4, 5, 6),
    z = c(2, 3, 5, 7, 11, 13),
    a = c(1, 2, 3, 4, 5, 6),
    b = c(6, 5, 4, 3, 2, 1),
    c = c(1, 1, 2, 3, 5, 8)
  )
}

test_that("heatmap and correlation reproducible code matches UI correlation pipeline", {
  d <- basic_graphics_data()

  heatmap_code <- generate_graphics_repro_code(
    "heatmap",
    state = list(selected_vars = c("a", "b"))
  )
  expect_match(heatmap_code, 'use = "complete.obs"', fixed = TRUE)
  expect_no_match(heatmap_code, "pairwise.complete.obs|pheatmap")
  expect_match(heatmap_code, "geom_tile", fixed = TRUE)

  heatmap_env <- new.env(parent = globalenv())
  heatmap_env$data <- d
  capture.output(suppressWarnings(eval(parse(text = heatmap_code), envir = heatmap_env)))
  expect_equal(
    heatmap_env$mat,
    stats::cor(d[, c("a", "b"), drop = FALSE], use = "complete.obs"),
    tolerance = 1e-12
  )

  correlation_code <- generate_graphics_repro_code(
    "correlation",
    state = list(selected_vars = c("a", "c"), method = "spearman")
  )
  expect_match(correlation_code, 'use = "complete.obs"', fixed = TRUE)
  expect_no_match(correlation_code, "pairwise.complete.obs|pheatmap")

  correlation_env <- new.env(parent = globalenv())
  correlation_env$data <- d
  capture.output(suppressWarnings(eval(parse(text = correlation_code), envir = correlation_env)))
  expect_equal(
    correlation_env$corr_mat,
    stats::cor(d[, c("a", "c"), drop = FALSE], use = "complete.obs", method = "spearman"),
    tolerance = 1e-12
  )
})

expect_committed_vars <- function(state, input_id, expected) {
  expect_equal(state$input_state[[input_id]], expected)
}

test_that("boxplot state follows generated parameters until rerender", {
  handler <- NULL
  d <- basic_graphics_data()

  testServer(
    function(input, output, session) {
      handler <<- boxplot_server(input, output, session, data = reactive(d))
    },
    {
      session$setInputs(
        boxplot_x = "grp",
        boxplot_y = "y",
        plot_title = "first",
        plot_palette = "lancet",
        line_size = 0.8,
        line_type = "solid",
        point_size = 1.2
      )
      session$setInputs(render_plot = 1)
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "boxplot_y", "y")
      expect_equal(state$extra_state$y_var, "y")
      expect_committed_vars(state, "plot_palette", "lancet")
      expect_equal(state$extra_state$plot_palette, "lancet")
      expect_equal(state$extra_state$line_size, 0.8)
      expect_equal(state$extra_state$line_type, "solid")
      expect_equal(state$extra_state$point_size, 1.2)

      session$setInputs(
        boxplot_y = "z",
        plot_title = "dirty",
        plot_palette = "jama",
        line_size = 1.4,
        line_type = "dashed",
        point_size = 2.2
      )
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "boxplot_y", "y")
      expect_equal(state$extra_state$y_var, "y")
      expect_committed_vars(state, "plot_palette", "lancet")
      expect_equal(state$extra_state$plot_palette, "lancet")
      expect_equal(state$extra_state$line_size, 0.8)
      expect_equal(state$extra_state$line_type, "solid")
      expect_equal(state$extra_state$point_size, 1.2)

      session$setInputs(render_plot = 2)
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "boxplot_y", "z")
      expect_equal(state$extra_state$y_var, "z")
      expect_committed_vars(state, "plot_palette", "jama")
      expect_equal(state$extra_state$plot_palette, "jama")
      expect_equal(state$extra_state$line_size, 1.4)
      expect_equal(state$extra_state$line_type, "dashed")
      expect_equal(state$extra_state$point_size, 2.2)
    }
  )
})

test_that("heatmap state follows generated parameters until rerender", {
  handler <- NULL
  d <- basic_graphics_data()

  testServer(
    function(input, output, session) {
      handler <<- heatmap_server(input, output, session, data = reactive(d))
    },
    {
      session$setInputs(
        heatmap_vars = c("a", "b"),
        heatmap_cluster = TRUE,
        plot_title = "first",
        plot_xlab = "",
        plot_ylab = "",
        color_palette = "heat",
        text_size = 10,
        tile_size = 1,
        show_values = FALSE
      )
      session$setInputs(render_plot = 1)
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "heatmap_vars", c("a", "b"))
      expect_equal(state$extra_state$selected_vars, c("a", "b"))
      expect_equal(state$extra_state$plot_title, "first")

      session$setInputs(heatmap_vars = c("a", "c"), plot_title = "dirty")
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "heatmap_vars", c("a", "b"))
      expect_equal(state$extra_state$selected_vars, c("a", "b"))
      expect_equal(state$extra_state$plot_title, "first")

      session$setInputs(render_plot = 2)
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "heatmap_vars", c("a", "c"))
      expect_equal(state$extra_state$selected_vars, c("a", "c"))
      expect_equal(state$extra_state$plot_title, "dirty")
    }
  )
})

test_that("correlation matrix state follows generated parameters until rerender", {
  handler <- NULL
  d <- basic_graphics_data()

  testServer(
    function(input, output, session) {
      handler <<- correlation_matrix_server(input, output, session, data = reactive(d))
    },
    {
      session$setInputs(
        correlation_vars = c("a", "b"),
        correlation_method = "pearson",
        plot_title = "first",
        plot_xlab = "",
        plot_ylab = "",
        color_palette = "heat",
        text_size = 10,
        tile_size = 1,
        show_values = FALSE
      )
      session$setInputs(render_plot = 1)
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "correlation_vars", c("a", "b"))
      expect_equal(state$extra_state$selected_vars, c("a", "b"))
      expect_equal(state$extra_state$method, "pearson")

      session$setInputs(correlation_vars = c("a", "c"), correlation_method = "spearman")
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "correlation_vars", c("a", "b"))
      expect_equal(state$extra_state$selected_vars, c("a", "b"))
      expect_equal(state$extra_state$method, "pearson")

      session$setInputs(render_plot = 2)
      session$flushReact()

      state <- handler$state()
      expect_committed_vars(state, "correlation_vars", c("a", "c"))
      expect_equal(state$extra_state$selected_vars, c("a", "c"))
      expect_equal(state$extra_state$method, "spearman")
    }
  )
})

test_that("combo plot state carries mapping and dynamic style for reproducible code", {
  handler <- NULL
  d <- basic_graphics_data()

  testServer(
    function(input, output, session) {
      handler <<- combo_plot_server(input, output, session, data = reactive(d))
    },
    {
      session$setInputs(
        main_x_var = "grp",
        main_y_var = "y",
        group_var = "grp",
        facet_var = "grp",
        combo_method = "overlay",
        plot_types = c("scatter", "line"),
        scatter_size = 3.5,
        scatter_alpha = 0.4,
        scatter_jitter = TRUE,
        line_width = 1.8,
        line_type = "dashed",
        line_smooth = FALSE
      )
      session$flushReact()

      state <- handler$state()
      expect_equal(state$extra_state$main_x_var, "grp")
      expect_equal(state$extra_state$main_y_var, "y")
      expect_equal(state$extra_state$group_var, "grp")
      expect_equal(state$extra_state$facet_var, "grp")
      expect_equal(state$extra_state$plot_types, c("scatter", "line"))
      expect_equal(state$extra_state$method, "overlay")
      expect_equal(state$extra_state$scatter_size, 3.5)
      expect_equal(state$extra_state$scatter_alpha, 0.4)
      expect_true(state$extra_state$scatter_jitter)
      expect_equal(state$extra_state$line_width, 1.8)
      expect_equal(state$extra_state$line_type, "dashed")
      expect_false(state$extra_state$line_smooth)
    }
  )
})
