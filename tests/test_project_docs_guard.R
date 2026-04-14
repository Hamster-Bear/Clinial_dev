# 文档守卫测试契约
# 目的: 确保项目的核心规范文档不被意外删除，并在一定程度上校验其内容完整性。

library(testthat)

context("Project Documentation Integrity Guard")

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
      file.exists(file.path("..", doc)),
      info = sprintf("关键规范文档 %s 缺失！请根据【文档驱动】铁律补齐。", doc)
    )
  }
})

test_that("CODE_STYLE.md 必须包含关键约定要求", {
  code_style_path <- file.path("..", "CODE_STYLE.md")
  if (file.exists(code_style_path)) {
    code_style_content <- paste(readLines(code_style_path, encoding = "UTF-8"), collapse = "\n")
    expect_match(code_style_content, "tests/")
    expect_match(code_style_content, "testthat")
    expect_match(code_style_content, "PROJECT_GUIDE")
    expect_match(code_style_content, "模块")
  }
})

test_that("PROJECT_SPEC.md 必须包含架构声明", {
  spec_path <- file.path("..", "PROJECT_SPEC.md")
  skip_if_not(file.exists(spec_path))
  
  content <- readLines(spec_path, encoding = "UTF-8")
  content_str <- paste(content, collapse = "\n")
  
  expect_match(content_str, "PostgreSQL", info = "PROJECT_SPEC.md 必须声明数据库依赖")
  expect_match(content_str, "Shiny", info = "PROJECT_SPEC.md 必须声明前端框架")
})