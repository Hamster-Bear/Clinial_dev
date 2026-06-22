# Tables committed_params 契约测试
# 验证 P1 引入的 committed_params 模式在 tables.R 中正确落地
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
library(testthat)

read_utf8 <- function(...) {
  fp <- file.path(project_root, ...)
  paste(readLines(fp, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

tables_text <- read_utf8("modules", "tables.R")

test_that("committed_params is initialized in tables_server", {
  expect_true(grepl("committed_params <- reactiveVal(NULL)", tables_text, fixed = TRUE))
})

test_that("committed_params is cleared on table_type switch", {
  # The observeEvent for table_type should include committed_params(NULL)
  switch_block <- regmatches(tables_text, regexec(
    "observeEvent\\(input\\$table_type.*?\\n.*?\\})", tables_text))[[1]]
  expect_true(length(switch_block) > 0)
  expect_true(grepl("committed_params(NULL)", switch_block, fixed = TRUE))
})

test_that("committed_params is set on successful generate", {
  expect_true(grepl("committed_params(params)", tables_text, fixed = TRUE))
})

test_that("params includes table_type field for all 4 branches", {
  expect_true(grepl('table_type = "t_dm"', tables_text, fixed = TRUE))
  expect_true(grepl('table_type = "t_ae_soc_pt"', tables_text, fixed = TRUE))
  expect_true(grepl('table_type = "listing_general"', tables_text, fixed = TRUE))
  expect_true(grepl('table_type = "ae_sidebyside"', tables_text, fixed = TRUE))
})

test_that("export handler reads from committed_params first", {
  expect_true(grepl("cp <- committed_params", tables_text, fixed = TRUE))
})

test_that("graphics_common.R is sourced for font support", {
  expect_true(grepl("modules/common/graphics/graphics_common.R", tables_text, fixed = TRUE))
})

test_that("ae_sidebyside font guard is simplified", {
  ae_text <- read_utf8("modules", "tables", "ae_sidebyside.R")
  expect_false(grepl("exists\\(\"graphics_resolve_device_safe_family\"",
                      ae_text, fixed = TRUE))
  expect_true(grepl("graphics_resolve_font_spec", ae_text, fixed = TRUE))
})

test_that("task_history_server is wired in tables_server", {
  expect_true(grepl("task_history_server", tables_text, fixed = TRUE))
  expect_true(grepl('scope = "tables"', tables_text, fixed = TRUE))
})

test_that("apply_state functions are exported from each submodule", {
  t_dm_text <- read_utf8("modules", "tables", "t_dm.R")
  expect_true(grepl("apply_t_dm_state", t_dm_text, fixed = TRUE))

  ae_soc_text <- read_utf8("modules", "tables", "t_ae_soc_pt.R")
  expect_true(grepl("apply_t_ae_soc_pt_state", ae_soc_text, fixed = TRUE))

  listing_text <- read_utf8("modules", "tables", "listing_general.R")
  expect_true(grepl("apply_listing_general_state", listing_text, fixed = TRUE))

  ae_side_text <- read_utf8("modules", "tables", "ae_sidebyside.R")
  expect_true(grepl("apply_ae_sidebyside_state", ae_side_text, fixed = TRUE))
})
