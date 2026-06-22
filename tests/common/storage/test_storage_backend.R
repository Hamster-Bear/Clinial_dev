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
library(testthat)
source(file.path(project_root, "modules", "common", "data", "storage_backend.R"))

# ---- storage_backend_get ----

test_that("storage_backend_get 默认返回 local", {
  withr::with_envvar(c(STORAGE_BACKEND = ""), {
    expect_equal(storage_backend_get(), "local")
  })
})

test_that("storage_backend_get 识别 s3", {
  withr::with_envvar(c(STORAGE_BACKEND = "s3"), {
    expect_equal(storage_backend_get(), "s3")
  })
})

test_that("storage_backend_get 对未知值回退到 local", {
  withr::with_envvar(c(STORAGE_BACKEND = "unknown"), {
    expect_equal(storage_backend_get(), "local")
  })
})

# ---- storage_data_key_build ----

test_that("storage_data_key_build 正常拼接路径", {
  key <- storage_data_key_build("ws1", "fld1", "ds1")
  expect_equal(key, "ws1/fld1/ds1.rds")
})

test_that("storage_data_key_build folder_id 为空时使用 root", {
  key <- storage_data_key_build("ws1", NULL, "ds1")
  expect_equal(key, "ws1/root/ds1.rds")
})

test_that("storage_data_key_build folder_id 为空串时使用 root", {
  key <- storage_data_key_build("ws1", "", "ds1")
  expect_equal(key, "ws1/root/ds1.rds")
})

# ---- storage_save_dataset / storage_load_dataset / storage_delete_dataset (local 模式) ----

test_that("local 模式 round-trip: save -> load -> delete", {
  withr::with_envvar(c(STORAGE_BACKEND = "local"), {
    tmp_root <- tempdir()
    test_df <- data.frame(x = 1:5, y = letters[1:5], stringsAsFactors = FALSE)

    path <- storage_save_dataset(test_df, "ws_test", "fld_test", "ds_test", storage_root = tmp_root)
    expect_true(file.exists(path))

    loaded <- storage_load_dataset(path)
    expect_equal(loaded$x, 1:5)
    expect_equal(loaded$y, letters[1:5])

    result <- storage_delete_dataset(path)
    expect_true(result)
    expect_false(file.exists(path))
  })
})

test_that("storage_delete_dataset 空路径返回 FALSE", {
  expect_false(storage_delete_dataset(""))
})

test_that("storage_delete_dataset 不存在的文件返回 FALSE", {
  expect_false(storage_delete_dataset(tempfile()))
})

# ---- storage_s3_ensure ----

test_that("storage_s3_ensure 在无 aws.s3 时报错", {
  withr::with_envvar(c(STORAGE_S3_BUCKET = "test-bucket"), {
    # 如果 aws.s3 已安装则跳过
    skip_if(requireNamespace("aws.s3", quietly = TRUE))
    expect_error(storage_s3_ensure(), "aws.s3")
  })
})

test_that("storage_s3_ensure 在无 bucket 配置时报错", {
  withr::with_envvar(c(STORAGE_S3_BUCKET = ""), {
    expect_error(storage_s3_ensure(), "STORAGE_S3_BUCKET")
  })
})
