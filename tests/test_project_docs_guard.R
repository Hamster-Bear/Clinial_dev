# 文档守卫测试契约
# 目的: 确保项目的核心规范文档不被意外删除，并在一定程度上校验其内容完整性。

library(testthat)

context("Project Documentation Integrity Guard")

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- if (length(script_path) > 0 && nzchar(script_path)) {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (basename(wd) == "tests") normalizePath(file.path(wd, ".."), winslash = "/", mustWork = TRUE) else wd
}

test_that("核心规范文档必须存在于项目根目录", {
  required_docs <- c(
    "PROJECT_GUIDE.md",
    "PROJECT_SPEC.md",
    "CODE_STYLE.md",
    "DEPLOYMENT_GUIDE.md",
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
