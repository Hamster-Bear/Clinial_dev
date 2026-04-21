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

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

graphics_common_path <- file.path(project_root, "modules", "common", "graphics_common.R")
source(graphics_common_path, local = TRUE)

test_that("任务快照排除 DT 与 Plotly 派生交互输入", {
  input <- shiny::reactiveValues(
    render_plot = 1,
    dl_plot = 1,
    config_tabs = "样式主题",
    lane_color_by = "ARM",
    time_range = c(0, 24),
    tracks = c("ARM", "SEX"),
    lane_table_rows_all = 1:3,
    lane_table_search_columns = data.frame(V1 = "A", stringsAsFactors = FALSE),
    interactive_plot_relayout = list(xaxis = list(range = c(0, 1)))
  )

  state <- isolate(graphics_collect_task_input_state(input))

  expect_true("lane_color_by" %in% names(state))
  expect_true("time_range" %in% names(state))
  expect_true("tracks" %in% names(state))
  expect_false("render_plot" %in% names(state))
  expect_false("dl_plot" %in% names(state))
  expect_false("config_tabs" %in% names(state))
  expect_false("lane_table_rows_all" %in% names(state))
  expect_false("lane_table_search_columns" %in% names(state))
  expect_false("interactive_plot_relayout" %in% names(state))
})

test_that("旧任务恢复时跳过复杂派生输入，只恢复业务字段", {
  sent_ids <- character(0)
  fake_session <- list(
    sendInputMessage = function(input_id, message) {
      sent_ids <<- c(sent_ids, input_id)
      invisible(message)
    }
  )

  expect_true(graphics_restore_single_input_value(fake_session, "time_range", c(0, 24)))
  expect_false(graphics_restore_single_input_value(
    fake_session,
    "lane_table_search_columns",
    data.frame(V1 = "A", stringsAsFactors = FALSE)
  ))
  expect_false(graphics_restore_single_input_value(
    fake_session,
    "interactive_plot_relayout",
    list(xaxis = list(range = c(0, 1)))
  ))

  expect_equal(sent_ids, "time_range")
})



