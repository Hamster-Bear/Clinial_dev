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
# 文档守卫测试契约
# 目的: 确保项目的核心规范文档不被意外删除，并在一定程度上校验其内容完整性。

library(testthat)

context("Project Documentation Integrity Guard")

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()


test_that("核心规范文档必须存在于项目根目录", {
  required_docs <- c(
    "PROJECT_GUIDE.md",
    "PROJECT_SPEC.md",
    "CODE_STYLE.md",
    "DEPLOYMENT_GUIDE.md",
    "TEST_GUIDE.md",
    "check_test_guide_index.R",
    file.path("tests", "common", "auth", "auth_regression_manifest.json"),
    "AI prompt.md"
  )
  
  for (doc in required_docs) {
    expect_true(
      file.exists(file.path(project_root, doc)),
      info = sprintf("关键规范文档 %s 缺失！请根据【文档驱动】铁律补齐。", doc)
    )
  }
})

test_that("CODE_STYLE.md 必须包含关键约定要求", {
  code_style_path <- file.path(project_root, "CODE_STYLE.md")
  if (file.exists(code_style_path)) {
    code_style_content <- paste(readLines(code_style_path, encoding = "UTF-8"), collapse = "\n")
    expect_match(code_style_content, "tests/")
    expect_match(code_style_content, "testthat")
    expect_match(code_style_content, "PROJECT_GUIDE")
    expect_match(code_style_content, "模块")
  }
})

test_that("TEST_GUIDE.md 必须包含测试索引关键约定", {
  test_guide_path <- file.path(project_root, "TEST_GUIDE.md")
  skip_if_not(file.exists(test_guide_path))
  
  content <- paste(readLines(test_guide_path, encoding = "UTF-8"), collapse = "\n")
  expect_match(content, "tests/")
  expect_match(content, "按项目架构")
  expect_match(content, "run_auth_regression.ps1")
  expect_match(content, "test_project_docs_guard.R")
  expect_match(content, "test_test_guide_index_contract.R")
  expect_match(content, "check_test_guide_index.R")
  expect_match(content, "新增测试更新清单")
})

test_that("PROJECT_SPEC.md 必须包含架构声明", {
  spec_path <- file.path(project_root, "PROJECT_SPEC.md")
  skip_if_not(file.exists(spec_path))
  
  content <- readLines(spec_path, encoding = "UTF-8")
  content_str <- paste(content, collapse = "\n")
  
  expect_match(content_str, "PostgreSQL", info = "PROJECT_SPEC.md 必须声明数据库依赖")
  expect_match(content_str, "Shiny", info = "PROJECT_SPEC.md 必须声明前端框架")
})

test_that("analysis_states 迁移脚本与部署文档必须存在关键约束", {
  migration_path <- file.path(project_root, "postgres", "migrations", "001_analysis_states_schema.sql")
  deployment_path <- file.path(project_root, "DEPLOYMENT_GUIDE.md")

  expect_true(file.exists(migration_path), info = "analysis_states 迁移脚本缺失")
  expect_true(file.exists(deployment_path), info = "DEPLOYMENT_GUIDE.md 缺失")

  migration_content <- paste(readLines(migration_path, encoding = "UTF-8"), collapse = "\n")
  deployment_content <- paste(readLines(deployment_path, encoding = "UTF-8"), collapse = "\n")

  expect_match(migration_content, "uq_analysis_states_user_workspace_scope_module_name")
  expect_match(migration_content, "uq_analysis_states_user_scope_module_name_personal")
  expect_match(migration_content, "DROP CONSTRAINT")
  expect_match(migration_content, "ROW_NUMBER\\(\\) OVER")
  expect_match(deployment_content, "analysis_states")
  expect_match(deployment_content, "001_analysis_states_schema.sql")
})

