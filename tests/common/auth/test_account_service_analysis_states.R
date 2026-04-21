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

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

source(file.path(project_root, "modules", "common", "auth", "auth.R"), local = TRUE)
source(file.path(project_root, "modules", "common", "auth", "account_service.R"), local = TRUE)

test_that("service_normalize_analysis_state_workspace_id 将空工作空间归一为 NULL", {
  expect_null(service_normalize_analysis_state_workspace_id(NULL))
  expect_null(service_normalize_analysis_state_workspace_id(""))
  expect_null(service_normalize_analysis_state_workspace_id("   "))
  expect_null(service_normalize_analysis_state_workspace_id("NULL"))
  expect_identical(service_normalize_analysis_state_workspace_id(list(id = " ws_list ")), "ws_list")
  expect_identical(
    service_normalize_analysis_state_workspace_id(data.frame(id = " ws_df ", stringsAsFactors = FALSE)),
    "ws_df"
  )
  expect_identical(service_normalize_analysis_state_workspace_id(" ws_001 "), "ws_001")
})

test_that("service_build_analysis_state_insert_spec 对个人任务使用 NULL workspace 分支", {
  insert_spec <- service_build_analysis_state_insert_spec(
    state_id = "analysis_state_1",
    user_id = "user_1",
    workspace_id = NULL,
    scope = "graphics",
    module_type = "forest",
    state_name = "demo",
    state_payload = "{\"foo\":1}",
    state_note = "note"
  )

  expect_match(insert_spec$sql, "VALUES \\(\\$1, \\$2, NULL, \\$3, \\$4, \\$5, \\$6, \\$7, NOW\\(\\), NOW\\(\\)\\)")
  expect_no_match(insert_spec$sql, "ON CONFLICT")
  expect_length(insert_spec$params, 7)
  expect_identical(insert_spec$params[[1]], "analysis_state_1")
  expect_identical(insert_spec$params[[2]], "user_1")
})

test_that("service_build_analysis_state_insert_spec 的 SQL 列顺序与参数顺序一致", {
  insert_spec <- service_build_analysis_state_insert_spec(
    state_id = "analysis_state_2",
    user_id = "user_2",
    workspace_id = "ws_002",
    scope = "graphics",
    module_type = "forest",
    state_name = "demo-name",
    state_payload = "{\"foo\":2}",
    state_note = "demo-note"
  )

  expect_match(insert_spec$sql, "state_name, state_payload, state_note")
  expect_no_match(insert_spec$sql, "ON CONFLICT")
  expect_identical(insert_spec$params[[6]], "demo-name")
  expect_identical(insert_spec$params[[7]], "{\"foo\":2}")
  expect_identical(insert_spec$params[[8]], "demo-note")
})

test_that("service_build_analysis_state_update_spec 生成覆盖保存 SQL", {
  update_spec <- service_build_analysis_state_update_spec(
    state_id = "analysis_state_2",
    state_payload = "{\"foo\":3}",
    state_note = "updated-note"
  )

  expect_match(update_spec$sql, "^UPDATE analysis_states")
  expect_match(update_spec$sql, "SET state_payload = \\$2, state_note = \\$3, updated_at = NOW\\(\\)")
  expect_match(update_spec$sql, "WHERE id = \\$1$")
  expect_identical(update_spec$params[[1]], "analysis_state_2")
  expect_identical(update_spec$params[[2]], "{\"foo\":3}")
  expect_identical(update_spec$params[[3]], "updated-note")
})

test_that("service_parse_analysis_state_payload 安全解析 JSON 任务快照", {
  parsed <- service_parse_analysis_state_payload("{\"input_state\":{\"a\":1},\"extra_state\":{\"b\":[\"x\"]}}")
  expect_true(is.list(parsed))
  expect_equal(parsed$input_state$a, 1)
  expect_identical(parsed$extra_state$b[[1]], "x")
  expect_equal(service_parse_analysis_state_payload(""), list())
})



