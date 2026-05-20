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
library(survival)
library(survminer)

set.seed(123)
n <- 100
sim_data <- data.frame(
  time = rexp(n, rate = 0.1),
  status = rbinom(n, 1, 0.8),
  grp = factor(rep(c("A", "B"), each = n / 2))
)

labels <- list(A = "Group Alpha", B = "Group Beta")

test_that("标签映射后中位生存 strata 使用映射标签", {
  plot_data <- sim_data
  strata_col <- as.character(plot_data$grp)
  for (orig in names(labels)) {
    if (labels[[orig]] != "") {
      strata_col[strata_col == orig] <- labels[[orig]]
    }
  }
  plot_data$grp <- factor(strata_col, levels = unique(strata_col))

  surv_obj <- Surv(plot_data$time, plot_data$status)
  fit <- surv_fit(surv_obj ~ grp, data = plot_data)
  median_surv <- surv_median(fit)

  expect_true(all(grepl("Group Alpha|Group Beta", median_surv$strata)),
    info = sprintf("strata 应包含映射标签，实际: %s",
      paste(median_surv$strata, collapse = ", ")))
})

test_that("未映射的原始拟合 strata 保留原始值", {
  fit_original <- surv_fit(Surv(sim_data$time, sim_data$status) ~ grp, data = sim_data)
  median_orig <- surv_median(fit_original)
  expect_true(all(median_orig$strata %in% c("grp=A", "grp=B")),
    info = sprintf("未映射 strata 应保留原始格式: %s",
      paste(median_orig$strata, collapse = ", ")))
})

test_that("HR 标签映射函数处理标准模式", {
  map_label <- function(x, labels) {
    if (x %in% names(labels) && labels[[x]] != "") {
      return(labels[[x]])
    }
    if (grepl("=", x)) {
      extracted <- sub(".*=", "", x)
      if (extracted %in% names(labels) && labels[[extracted]] != "") {
        return(labels[[extracted]])
      }
    }
    return(x)
  }

  expect_equal(map_label("A", labels), "Group Alpha")
  expect_equal(map_label("B", labels), "Group Beta")
  expect_equal(map_label("grp=A", labels), "Group Alpha")
  expect_equal(map_label("grp=B", labels), "Group Beta")
})

test_that("HR 标签映射函数对未知值返回原值", {
  map_label <- function(x, labels) {
    if (x %in% names(labels) && labels[[x]] != "") {
      return(labels[[x]])
    }
    if (grepl("=", x)) {
      extracted <- sub(".*=", "", x)
      if (extracted %in% names(labels) && labels[[extracted]] != "") {
        return(labels[[extracted]])
      }
    }
    return(x)
  }

  expect_equal(map_label("C", labels), "C")
  expect_equal(map_label("grp=C", labels), "grp=C")
})
