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

load_env_file <- function(file_path) {
  if (!file.exists(file_path)) {
    return(invisible(FALSE))
  }
  lines <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
  for (line in lines) {
    trimmed <- trimws(line)
    if (!nzchar(trimmed) || startsWith(trimmed, "#")) {
      next
    }
    idx <- regexpr("=", trimmed, fixed = TRUE)[[1]]
    if (idx <= 1) {
      next
    }
    key <- trimws(substr(trimmed, 1, idx - 1))
    value <- trimws(substr(trimmed, idx + 1, nchar(trimmed)))
    do.call(Sys.setenv, stats::setNames(list(value), key))
  }
  invisible(TRUE)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

wait_until <- function(check_fn, timeout = 20, interval = 0.5) {
  deadline <- Sys.time() + timeout
  last_value <- NULL
  repeat {
    last_value <- tryCatch(check_fn(), error = function(e) NULL)
    if (!is.null(last_value) && !identical(last_value, FALSE)) {
      return(last_value)
    }
    if (Sys.time() >= deadline) {
      return(NULL)
    }
    Sys.sleep(interval)
  }
}

skip_if_admin_smoke_not_enabled <- function() {
  if (!identical(Sys.getenv("RUN_ADMIN_SMOKE", ""), "1")) {
    skip("未设置 RUN_ADMIN_SMOKE=1，跳过管理员页 shinytest2 smoke test")
  }
}

skip_if_missing_env <- function() {
  required_env <- c(
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "APP_ADMIN_USERNAME",
    "APP_ADMIN_PASSWORD"
  )
  values <- Sys.getenv(required_env, "")
  if (any(!nzchar(values))) {
    skip("缺少管理员 smoke test 所需环境变量，跳过验证")
  }
}

load_env_file(file.path(project_root, ".env.test"))

test_that("管理员可登录并进入系统管理页", {
  skip_if_not_installed("shinytest2")
  skip_if_admin_smoke_not_enabled()
  skip_if_missing_env()

  app <- shinytest2::AppDriver$new(
    app_dir = project_root,
    name = "admin-manager-smoke",
    load_timeout = 30000,
    height = 1200,
    width = 1600
  )
  on.exit(app$stop(), add = TRUE)

  app$set_inputs(
    `auth-login_identity` = Sys.getenv("APP_ADMIN_USERNAME"),
    `auth-login_password` = Sys.getenv("APP_ADMIN_PASSWORD")
  )
  app$click("auth-login_submit")

  logged_in_tab <- wait_until(function() {
    tab_value <- app$get_value(input = "tabs")
    if (identical(tab_value, "db_manage")) {
      tab_value
    } else {
      NULL
    }
  }, timeout = 30)
  expect_identical(logged_in_tab, "db_manage")

  app$set_inputs(tabs = "admin")
  admin_tab <- wait_until(function() {
    tab_value <- app$get_value(input = "tabs")
    if (identical(tab_value, "admin")) {
      tab_value
    } else {
      NULL
    }
  }, timeout = 15)
  expect_identical(admin_tab, "admin")

  runtime_meta <- wait_until(function() {
    value <- app$get_value(output = "admin-admin_runtime_meta")
    text <- paste(value, collapse = "\n")
    if (nzchar(text) && grepl("数据库主机", text, fixed = TRUE)) {
      text
    } else {
      NULL
    }
  }, timeout = 20)
  expect_match(runtime_meta %||% "", "数据库主机", fixed = TRUE)
  expect_match(runtime_meta %||% "", "数据库名称", fixed = TRUE)

  smtp_probe_meta <- wait_until(function() {
    value <- app$get_value(output = "admin-admin_smtp_probe_meta")
    text <- paste(value, collapse = "\n")
    if (nzchar(text) && grepl("邮件模式", text, fixed = TRUE)) {
      text
    } else {
      NULL
    }
  }, timeout = 20)
  expect_match(smtp_probe_meta %||% "", "邮件模式", fixed = TRUE)

  smtp_probe_last_result <- wait_until(function() {
    value <- app$get_value(output = "admin-admin_smtp_probe_last_result")
    text <- paste(value, collapse = "\n")
    if (nzchar(text) && grepl("最近一次探针状态", text, fixed = TRUE)) {
      text
    } else {
      NULL
    }
  }, timeout = 20)
  expect_match(smtp_probe_last_result %||% "", "最近一次探针状态", fixed = TRUE)

  risk_panel <- wait_until(function() {
    value <- app$get_value(output = "admin-admin_risk_overview")
    text <- paste(capture.output(str(value)), collapse = " ")
    if (grepl("停用账号", text, fixed = TRUE) || grepl("优先关注", text, fixed = TRUE)) {
      text
    } else {
      NULL
    }
  }, timeout = 20)
  expect_true(nzchar(risk_panel %||% ""))

  registry_table <- wait_until(function() {
    value <- app$get_value(output = "admin-admin_user_registry_table")
    text <- paste(capture.output(str(value)), collapse = " ")
    if (grepl("账号名", text, fixed = TRUE) || grepl("联系邮箱", text, fixed = TRUE)) {
      text
    } else {
      NULL
    }
  }, timeout = 20)
  expect_true(nzchar(registry_table %||% ""))

  registry_summary <- wait_until(function() {
    value <- app$get_value(output = "admin-admin_user_registry_summary")
    text <- paste(capture.output(str(value)), collapse = " ")
    if (grepl("注册账号总数", text, fixed = TRUE) || grepl("未开通数据空间功能", text, fixed = TRUE)) {
      text
    } else {
      NULL
    }
  }, timeout = 20)
  expect_true(nzchar(registry_summary %||% ""))
})



