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

auth_path <- file.path("..", "modules", "common", "auth", "auth.R")
init_sql_path <- file.path("..", "postgres", "init.sql")
migration_sql_path <- file.path("..", "postgres", "migrations", "001_analysis_states_schema.sql")

test_that("auth runtime schema hook 包含 analysis_states 迁移入口", {
  skip_if_not(file.exists(auth_path))
  auth_text <- paste(readLines(auth_path, encoding = "UTF-8"), collapse = "\n")

  expect_match(auth_text, "auth_migrate_analysis_states_schema <- function")
  expect_match(auth_text, "auth_migrate_analysis_states_schema\\(pool\\)")
  expect_match(auth_text, "uq_analysis_states_user_workspace_scope_module_name")
  expect_match(auth_text, "uq_analysis_states_user_scope_module_name_personal")
})

test_that("analysis_states 初始化与迁移脚本保持唯一索引约束", {
  skip_if_not(file.exists(init_sql_path))
  skip_if_not(file.exists(migration_sql_path))

  init_text <- paste(readLines(init_sql_path, encoding = "UTF-8"), collapse = "\n")
  migration_text <- paste(readLines(migration_sql_path, encoding = "UTF-8"), collapse = "\n")

  expect_match(init_text, "uq_analysis_states_user_workspace_scope_module_name")
  expect_match(init_text, "uq_analysis_states_user_scope_module_name_personal")
  expect_match(migration_text, "ROW_NUMBER\\(\\) OVER")
  expect_match(migration_text, "DROP CONSTRAINT")
})

