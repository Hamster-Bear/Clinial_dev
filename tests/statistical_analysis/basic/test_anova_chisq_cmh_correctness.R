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

Sys.setlocale("LC_CTYPE", "Chinese_China.utf8")
project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))
library(testthat)

source(file.path("..", "modules", "statistical_analysis", "anova.R"))
source(file.path("..", "modules", "statistical_analysis", "chisq.R"))

test_that("ANOVA 输出统一字段和 AMA P 值", {
  dat <- data.frame(
    arm = rep(c("A", "B", "C"), each = 8),
    score = c(seq(1, 1.7, length.out = 8), seq(10, 10.7, length.out = 8), seq(20, 20.7, length.out = 8)),
    stringsAsFactors = FALSE
  )

  res <- perform_anova_analysis(dat, "score", "arm")

  expect_true(all(c("项目", "自由度", "平方和", "均方", "F值", "P值") %in% names(res)))
  expect_false("p.value" %in% names(res))
  expect_equal(res$P值[res$项目 == "arm"], "<0.001")
})

test_that("ANOVA 使用 complete cases 并拒绝重复变量", {
  dat <- data.frame(
    arm = c("A", "A", "B", "B", "C", "C"),
    score = c(1, 1.2, 2, NA_real_, 3, 3.1),
    stringsAsFactors = FALSE
  )

  res <- perform_anova_analysis(dat, "score", "arm")

  expect_true("Residuals" %in% res$项目)
  expect_equal(res$自由度[res$项目 == "Residuals"], 2)
  expect_error(perform_anova_analysis(dat, "score", "score"), "响应变量不能同时作为分组变量")
})

test_that("卡方检验支持字符分类变量并输出 AMA P 值", {
  dat <- data.frame(
    arm = c(rep("Drug", 24), rep("Control", 24)),
    response = c(rep("Yes", 22), rep("No", 2), rep("Yes", 2), rep("No", 22)),
    stringsAsFactors = FALSE
  )

  res <- perform_chisq_analysis(dat, "arm", "response")

  expect_true(all(c("检验", "统计量", "自由度", "P值") %in% names(res)))
  expect_false("p.value" %in% names(res))
  expect_equal(res$P值[[1]], "<0.001")
  expect_error(perform_chisq_analysis(dat, "arm", "arm"), "分类检验变量不能重复")
})

test_that("CMH 检验可运行并输出分层检验结果", {
  dat <- data.frame(
    arm = rep(c("Drug", "Drug", "Control", "Control"), times = 3),
    response = c(
      "Yes", "Yes", "Yes", "No",
      "Yes", "No", "No", "No",
      "Yes", "Yes", "No", "No"
    ),
    site = rep(c("S1", "S2", "S3"), each = 4),
    stringsAsFactors = FALSE
  )

  res <- perform_cmh_analysis(dat, "arm", "response", "site")

  expect_true(all(c("检验", "统计量", "自由度", "P值") %in% names(res)))
  expect_equal(res$检验[[1]], "Cochran-Mantel-Haenszel 检验")
  expect_match(res$P值[[1]], "^(<0\\.001|>0\\.99|[0-9]+\\.[0-9]{3}|—)$")
  expect_true(is.numeric(res$统计量))
})
