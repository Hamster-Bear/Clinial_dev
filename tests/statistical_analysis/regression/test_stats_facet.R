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
# Test script for statistical analysis modules
# This script simulates the environment and calls the analysis functions directly

library(testthat)
library(dplyr)
library(survival)
library(gtsummary)
library(gt)
library(shiny) # Load shiny for req()

# Helper to resolve module paths
module_path <- function(p) {
  if (file.exists(p)) p else file.path("..", p)
}

# Load modules
source(module_path("modules/common/export/table_export.R"))
source(module_path("modules/common/analysis/analysis_format.R"))
source(module_path("modules/common/analysis/analysis_shared.R"))
source(module_path("modules/statistical_analysis/linear.R"))
source(module_path("modules/statistical_analysis/logistic.R"))
source(module_path("modules/statistical_analysis/cox.R"))

# Mock data
set.seed(123)
mock_data <- data.frame(
  time = rexp(100, 0.1),
  status = rbinom(100, 1, 0.7),
  age = rnorm(100, 60, 10),
  sex = factor(rbinom(100, 1, 0.5), labels = c("F", "M")),
  trt = factor(rbinom(100, 1, 0.5), labels = c("Placebo", "Drug")),
  response_linear = rnorm(100, 100, 15),
  response_binary = rbinom(100, 1, 0.4)
)

test_that("Cox Analysis works", {
  # Standard
  res <- perform_cox_analysis(mock_data, "time", "status", c("age", "sex"), NULL)
  expect_true(inherits(res$table, "gt_tbl"))
  expect_true(!is.null(res$interpretation))
  
  # With Strata
  res_strata <- perform_cox_analysis(mock_data, "time", "status", "age", "sex")
  expect_true(inherits(res_strata$table, "gt_tbl"))
  
  # With Facet
  res_facet <- perform_cox_analysis(mock_data, "time", "status", "age", NULL, "sex")
  expect_true(inherits(res_facet$table, "gt_tbl"))
})

test_that("Logistic Analysis works", {
  # Standard
  res <- perform_logistic_analysis(mock_data, "response_binary", c("age", "sex"))
  expect_true(inherits(res$table, "gt_tbl"))
  
  # With Facet
  res_facet <- perform_logistic_analysis(mock_data, "response_binary", "age", "sex")
  expect_true(inherits(res_facet$table, "gt_tbl"))
})

test_that("Linear Analysis works", {
  # Standard
  res <- perform_linear_analysis(mock_data, "response_linear", c("age", "sex"))
  expect_true(inherits(res$table, "gt_tbl"))
  
  # With Facet
  res_facet <- perform_linear_analysis(mock_data, "response_linear", "age", "sex")
  expect_true(inherits(res_facet$table, "gt_tbl"))
})

print("All tests passed!")

