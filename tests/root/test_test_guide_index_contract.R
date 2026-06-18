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

normalize_rel_path <- function(path) {
  gsub("\\\\", "/", path)
}

collect_actual_test_assets <- function(root) {
  test_files <- list.files(
    file.path(root, "tests"),
    pattern = "^test_.*\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )
  quality_gate_scripts <- file.path(root, "tests", "check_test_guide_index.R")
  quality_gate_scripts <- quality_gate_scripts[file.exists(quality_gate_scripts)]
  fixture_files <- list.files(
    file.path(root, "tests", "fixtures"),
    recursive = TRUE,
    full.names = TRUE
  )

  assets <- c(test_files, quality_gate_scripts, fixture_files[file.info(fixture_files)$isdir %in% FALSE])
  assets <- normalizePath(assets, winslash = "/", mustWork = TRUE)
  prefix <- paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/")
  sort(unique(sub(prefix, "", assets, fixed = TRUE)))
}

extract_test_guide_paths <- function(root) {
  guide_path <- file.path(root, "docs", "main", "TEST_GUIDE.md")
  content <- paste(readLines(guide_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  matches <- gregexpr("tests/[A-Za-z0-9_./-]+\\.(R|csv)", content, perl = TRUE)
  paths <- regmatches(content, matches)[[1]]
  if (length(paths) == 0) return(character(0))

  sort(unique(paths))
}

test_that("TEST_GUIDE.md 覆盖现有测试文件与夹具", {
  actual_assets <- collect_actual_test_assets(project_root)
  guide_assets <- extract_test_guide_paths(project_root)

  missing_in_guide <- setdiff(actual_assets, guide_assets)
  missing_on_disk <- setdiff(guide_assets, actual_assets)

  expect_equal(
    missing_in_guide,
    character(0),
    info = paste("以下测试资产未登记到 TEST_GUIDE.md:", paste(missing_in_guide, collapse = ", "))
  )
  expect_equal(
    missing_on_disk,
    character(0),
    info = paste("以下 TEST_GUIDE.md 路径在磁盘上不存在:", paste(missing_on_disk, collapse = ", "))
  )
})
