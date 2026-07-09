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
setwd(project_root)

library(testthat)

source_utf8 <- function(path) {
  eval(parse(text = readLines(path, encoding = "UTF-8", warn = FALSE)), envir = .GlobalEnv)
}

source_utf8(file.path("modules", "common", "graphics", "graphics_common.R"))
source_utf8(file.path("modules", "statistical_graphics", "heatmap.R"))

test_that("热图聚类开关开启时按相关结构重排矩阵", {
  mat <- matrix(
    c(
      1.0, 0.1, 0.9,
      0.1, 1.0, 0.2,
      0.9, 0.2, 1.0
    ),
    nrow = 3,
    byrow = TRUE,
    dimnames = list(c("A", "B", "C"), c("A", "B", "C"))
  )

  unclustered <- heatmap_order_correlation_matrix(mat, cluster = FALSE)
  clustered <- heatmap_order_correlation_matrix(mat, cluster = TRUE)

  expect_identical(rownames(unclustered), c("A", "B", "C"))
  expect_identical(colnames(unclustered), c("A", "B", "C"))
  expect_setequal(rownames(clustered), c("A", "B", "C"))
  expect_identical(rownames(clustered), colnames(clustered))
  expect_false(identical(rownames(clustered), rownames(unclustered)))
})

test_that("热图可复现代码按状态中的聚类开关重排矩阵", {
  code <- generate_graphics_repro_code(
    "heatmap",
    state = list(selected_vars = c("A", "B", "C"), clustering = TRUE)
  )

  expect_match(code, "cluster_heatmap <- TRUE", fixed = TRUE)
  expect_match(code, "stats::hclust", fixed = TRUE)

  repro_env <- new.env(parent = globalenv())
  repro_env$data <- data.frame(
    A = c(1, 2, 3, 4, 5, 6),
    B = c(6, 5, 4, 3, 2, 1),
    C = c(1, 2, 4, 5, 7, 8)
  )

  capture.output(suppressWarnings(eval(parse(text = code), envir = repro_env)))

  expect_setequal(rownames(repro_env$mat), c("A", "B", "C"))
  expect_identical(rownames(repro_env$mat), colnames(repro_env$mat))
  expect_false(identical(rownames(repro_env$mat), c("A", "B", "C")))
})
