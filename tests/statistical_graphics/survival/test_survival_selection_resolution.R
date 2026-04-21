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

source(file.path("..", "modules", "statistical_graphics", "survival_analysis.R"))

test_that(".resolve_survival_choice 优先保留当前输入值", {
  choices <- c("time", "status", "age")
  out <- .resolve_survival_choice(
    input_value = "status",
    state_value = "time",
    choices = choices,
    default_value = "age"
  )
  expect_equal(out, "status")
})

test_that(".resolve_survival_choice 在输入无效时回退 state/default", {
  choices <- c("time", "status")
  out_state <- .resolve_survival_choice(
    input_value = "invalid",
    state_value = "status",
    choices = choices,
    default_value = "time"
  )
  expect_equal(out_state, "status")
  out_default <- .resolve_survival_choice(
    input_value = "invalid",
    state_value = "missing",
    choices = choices,
    default_value = "time"
  )
  expect_equal(out_default, "time")
})

test_that(".resolve_survival_choice 在无选项时回退默认值", {
  out <- .resolve_survival_choice(
    input_value = "a",
    state_value = "b",
    choices = character(0),
    default_value = "c"
  )
  expect_equal(out, "c")
  out_null <- .resolve_survival_choice(
    input_value = "a",
    state_value = "b",
    choices = character(0),
    default_value = NULL
  )
  expect_null(out_null)
})

test_that("总体标签与图例标签解析一致", {
  expect_equal(
    .format_survival_group_label("all", overall_label = "Overall"),
    "Overall"
  )
  expect_equal(
    .format_survival_group_label("arm=A", strata_var = "arm", strata_labels = list(A = "Treatment A"), overall_label = "Overall"),
    "Treatment A"
  )
  expect_equal(
    .extract_survival_legend_labs(list(strata = NULL), overall_label = "Overall"),
    "Overall"
  )
})

test_that("线条样式应用到现有生存曲线图层", {
  p <- ggplot2::ggplot(data.frame(x = c(0, 1), y = c(1, 0.8)), ggplot2::aes(x, y)) +
    ggplot2::geom_step()
  out <- .apply_survival_line_style(p, line_size = 1.4, line_type = "dashed")
  expect_equal(out$layers[[1]]$aes_params$linetype, "dashed")
  expect_equal(out$layers[[1]]$aes_params$linewidth, 1.4)
})

