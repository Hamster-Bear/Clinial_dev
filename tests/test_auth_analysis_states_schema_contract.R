library(testthat)

auth_path <- file.path("..", "modules", "common", "auth.R")
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
