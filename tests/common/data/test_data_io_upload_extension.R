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

source(file.path(project_root, "modules", "common", "data", "data_io.R"))

test_that("Shiny 无扩展名临时上传文件可从原始文件名推断格式", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c("subject,value", "A,1", "B,2"), tmp, useBytes = TRUE)

  dat <- data_read_file(tmp, original_file_name = "upload.csv")
  expect_s3_class(dat, "data.frame")
  expect_equal(names(dat), c("subject", "value"))
  expect_equal(nrow(dat), 2)
})
